import cv2
import copy
import random
import re

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug
from table_extraction.image_processing import ImageProcessing
from table_extraction.table_box import TableBox
from table_extraction.table import Table
from table_extraction.line import Line
from table_extraction.content_block import ContentBlock
from table_extraction.content_group_block import ContentGroupBlock

class TableProcessing(object):
    """All table processing work:
    1. Merge all single lines to one
    2. Refine all lines (connect at start/end point to reduce the noise)
    3. Connect the table borders, table lines (extend)
    4. Create the virtual line to seperate the table content
    """

    def __init__(self, input_image, binary_image, crnn_chars, header_regex, flag_semi_virtual, debug_save_path):
        self.input_image       = input_image
        self.binary_image      = binary_image
        self.crnn_chars        = crnn_chars #13968
        self.header_regex      = header_regex #13968
        self.flag_semi_virtual = flag_semi_virtual #14814

        self.debug_save_path = debug_save_path

    def merge_single_horizontal_lines(self, lines, threshold=5):
        """Merge all nearby horizontal lines with sort distance ( < threshold) to be one
        """
        group_dict = {}
        for line in lines:
            # Sort the key list
            keys = list(group_dict.keys())
            keys.sort()
            position = 0 if len(group_dict) == 0 else keys[-1]
            if line.start_point[1] <= position + threshold:
                groups = group_dict.get(position, [])
                groups.append(line)
            else:
                group_dict[line.start_point[1]] = [line]

        invalid_lines = []

        for lines in group_dict.values():
            lines = sorted(lines, key=lambda line: line.start_point[0])
            for i in range(len(lines) - 1):
                a_line = lines[i]
                b_line = lines[i+1]

                if not a_line.connect_at_end_point and not b_line.connect_at_start_point:
                    Utils.extend_lines(a_line, b_line, "horizontal")
                    invalid_lines.append(a_line)

        h_lines = []
        for lines in group_dict.values():
            for line in lines:
                if line not in invalid_lines:
                    h_lines.append(line)

        return h_lines

    def merge_single_vertical_lines(self, lines, threshold=5):
        """Merge all nearby vertical lines with sort distance ( < threshold) to be one
        """
        group_dict = {}
        for line in lines:
            # Sort the key list
            keys = list(group_dict.keys())
            keys.sort()
            position = 0 if len(group_dict) == 0 else keys[-1]
            if line.start_point[0] <= position + threshold:
                groups = group_dict.get(position, [])
                groups.append(line)
            else:
                group_dict[line.start_point[0]] = [line]

        invalid_lines = []

        for lines in group_dict.values():
            lines = sorted(lines, key=lambda line: line.start_point[1])
            for i in range(len(lines) - 1):
                a_line = lines[i]
                b_line = lines[i+1]

                if not a_line.connect_at_end_point and not b_line.connect_at_start_point:
                    Utils.extend_lines(a_line, b_line, "vertical")
                    invalid_lines.append(a_line)

        v_lines = []
        for lines in group_dict.values():
            for line in lines:
                if line not in invalid_lines:
                    v_lines.append(line)

        return v_lines

    def merge_nearby_lines(self, table, threshold=5):
        """Merge all duplicated or nearby lines in table
        """
        h_lines = table.all_horizontal_lines()
        h_rects = [Utils.convert_line_to_box(h_line, threshold, 'h') for h_line in h_lines]
        h_rects_image = np.ones((self.input_image.shape[0], self.input_image.shape[1]), dtype=np.uint8) * 255
        h_rects_image = Utils.fill_boxes(h_rects_image, h_rects, (0, 0, 0))

        merged_h_rects = Utils.extract_line_rect(h_rects_image, False)
        merged_h_lines = [Utils.convert_box_to_line(rect) for rect in merged_h_rects]

        v_lines = table.all_vertical_lines()
        v_rects = [Utils.convert_line_to_box(v_line, threshold, 'v') for v_line in v_lines]
        v_rects_image = np.ones((self.input_image.shape[0], self.input_image.shape[1]), dtype=np.uint8) * 255
        v_rects_image = Utils.fill_boxes(v_rects_image, v_rects, (0, 0, 0))

        merged_v_rects = Utils.extract_line_rect(v_rects_image, False)
        merged_v_lines = [Utils.convert_box_to_line(rect) for rect in merged_v_rects]

        # Shrink the lines after merged
        h_lines, v_lines = Utils.shrink_line(merged_h_lines, merged_v_lines, 15)

        self.set_table_vertical_lines(table, v_lines)
        self.set_table_horizontal_lines(table, h_lines)

    def set_table_vertical_lines(self, table, v_lines):
        all_vertical_lines = sorted(v_lines, key=lambda line: line.start_point[0])
        if len(all_vertical_lines) > 0:
            # The left table border will be the first one
            table.left_border = all_vertical_lines[0]
            table.left_border.table_line = True

            # The right table border will be the last one
            table.right_border = all_vertical_lines[-1]
            table.right_border.table_line = True

            table.vertical_lines = all_vertical_lines[1:-1]

    def set_table_horizontal_lines(self, table, h_lines):
        # Sort all vertical lines by Y position
        all_horizontal_lines = sorted(h_lines, key=lambda line: line.start_point[1])
        if len(all_horizontal_lines) > 0:
            # The left table border will be the first one
            table.top_border = all_horizontal_lines[0]
            table.top_border.table_line = True

            # The right table border will be the last one
            table.bottom_border = all_horizontal_lines[-1]
            table.bottom_border.table_line = True

            table.horizontal_lines = all_horizontal_lines[1:-1]

    def connect_table_borders(self, box, table, h_lines, v_lines, threshold=15):
        """Find all table border lines and connect it
        
        :param box: the bouding box of table
        :param table: the table object need to process
        :param h_lines: all horizontal lines inside the table
        :param v_lines: all vertical lines insdie the table
        """

        box_x, box_y, box_w, box_h = box
        left_borders = []
        top_borders = []
        right_borders = []
        bottom_borders = []

        # Find all nearest lines with bounding box, this should be the border lines
        for h_line in h_lines:
            if Utils.distance_from_line_to_box(box, h_line, "top") < threshold:
                top_borders.append(h_line)
            if Utils.distance_from_line_to_box(box, h_line, "bottom") < threshold:
                bottom_borders.append(h_line)

        # Find all nearest lines with bounding box, this should be the border lines
        for v_line in v_lines:
            if Utils.distance_from_line_to_box(box, v_line, "left") < threshold:
                left_borders.append(v_line)
            if Utils.distance_from_line_to_box(box, v_line, "right") < threshold:
                right_borders.append(v_line)

        if len(top_borders) > 0:
            # Merge mutiple lines to one
            table.top_border = Utils.merge_border_lines(top_borders, "horizontal")
        else:
            # In case can't find any line at the border, create new one
            line = Line((box_x, box_y), (box_x + box_w, box_y), 0, "h")
            # line.virtual_line = True
            table.top_border = line

        if len(bottom_borders) > 0:
            # Merge mutiple lines to one
            table.bottom_border = Utils.merge_border_lines(bottom_borders, "horizontal")
        else:
            # In case can't find any line at the border, create new one
            line = Line((box_x, box_y + box_h), (box_x + box_w, box_y + box_h), 0, "h")
            # line.virtual_line = True
            table.bottom_border = line

        if len(left_borders) > 0:
            # Merge mutiple lines to one
            table.left_border = Utils.merge_border_lines(left_borders, "vertical")
        else:
            # In case can't find any line at the border, create new one
            line = Line((box_x, box_y), (box_x, box_y + box_h), 0, "v")
            # line.virtual_line = True
            table.left_border = line

        if len(right_borders) > 0:
            # Merge mutiple lines to one
            table.right_border = Utils.merge_border_lines(right_borders, "vertical")
        else:
            # In case can't find any line at the border, create new one
            line = Line((box_x + box_w, box_y), (box_x + box_w, box_y + box_h), 0, "v")
            # line.virtual_line = True
            table.right_border = line

        # Refine all border lines
        Utils.shrink_line([table.top_border, table.bottom_border], [table.left_border, table.right_border])

        self.connect_table_border_lines(table.left_border, table.top_border, table.right_border, table.bottom_border)

        for h_line in h_lines:
            if h_line not in top_borders and h_line not in bottom_borders:
                table.append_horizontal_lines(h_line)

        for v_line in v_lines:
            if v_line not in left_borders and v_line not in right_borders:
                table.append_vertical_lines(v_line)

        # Refine all border lines after connected
        Utils.shrink_line(table.all_horizontal_lines(), table.all_vertical_lines())

    def connect_table_border_lines(self, left_border, top_border, right_border, bottom_border, threshold=20):
        """Make the table borders connected in case it didn't
        
        :param left_border: the table left border
        :param top_border: the table top border
        :param right_border: the table right border
        :param bottom_border: the table bottom border

        """

        def connect_left_top_borders(left_border, top_border):
            intersection_point = Utils.line_intersection(left_border, top_border)
            if intersection_point[0] and intersection_point[1]:
                left_border.start_point = intersection_point
                left_border.connect_at_start_point = True
                top_border.start_point = intersection_point
                top_border.connect_at_start_point = True

        def connect_left_bottom_borders(left_border, bottom_border):
            intersection_point = Utils.line_intersection(left_border, bottom_border)
            if intersection_point[0] and intersection_point[1]:
                left_border.end_point = intersection_point
                left_border.connect_at_end_point = True
                bottom_border.start_point = intersection_point
                bottom_border.connect_at_start_point = True

        def connect_right_top_border(right_border, top_border):
            intersection_point = Utils.line_intersection(right_border, top_border)
            if intersection_point[0] and intersection_point[1]:
                right_border.start_point = intersection_point
                right_border.connect_at_start_point = True
                top_border.end_point = intersection_point
                top_border.connect_at_end_point = True

        def connect_right_bottom_border(right_border, bottom_border):
            intersection_point = Utils.line_intersection(right_border, bottom_border)
            if intersection_point[0] and intersection_point[1]:
                right_border.end_point = intersection_point
                right_border.connect_at_end_point = True
                bottom_border.end_point = intersection_point
                bottom_border.connect_at_end_point = True

        # Only connect if two borders don't connect with another line
        if not left_border.connect_at_start_point and not top_border.connect_at_start_point:
            connect_left_top_borders(left_border, top_border)

        # Only connect if two borders don't connect with another line
        if not left_border.connect_at_end_point and not bottom_border.connect_at_start_point:
            connect_left_bottom_borders(left_border, bottom_border)

        # Only connect if two borders don't connect with another line
        if not right_border.connect_at_start_point and not top_border.connect_at_end_point:
            connect_right_top_border(right_border, top_border)

        # Only connect if two borders don't connect with another line
        if not right_border.connect_at_end_point and not bottom_border.connect_at_end_point:
            connect_right_bottom_border(right_border, bottom_border)

        # extend border to other border
        if Utils.check_two_points_in_same_line(top_border.start_point, bottom_border.start_point, 'vertical') \
                and Utils.check_two_points_in_same_line(top_border.start_point, left_border.start_point, 'vertical'):
            connect_left_top_borders(left_border, top_border)
            connect_left_bottom_borders(left_border, bottom_border)

        if Utils.check_two_points_in_same_line(top_border.end_point, bottom_border.end_point, 'vertical') \
                and Utils.check_two_points_in_same_line(top_border.end_point, right_border.start_point, 'vertical'):
            connect_right_top_border(right_border, top_border)
            connect_right_bottom_border(right_border, bottom_border)

        if Utils.check_two_points_in_same_line(left_border.start_point, right_border.start_point, 'horizontal') \
                and Utils.check_two_points_in_same_line(left_border.start_point, top_border.start_point, 'horizontal'):
            connect_left_top_borders(left_border, top_border)
            connect_right_top_border(right_border, top_border)

        if Utils.check_two_points_in_same_line(left_border.end_point, right_border.end_point, 'horizontal') \
                and Utils.check_two_points_in_same_line(left_border.end_point, bottom_border.start_point, 'horizontal'):
            connect_left_bottom_borders(left_border, bottom_border)
            connect_right_bottom_border(right_border, bottom_border)

    def connect_table_horizontal_lines(self, table):
        """Expand all horizontal lines
        """
        LINE_TIMES = 1
        LINE_DIFF  = 5 #12596

        h_lines = table.all_horizontal_lines()
        v_lines = table.all_vertical_lines()

        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]

        invalid_lines = []

        for h_line in h_lines:
            # find the vertical line which stops horizontal lines
            # invalid line is line, which go across these content block
            left_stop_line, right_stop_line, invalid_horizontal_line = Utils.vertical_stop_line(h_line, v_lines, content_rects)

            if invalid_horizontal_line and not (h_line.connect_at_start_point or h_line.connect_at_end_point): #12465
                invalid_lines.append(h_line)
                continue
            elif invalid_horizontal_line:
                continue

            # extend horizontal line to the left point
            if left_stop_line is not None:
                intersection_point = Utils.line_intersection(h_line, left_stop_line)
                if intersection_point[0] and intersection_point[1]:
                    # skip if the point far from the line #12532
                    if Utils.is_point_far_line(intersection_point, h_line, times=LINE_TIMES):
                        orig_start_point = h_line.start_point #12596
                        h_line.start_point = intersection_point #12596
                        if not Utils.line_overlap_rects(h_line, content_rects, orientation="h", shrink_size=-3): #12596
                            h_line.start_point = intersection_point
                            h_line.connect_at_start_point = True
                        else: #12596
                            h_line.start_point = orig_start_point

            # extend horizontal line to the right point
            if right_stop_line is not None:
                intersection_point = Utils.line_intersection(h_line, right_stop_line)
                if intersection_point[0] and intersection_point[1]:
                    # skip if the point far from the line #12532
                    if Utils.is_point_far_line(intersection_point, h_line, times=LINE_TIMES):
                        h_line.end_point = intersection_point
                        h_line.connect_at_end_point = True

            # COMMENT #13409
            # if can not find the stop point at the left try to connect to neighbor horizontal line
            # if not h_line.connect_at_start_point:
            #     neighbor_line = Utils.horizontal_neighbor_line(h_line, h_lines)
            #     if abs(h_line.start_point[0]-neighbor_line.start_point[0])<LINE_DIFF: #12596
            #         virtual_v_line = Utils.create_virtual_vertical_line(h_line, neighbor_line, direction="start")
            #         if not Utils.line_overlap_rects(virtual_v_line, content_rects, orientation="v", shrink_size=-3): #12596
            #             table.append_vertical_lines(virtual_v_line)

            # if can not find the stop point at the right try to connect to neighbor horizontal line
            # if not h_line.connect_at_end_point:
            #     neighbor_line = Utils.horizontal_neighbor_line(h_line, h_lines)
            #     if abs(h_line.end_point[0]-neighbor_line.end_point[0])<LINE_DIFF: #12596
            #         virtual_v_line = Utils.create_virtual_vertical_line(h_line, neighbor_line, direction="end")
            #         if not Utils.line_overlap_rects(virtual_v_line, content_rects, orientation="v", shrink_size=-3): #12596
            #             table.append_vertical_lines(virtual_v_line)

        # remove invalid horizontal lines
        all_horizontal_lines = table.all_horizontal_lines()
        for h_line in invalid_lines:
            if h_line in all_horizontal_lines:
                all_horizontal_lines.remove(h_line)

        self.set_table_horizontal_lines(table, all_horizontal_lines)


    def connect_table_vertical_lines(self, table):
        """Expand all the vertical lines
        """
        LINE_TIMES = 1
        LINE_DIFF  = 5 #12596

        h_lines = table.all_horizontal_lines()
        v_lines = table.all_vertical_lines()

        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]

        invalid_lines = []

        for v_line in v_lines:
            # find the horizontal line which stops vertical lines
            # invalid line is line, which go across these content block
            top_stop_line, bottom_stop_line, invalid_vertical_line = Utils.horizontal_stop_line(v_line, h_lines, content_rects)

            if invalid_vertical_line and not (v_line.connect_at_start_point or v_line.connect_at_end_point): #12465
                invalid_lines.append(v_line)
                continue
            elif invalid_vertical_line:
                continue

            # extend vertical line to the top point
            if top_stop_line is not None:
                intersection_point = Utils.line_intersection(v_line, top_stop_line)
                if intersection_point[0] and intersection_point[1]:
                    # skip if the point far from the line #12532
                    if Utils.is_point_far_line(intersection_point, v_line, times=LINE_TIMES):
                        orig_start_point = v_line.start_point #12596
                        v_line.start_point = intersection_point #12596
                        if not Utils.line_overlap_rects(v_line, content_rects, orientation="v", shrink_size=-3): #12596
                            v_line.start_point = intersection_point
                            v_line.connect_at_start_point = True
                        else: #12596
                            v_line.start_point = orig_start_point

            # extend vertical line to the bottom point
            if bottom_stop_line is not None:
                intersection_point = Utils.line_intersection(v_line, bottom_stop_line)
                if intersection_point[0] and intersection_point[1]:
                    # skip if the point far from the line #12532
                    if Utils.is_point_far_line(intersection_point, v_line, times=LINE_TIMES):
                        v_line.end_point = intersection_point
                        v_line.connect_at_end_point = True

            # COMMENT #13409
            # if can not find the stop point at the top, try to connect to neighbor vertical line
            # if not v_line.connect_at_start_point:
            #     neighbor_line = Utils.vertical_neighbor_line(v_line, v_lines)
            #     if abs(v_line.start_point[1]-neighbor_line.start_point[1])<LINE_DIFF: #12596
            #         virtual_h_line = Utils.create_virtual_horizontal_line(v_line, neighbor_line, direction="start")
            #         if not Utils.line_overlap_rects(virtual_h_line, content_rects, orientation="h", shrink_size=-3): #12585
            #             table.append_horizontal_lines(virtual_h_line)

            # if can not find the stop point at the bottom, try to connect to neighbor vertical line
            # if not v_line.connect_at_end_point:
            #     neighbor_line = Utils.vertical_neighbor_line(v_line, v_lines)
            #     if abs(v_line.end_point[1]-neighbor_line.end_point[1])<LINE_DIFF: #12596
            #         virtual_h_line = Utils.create_virtual_horizontal_line(v_line, neighbor_line, direction="end")
            #         if not Utils.line_overlap_rects(virtual_h_line, content_rects, orientation="h", shrink_size=-3): #12585
            #             table.append_horizontal_lines(virtual_h_line)

        # remove invalid lines
        all_vertical_lines = table.all_vertical_lines()
        for v_line in invalid_lines:
            if v_line in all_vertical_lines:
                all_vertical_lines.remove(v_line)

        self.set_table_vertical_lines(table, all_vertical_lines)

    def connect_broken_horizontal_line(self, table):
        """
        Connect or remove broken horizontal line
        """
        h_lines = table.all_horizontal_lines()
        v_lines = table.all_vertical_lines()
        table_width = -1
        if table.right_border and table.left_border:
            table_width = table.top_border.length()
            f_check_removable_line = lambda line:line.length()<=table_width/2
        invalid_lines = set() # set type
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        for h_line in h_lines:
            if not h_line.connect_at_start_point:
                # find neighbor broken line
                neighbor_line = self.find_neighbor_broken_horizontal_line(h_line, h_lines, v_lines, content_rects, direction="start")
                h_line.start_point=(0, h_line.start_point[1])
                if neighbor_line:
                    h_line.end_point = (h_line.end_point[0], neighbor_line.end_point[1])
                elif table_width!=-1 and f_check_removable_line(h_line): #14818
                    invalid_lines.add(h_line)
            if not h_line.connect_at_end_point:
                # find neighbor broken line
                neighbor_line = self.find_neighbor_broken_horizontal_line(h_line, h_lines, v_lines, content_rects, direction="end")
                if neighbor_line:
                    h_line.end_point = (h_line.end_point[0], neighbor_line.end_point[1])
                elif table_width!=-1 and f_check_removable_line(h_line): #14818
                    invalid_lines.add(h_line)
        table.horizontal_lines = list(set(table.horizontal_lines)-invalid_lines)
        return table

    def connect_broken_vertical_line(self, table):
        """
        Connect broken vertical line
        """
        h_lines = table.all_horizontal_lines()
        v_lines = table.all_vertical_lines()
        table_height = -1
        if table.right_border and table.left_border:
            table_height = table.left_border.length()
            f_check_removable_line = lambda line:line.length()<=table_height/2
        invalid_lines = set() # set type
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        for i, v_line in enumerate(v_lines):
            if not v_line.connect_at_start_point:
                # find neighbor broken line
                neighbor_line = self.find_neighbor_broken_vertical_line(v_line, h_lines, v_lines, content_rects, direction="start")
                if neighbor_line:
                    v_line.end_point = (v_line.end_point[0], neighbor_line.end_point[1])
                elif table_height!=-1 and f_check_removable_line(v_line): #14818
                    invalid_lines.add(v_line)
            if not v_line.connect_at_end_point:
                # find neighbor broken line
                neighbor_line = self.find_neighbor_broken_vertical_line(v_line, h_lines, v_lines, content_rects, direction="end")
                if neighbor_line:
                    v_line.end_point = (v_line.end_point[0], neighbor_line.end_point[1])
                elif table_height!=-1 and f_check_removable_line(v_line): #14818
                    invalid_lines.add(v_line)
        table.vertical_lines = list(set(table.vertical_lines)-invalid_lines)
        return table

    def find_neighbor_broken_horizontal_line(self, line, h_lines, v_lines, content_rects, direction):
        rect = Utils.convert_line_to_box(line, orientation="h")
        # find overlap rects
        overlapped_rects = []
        for other_line in h_lines:
            if other_line==line:
                continue
            other_rect = Utils.convert_line_to_box(other_line, orientation="h")
            if Utils.rect_vertical_overlap_rect(rect, other_rect): # verticaly overlap
                # append other rect if not line or content_rect between two rects
                if not (Utils.rect_between_two_rects(rect, other_rect, content_rects, orientation="h", threshold=0) or
                        Utils.line_between_two_rects(rect, other_rect, h_lines, orientation="h", threshold=0)):
                    if direction=="start" and (other_rect[0]+other_rect[2])<rect[0]: # Is other_rect left rect if "start"
                        overlapped_rects.append(other_rect)
                    elif direction=="end" and other_rect[0]>(rect[0]+rect[2]): # Is other_rect right rect if "end"
                        overlapped_rects.append(other_rect)

        # return maximum distance line
        max_distance = -1
        max_rect     = None
        for other_rect in overlapped_rects:
            distance   = Utils.distance_from_box_to_box(rect, other_rect)
            max_distance = max(distance, max_distance) if max_distance!=-1 else distance
            if distance==max_distance:
                max_rect = other_rect
        return Utils.convert_box_to_line(max_rect) if max_rect else max_rect

    def find_neighbor_broken_vertical_line(self, line, h_lines, v_lines, content_rects, direction):
        rect = Utils.convert_line_to_box(line, orientation="v")
        # find overlap rects
        overlapped_rects = []
        for i, other_line in enumerate(v_lines):
            if other_line==line:
                continue
            other_rect = Utils.convert_line_to_box(other_line, orientation="v")
            if Utils.rect_horizontal_overlap_rect(rect, other_rect): # horizontaly overlap
                # append other rect if not line or content_rect between two rects
                if not (Utils.rect_between_two_rects(rect, other_rect, content_rects, orientation="v", threshold=0) or
                        Utils.line_between_two_rects(rect, other_rect, h_lines, orientation="v", threshold=0)):
                    if direction=="start" and (other_rect[1]+other_rect[3])<rect[1]: # Is other_rect above rect if "start"
                        overlapped_rects.append(other_rect)
                    elif direction=="end" and other_rect[1]>(rect[1]+rect[3]): # Is other_rect bellow rect if "end"
                        overlapped_rects.append(other_rect)

        # return maximum distance line
        max_distance = -1
        max_rect     = None
        for other_rect in overlapped_rects:
            distance   = Utils.distance_from_box_to_box(rect, other_rect)
            max_distance = max(distance, max_distance) if max_distance!=-1 else distance
            if distance==max_distance:
                max_rect = other_rect
        return Utils.convert_box_to_line(max_rect) if max_rect else max_rect

    def merge_groups(self, content_groups, group_type="column"):
        """Merge all overlapping content groups
        """
        # extract candidate merge groups
        candidate_groups_list = []
        searched_groups       = []
        for i, src_group in enumerate(content_groups):
            if src_group not in searched_groups:
                candidate_groups_list.append([src_group]) # new group
                searched_groups.append(src_group)
                stack = [src_group]
                while stack:
                    current_group = stack.pop(0) # next group
                    for dst_group in content_groups[i+1:]:
                        if dst_group not in searched_groups:
                            if Utils.rect_overlap_rect(current_group.bounding_rect(), dst_group.bounding_rect()): # check collision
                                candidate_groups_list[-1].append(dst_group) # append dst_group into current candidate
                                stack.insert(0, dst_group)
                                searched_groups.append(dst_group)
        # create new groups
        invalid_groups = []
        merged_groups  = []
        for groups in candidate_groups_list:
            if len(groups)>1:
                new_group = ContentGroupBlock(group_type)
                for group in groups:
                    new_group.extend_content_blocks(group.content_blocks)
                    invalid_groups.append(group)
                merged_groups.append(new_group)
        # remove invalid groups
        for group in invalid_groups:
            if group in content_groups:
                content_groups.remove(group)
        return content_groups+merged_groups

    def merge_content_groups(self, content_groups, content_blocks, group_type="column"):
        """Merge all overlapping content groups
        """
        threshold = 4

        # Find all bounding box rects of content_groups
        bounding_rects = []
        # content_blocks = []
        for content_group in content_groups:

            bounding_rects.append(content_group.bounding_rect())
            content_group_bounding_rect = content_group.bounding_rect()
            content_block_rects = [content_block.bounding_rect for content_block in content_blocks]
            content_block_rects.sort(key=lambda rect: rect[0])
            for content_block_rect in content_block_rects:
                if Utils.rect_overlap_rect_with_width_height(content_group_bounding_rect, content_block_rect, threshold, threshold):
                    content_group_bounding_rect = Utils.bounding_rect([content_group_bounding_rect, content_block_rect])
                    # remove padding after each of merge
                    content_group_bounding_rect = (content_group_bounding_rect[0], content_group_bounding_rect[1],
                                                    content_group_bounding_rect[2] - 1, content_group_bounding_rect[3] - 1)
                    bounding_rects.append(content_group_bounding_rect)

        # Merge all overlapping rects
        merged_rects = Utils.merge_overlap_boxes(bounding_rects, threshold, threshold)

        # if group_type=="column":
        #     # Sort by X position
        #     merged_rects = sorted(merged_rects, key=lambda rect: rect[0])
        # else:
        #     # Sort by Y position
        #     merged_rects = sorted(merged_rects, key=lambda rect: rect[1])
        # invalid_rects = []

        # threshold = 5

        # # Merge all columns/rows with same width/height and position X/Y
        # for i in range(len(merged_rects) - 1):
        #     a_rect = merged_rects[i]
        #     b_rect = merged_rects[i+1]

        #     if group_type=="column":
        #         if abs(a_rect[2] - b_rect[2]) <= threshold and abs(a_rect[0] - b_rect[0]) <= threshold:
        #             merged_rects.append(Utils.bounding_rect([a_rect, b_rect]))
        #             invalid_rects.append(a_rect)
        #             invalid_rects.append(b_rect)

        #     else:
        #         if abs(a_rect[1] - b_rect[1]) <= threshold and abs(a_rect[3] - b_rect[3]) <= threshold:
        #             merged_rects.append(Utils.bounding_rect([a_rect, b_rect]))
        #             invalid_rects.append(a_rect)
        #             invalid_rects.append(b_rect)

        # for rect in invalid_rects:
        #     if rect in merged_rects:
        #         merged_rects.remove(rect)

        merged_content_groups = []

        # Re-group the ContentBlocks to the new ContentGroup
        for group_rect in merged_rects:
            group_content_block = ContentGroupBlock(group_type)

            for content_block in content_blocks:
                if Utils.rect_inside_rect(group_rect, content_block.bounding_rect):
                    group_content_block.append_content_block(content_block)

            merged_content_groups.append(group_content_block)

        # if group_type == "column":
        #     invalid_column_groups = []
        #     for column_group in merged_content_groups:
        #         if len(column_group.content_blocks) < 5 and column_group.single_word_percentage() > 80:
        #             invalid_column_groups.append(column_group)
        #     for column_group in invalid_column_groups:
        #         if column_group in merged_content_groups:
        #             merged_content_groups.remove(column_group)

        return merged_content_groups

    def create_divider_horizontal_lines(self, table, threshold=6):
        """Create virtual lines to divide the table contents
        """

        self.refine_row_groups(table)

        row_groups = table.all_row_groups()

        # Loop all row of text, create a divider line to seperate the row content
        for i in range(len(row_groups) - 1):
            a_rect = row_groups[i].bounding_rect()
            b_rect = row_groups[i+1].bounding_rect()

            # Check if two rects are overlapping, continue
            if a_rect[1] < b_rect[1] < a_rect[1] + a_rect[3] - threshold:
                continue

            if a_rect[0] + a_rect[2] < b_rect[0]:
                continue

            # In case no real table line between two rows, create a new one
            if len(Utils.line_between_two_rects(a_rect, b_rect, table.all_horizontal_lines(), "h", threshold=5)) == 0: #13676(threshold=5)
                # Find the connection point at the left and right
                left_point = Utils.stop_point_at_left(table, (b_rect[0], b_rect[1]))
                right_point = Utils.stop_point_at_right(table, (b_rect[0] + b_rect[2], b_rect[1]))
                if left_point is not None and right_point is not None:
                    divider_line = Line(left_point, right_point, 0, "h")
                    table.append_divider_horizontal_lines(divider_line)

    def create_divider_vertical_lines(self, table):
        """Create virtual lines to divide the table contents
        """
        column_groups = table.all_column_groups()

        # Loop all column of text, create a divider line to seperate the column content
        for i in range(len(column_groups) - 1):
            a_rect = column_groups[i].bounding_rect()
            b_rect = column_groups[i+1].bounding_rect()

            # Check if two rects are overlapping, continue
            if a_rect[0] <= b_rect[0] <= a_rect[0] + a_rect[2] or b_rect[0] <= a_rect[0] <= b_rect[0] + b_rect[2]:
                continue

            # In case no real table line between two columns, create a new one
            if len(Utils.line_between_two_rects(a_rect, b_rect, table.all_vertical_lines(), "v")) == 0:
                # Find the connection point at the top and bottom
                top_point = Utils.stop_point_at_top(table, (b_rect[0], b_rect[1]))
                bottom_point = Utils.stop_point_at_bottom(table, (b_rect[0], b_rect[1] + b_rect[3]))
                if top_point is not None and bottom_point is not None:
                    # Move line to the left because text_block is shrink
                    top_point = (top_point[0] - 5, top_point[1])
                    bottom_point = (bottom_point[0] - 5, bottom_point[1])
                    divider_line = Line(top_point, bottom_point, 0, "v")
                    table.append_divider_vertical_lines(divider_line)

    def need_create_divider_vertical_lines(self, column_groups):
        """Check if table need create virtual vertical lines
        Condition: Table is real-table and table contains at least 2 column blocks with same height
        """
        threshold = 10
        if len(column_groups) == 1:
            return False

        for i in range(len(column_groups) - 1):

            # Only check if a column contain at least 2 content blocks
            if len(column_groups[i].content_blocks) < 2:
                continue

            for j in range(i + 1, len(column_groups)):
                a_rect = column_groups[i].bounding_rect()
                b_rect = column_groups[j].bounding_rect()
                if abs(a_rect[3] - b_rect[3]) <= threshold and abs(a_rect[1] - b_rect[1]) <= threshold:
                    return True
        return False

    def need_create_divider_horizontal_lines(self, row_groups):
        """Check if table need create virtual horizontal lines
        Condition: Table is real-table and table contains at least 2 row blocks with same width
        """
        threshold = 10
        if len(row_groups) == 1:
            return False

        for i in range(len(row_groups) - 1):

            # Only check if a row contain at least 2 content blocks
            if len(row_groups[i].content_blocks) < 2:
                continue

            for j in range(i + 1, len(row_groups)):
                a_rect = row_groups[i].bounding_rect()
                b_rect = row_groups[j].bounding_rect()
                if abs(a_rect[2] - b_rect[2]) <= threshold and abs(a_rect[0] - b_rect[0]) <= threshold:
                    return True
        return False

    def get_table_header_content_blocks(self, table): #13729
        """Get table header content blocks
        """
        threshold = 25
        header_rects = []
        header_content_blocks = []

        # find all content blocks at top of the table (should be table header)
        for content_block in table.content_blocks:
            if content_block.bounding_rect[1] - table.top_border.start_point[1] < threshold:
                header_rects.append(content_block.bounding_rect)
        if len(header_rects) > 0:
            header_rect = Utils.bounding_rect(header_rects)
            for content_block in table.content_blocks:
                if content_block.bounding_rect[1] < header_rect[1] + header_rect[3] - 5:
                    header_content_blocks.append(content_block)

        header_content_blocks = sorted(header_content_blocks, key=lambda content_block: content_block.bounding_rect[0])
        if len(header_content_blocks) == 0:
            if table.row_groups:
                header_content_blocks = table.row_groups[0].content_blocks
            else:
                row_groups = self.group_content_blocks_by_row([], table.content_blocks)
                # Sort by Y position
                row_groups = sorted(row_groups, key=lambda row_group: row_group.bounding_rect()[1])
                if row_groups:
                    header_content_blocks = row_groups[0].content_blocks
        return header_content_blocks

    def refine_table_header_content_blocks(self, table, text_stats_dict):
        """Refine all table header row group: merge all continuous single words to one 
        """
        threshold = 25
        header_rects = []
        header_content_blocks = []

        # find all content blocks at top of the table (should be table header)
        for content_block in table.content_blocks:
            if content_block.bounding_rect[1] - table.top_border.start_point[1] < threshold:
                header_rects.append(content_block.bounding_rect)

        if len(header_rects) > 0:
            header_rect = Utils.bounding_rect(header_rects)

            for content_block in table.content_blocks:
                if content_block.bounding_rect[1] < header_rect[1] + header_rect[3] - 5:
                    header_content_blocks.append(content_block)

        header_content_blocks = sorted(header_content_blocks, key=lambda content_block: content_block.bounding_rect[0])

        if len(header_content_blocks) == 0:
            header_content_blocks = table.row_groups[0].content_blocks

        # ignore noise #14799
        header_content_blocks = [block for block in header_content_blocks if block.area()>text_stats_dict["ave_area"]/2]

        """Merge all single words content blocks in header to be one
        """

        # invalid_content_blocks = []
        groupped_rects = []

        for i in range(len(header_content_blocks)):
            a_content_block = header_content_blocks[i]
            if Utils.rect_in_list(a_content_block.bounding_rect, groupped_rects):
                continue

            rects = [a_content_block.bounding_rect]
            groupped_rects.append(rects)

            for j in range(i + 1, len(header_content_blocks)):
                b_content_block = header_content_blocks[j]
                between_lines = Utils.line_between_two_rects(a_content_block.bounding_rect, b_content_block.bounding_rect, table.all_vertical_lines(), "v", threshold=0) #13451
                between_lines = [line for line in between_lines if line.start_point[1]<=b_content_block.bounding_rect[1]] #13451
                if len(between_lines) != 0:
                    continue

                if not b_content_block.single_word():
                    break

                if a_content_block.is_upper(b_content_block) or a_content_block.is_below(b_content_block): #13676
                    continue

                rects.append(b_content_block.bounding_rect)

        merged_rects = []
        for rects in groupped_rects:
            merged_rects.append(Utils.bounding_rect(rects))

        for content_block in header_content_blocks:
            if content_block in table.content_blocks:
                table.content_blocks.remove(content_block)

        header_content_blocks = [ContentBlock(rect, random.randint(1000, 10000)) for rect in merged_rects]

        table.content_blocks.extend(header_content_blocks)

        return header_content_blocks

    def create_table_divider_lines(self, table, text_stats_dict):
        # In case table have more than 2 rows, consider first one is table header
        row_groups = self.group_content_blocks_by_row([], table.content_blocks)
        # row_groups = self.merge_content_groups(row_groups, table.content_blocks, "row")

        if len(row_groups) > 1:

            # Sort by Y position
            table.row_groups = sorted(row_groups, key=lambda row_group: row_group.bounding_rect()[1])

            header_content_blocks = self.refine_table_header_content_blocks(table, text_stats_dict)

            row_groups = self.group_content_blocks_by_row([], table.content_blocks)
            # table.row_groups = self.merge_content_groups(row_groups, table.content_blocks, "row")

            # Sort by Y position
            table.row_groups = sorted(row_groups, key=lambda row_group: row_group.bounding_rect()[1])

            # header_content_blocks = table.row_groups[0].content_blocks

            non_header_content_blocks = list(set(table.content_blocks) - set(header_content_blocks))

            header_column_groups = self.group_content_blocks_by_column([], header_content_blocks, False)

            column_groups = self.group_content_blocks_by_column([], non_header_content_blocks)
            table.column_groups = self.merge_content_groups(column_groups, non_header_content_blocks, "column")
            all_column_groups = self.group_content_blocks_by_column([], non_header_content_blocks, False) #13409
            all_column_groups = self.merge_content_groups(all_column_groups, table.content_blocks, "column")
            indent_column_groups = self.make_indent_groups(all_column_groups, table.column_groups, [], table.content_blocks, indent_length=text_stats_dict["ave_w"]*4) #12564 => #13641

            #13513
            n_header_content_blocks = len(header_content_blocks)
            if n_header_content_blocks==1:
                n_header_content_blocks = 2
            n_header_columns_groups = len(header_column_groups)
            if n_header_columns_groups==1:
                n_header_columns_groups = 2

            # In case the table have total vertical lines same with columns, dont' need do anything
            if n_header_columns_groups != len(table.all_vertical_lines()) - 1:
                if n_header_content_blocks>=len(table.column_groups):
                    self.merge_table_columns_and_headers(table, header_column_groups)
                    self.remove_invalid_columns(table)
                    self.create_divider_vertical_lines(table)
                elif n_header_content_blocks>=len(indent_column_groups): # case of indent block
                    table.column_groups = indent_column_groups
                    self.merge_table_columns_and_headers(table, header_column_groups)
                    self.remove_invalid_columns(table)
                    self.create_divider_vertical_lines(table)

            self.remove_invalid_rows(table)
            self.create_divider_horizontal_lines(table)

    def remove_invalid_columns(self, table, threshold=5):
        v_lines = table.vertical_lines
        invalid_column_groups = []
        for v_line in v_lines:
            for column_group in table.column_groups:
                if Utils.v_line_inside_box(column_group.bounding_rect(), v_line, threshold):
                    invalid_column_groups.append(column_group)

        for invalid_column_group in invalid_column_groups:
            if invalid_column_group in table.column_groups:
                table.column_groups.remove(invalid_column_group)

    def remove_invalid_rows(self, table, threshold=5):
        h_lines = table.horizontal_lines
        invalid_row_groups = []
        for h_line in h_lines:
            for row_group in table.row_groups:
                if Utils.h_line_inside_box(row_group.bounding_rect(), h_line, threshold):
                    invalid_row_groups.append(row_group)

        for invalid_row_group in invalid_row_groups:
            if invalid_row_group in table.row_groups:
                table.row_groups.remove(invalid_row_group)

    def merge_table_columns_and_headers(self, table, header_column_groups, threshold=5):
        image_size = self.input_image.shape
        blank_image = np.zeros((image_size[0], image_size[1], 1), np.uint8)

        for header_column_group in header_column_groups:
            header_rect = header_column_group.bounding_rect()
            Utils.draw_box(blank_image, header_rect, (255, 255, 255), 1)
            for column_group in table.column_groups:
                column_rect = column_group.bounding_rect()
                Utils.draw_box(blank_image, column_rect, (255, 255, 255), 1)
                if header_rect[0] - threshold <= column_rect[0] <= header_rect[0] + header_rect[2] + threshold \
                        or header_rect[0] - threshold <= column_rect[0] + column_rect[2] <= header_rect[0] + header_rect[2] + threshold:
                    overlap_rect = Utils.bounding_rect([header_rect, column_rect])
                    Utils.draw_box(blank_image, overlap_rect, (255, 255, 255), 1)
                if column_rect[0] - threshold <= header_rect[0] <= column_rect[0] + column_rect[2] + threshold \
                        or column_rect[0] - threshold <= header_rect[0] + header_rect[2] <= column_rect[0] + column_rect[2] + threshold:
                    overlap_rect = Utils.bounding_rect([column_rect, header_rect])
                    Utils.draw_box(blank_image, overlap_rect, (255, 255, 255), 1)

        contours = cv2.findContours(blank_image.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]

        column_groups = []

        for rect in rects:
            group_content_block = ContentGroupBlock("column")
            for content_block in table.content_blocks:
                if Utils.rect_inside_rect(rect, content_block.bounding_rect):
                    group_content_block.append_content_block(content_block)

                if len(group_content_block.content_blocks) > 0:
                    column_groups.append(group_content_block)
            
        table.column_groups = column_groups

    def process_table(self, boxes, lines, content_blocks, text_stats_dict):
        """
        :param boxes: these bounding box of a table
        :param lines: the list of these line in the image
        :param content_blocks: list of text block coordination
        :return: list of table with real line and virtual line
        """
        tables = []
        boxes.sort(key=lambda table_box: table_box.bounding_rect[2] * table_box.bounding_rect[3])
        for i, table_box in enumerate(boxes):
            box = table_box.bounding_rect
            table_lines = []
            # find table which line belongs to
            for line in lines:
                if Utils.line_inside_table_box(box, line, 5) and not line.table_line:
                    line.table_line = True
                    table_lines.append(line)

            table = Table(table_box.real_table)

            # find table which content block belongs to
            for content_block in content_blocks:
                if content_block.table_content_block:
                    continue

                if Utils.rect_inside_rect(box, content_block.bounding_rect, 5):
                    content_block.table_content_block = True
                    table.append_content_block(content_block)

            h_lines, v_lines = Utils.split_lines(table_lines)
            h_lines, v_lines = Utils.sort_lines(h_lines, v_lines)

            h_lines, v_lines = Utils.shrink_line(h_lines, v_lines)

            self.connect_table_borders(box, table, h_lines, v_lines)

            # extend horizontal line inside table. Make these lines inside table connect to each others
            self.connect_table_horizontal_lines(table)
            self.connect_table_vertical_lines(table)

            # connect or "remove(if invalid line)" broken lines #12594->#14818
            # self.connect_broken_horizontal_line(table)
            self.connect_broken_vertical_line(table)

            # remove vertical header lines #13027->#13729
            self.remove_vertical_header_lines(table)

            # merge those line which is the really near each others to become to one line
            self.merge_nearby_lines(table)

            # create virtual lines
            self.create_table_divider_lines(table, text_stats_dict)

            # make the vertical line connect to the header of these table.
            self.extend_to_header_border(table, table.content_blocks)

            # remove wrong virtual vertical lines
            self.refine_virtual_vertical_lines(table, table.content_blocks)

            # remove wrong virtual horizontal lines
            self.refine_virtual_horizontal_lines(table, table.content_blocks)

            # extend the real line if it can not connect to the true vertical lines
            # self.extend_real_line_in_table(table)

            tables.append(table)

        return tables

    def refine_virtual_vertical_lines(self, table, content_blocks):
        """
        :param table: the table
        :param content_blocks: the content block inside the table
        :return: A vertical line is considered as invalid virtual vertical line
                    when the bounding box between the virtual vertical line and the nearest real vertical line
                    do not contains any text block
        """
        content_rects = [content_block.bounding_rect for content_block in content_blocks]
        v_lines = table.all_vertical_lines()
        v_lines = list(set(v_lines)-set([table.left_border, table.right_border])) #13676
        v_lines.sort(key=lambda line: line.start_point[0])
        v_virtual_lines = table.divider_vertical_lines
        v_virtual_lines.sort(key=lambda line: line.start_point[0])
        invalid_virtual_lines = []
        for i in range(len(v_virtual_lines)):
            for j in range(len(v_lines) - 1):
                if v_lines[j].start_point[0] < v_virtual_lines[i].start_point[0] < v_lines[j + 1].start_point[0]:
                    bounding_lines_rect_left = Utils.bounding_lines_virtual_line_real_line(v_virtual_lines[i], v_lines[j], 'v')
                    bounding_lines_rect_right = Utils.bounding_lines_virtual_line_real_line(v_virtual_lines[i], v_lines[j+1], 'v')
                    if not Utils.is_rect_contains_rects(bounding_lines_rect_left, content_rects) or \
                            not Utils.is_rect_contains_rects(bounding_lines_rect_right, content_rects):
                        invalid_virtual_lines.append(v_virtual_lines[i])

        for v_line in v_virtual_lines:
            if Utils.is_line_cut_rects(v_line, content_rects, 'v', -10):
                invalid_virtual_lines.append(v_line)

        for invalid_virtual_line in invalid_virtual_lines:
            if invalid_virtual_line in v_virtual_lines:
                v_virtual_lines.remove(invalid_virtual_line)

        table.divider_vertical_lines = v_virtual_lines

    def refine_virtual_horizontal_lines(self, table, content_blocks):
        threshold = -13
        content_rects = [content_block.bounding_rect for content_block in content_blocks]
        h_lines = table.all_horizontal_lines()
        h_lines = list(set(h_lines)-set([table.top_border, table.bottom_border])) #13676

        h_lines.sort(key=lambda line: line.start_point[1])
        h_virtual_lines = table.divider_horizontal_lines
        h_virtual_lines.sort(key=lambda line: line.start_point[1])
        invalid_virtual_lines = []
        for i in range(len(h_virtual_lines)):
            for j in range(len(h_lines) - 1):
                if h_lines[j].start_point[1] < h_virtual_lines[i].start_point[1] < h_lines[j + 1].start_point[1]:
                    bounding_lines_rect_top = Utils.bounding_lines_virtual_line_real_line(h_virtual_lines[i], h_lines[j], 'h')
                    bounding_lines_rect_down = Utils.bounding_lines_virtual_line_real_line(h_virtual_lines[i], h_lines[j + 1], 'h')
                    if not Utils.is_rect_contains_rects(bounding_lines_rect_top, content_rects) or \
                            not Utils.is_rect_contains_rects(bounding_lines_rect_down, content_rects):
                        invalid_virtual_lines.append(h_virtual_lines[i])

        for h_line in h_virtual_lines:
            if Utils.is_line_cut_rects(h_line, content_rects, 'h', threshold):
                invalid_virtual_lines.append(h_line)

        for invalid_virtual_line in invalid_virtual_lines:
            if invalid_virtual_line in h_virtual_lines:
                h_virtual_lines.remove(invalid_virtual_line)

        table.divider_horizontal_lines = h_virtual_lines

    def extend_real_line_in_table(self, table):
        """
            if the line between two rows, and width of the row approximately equal width of table,
            the horizontal line's width will be extend equal to table's width
        """
        THRESHOLD_INTERSECTION_DISTANCE = 3
        threshold_to_extend_line = 0.5
        # extend horizontal lines
        row_groups = [row_group.bounding_rect() for row_group in table.row_groups]
        row_groups = sorted(row_groups, key=lambda row_group: row_group[1])

        max_table_width = table.right_border.start_point[0] - table.left_border.start_point[0]

        if max_table_width != 0:
            for i in range(len(row_groups) - 1):
                a_rect = row_groups[i]
                b_rect = row_groups[i + 1]
                max_row_width = max(a_rect[2], b_rect[2])

                if max_row_width / max_table_width > threshold_to_extend_line:
                    h_lines = Utils.line_between_two_rects(a_rect, b_rect, table.horizontal_lines, "h")
                    if len(h_lines) == 1:
                        temp_line = copy.copy(h_lines[0])

                        # extend if not h_line start point on the intersection point
                        if not Utils.is_start_point_on_intersection(h_lines[0], "h", THRESHOLD_INTERSECTION_DISTANCE): # add at #12511
                            temp_line.start_point = (table.left_border.start_point[0], temp_line.start_point[1])
                            if not Utils.is_point_in_line(temp_line.start_point, table.left_border):
                                continue

                        # extend if not h_line end point on the intersection point (#12511)
                        if not Utils.is_end_point_on_intersection(h_lines[0], "h", THRESHOLD_INTERSECTION_DISTANCE):
                            temp_line.end_point = (table.right_border.start_point[0], temp_line.end_point[1])
                            if not Utils.is_point_in_line(temp_line.end_point, table.right_border):
                                continue

                        if Utils.is_line_cut_rects(temp_line, [content_block.bounding_rect for content_block in table.content_blocks], 'h', -6):
                            continue

                        if h_lines[0] in table.horizontal_lines:
                            table.horizontal_lines.remove(h_lines[0])
                            table.horizontal_lines.append(temp_line)

    def extend_to_header_border(self, table, content_blocks):
        """
            make the vertical line connect to the header of these table.
        """
        content_rects = [content_block.bounding_rect for content_block in content_blocks]
        h_lines = sorted(table.horizontal_lines, key=lambda h_line: h_line.start_point[1])
        top_border = table.top_border
        height_header = 50
        threshold = 10
        THRESHOLD_INTERSECTION_DISTANCE = 3

        if len(table.horizontal_lines) > 0 and len(table.all_horizontal_lines() + table.divider_horizontal_lines) > threshold:
            last_horizontal_line = h_lines[-1]
            for idx, line in enumerate(table.vertical_lines):
                if Utils.is_intersect(last_horizontal_line, line) and not Utils.is_intersect(top_border, line):
                    intersection_point = Utils.line_intersection(line, top_border)
                    if intersection_point[0] and intersection_point[1]:
                        if intersection_point[1] == top_border.start_point[1] \
                                and top_border.start_point[0] <= intersection_point[0] <= top_border.end_point[0]:
                            if not Utils.is_start_point_on_intersection(line, "v", THRESHOLD_INTERSECTION_DISTANCE): #12793
                                temp_line = copy.copy(line)
                                temp_line.start_point = (line.start_point[0], top_border.start_point[1])
                                if (line.start_point[1] - top_border.start_point[1]) <= height_header \
                                    and not Utils.is_line_cut_rects(temp_line, content_rects, 'v'):
                                    table.vertical_lines[idx] = temp_line

    def remove_vertical_header_lines(self, table): #13027
        """
        Remove invalid table header lines

        :param table:
        :return removed table:

        invalid line is line has not text from left neighbor line

        image:
        [valid line]      [invalid line(has not text)]
        -------------     -------------            -------------
        |  0  |  1  |     |     |  0  |            |  0  |     |
        -------------     -------------     OR     -------------
        | abc | def |     |     | abc |            | abc |     |
        -------------     -------------            -------------
              .                 .                        .      
              .                 .                        .      
              .                 .                        .      
        """                                                    
        def sort_key_f(x):
            return x.start_point[0]

        COUNTDOWN = 5 # limit of divide content_rect #13729

        v_lines       = table.all_vertical_lines()
        content_blocks = table.content_blocks
        # exclude header blocks
        header_content_blocks = self.get_table_header_content_blocks(table)
        content_blocks = list(set(content_blocks)-set(header_content_blocks))
        content_rects = [content_block.bounding_rect for content_block in content_blocks]
        # extract connected header lines
        connected_v_lines = [v_line for v_line in v_lines if v_line.connect_at_start_point and v_line.start_point[1]==table.top_border.start_point[1]]
        # extract halfway header lines from connected_v_lines #13729
        halfway_lines = [v_line for v_line in connected_v_lines if v_line.end_point[1]!=table.bottom_border.end_point[1]]
        connected_v_lines_for_right = sorted(list(set(connected_v_lines)-set(halfway_lines)), key=sort_key_f)

        # extract invalid header lines
        invalid_lines = []
        for v_line in halfway_lines:
            if v_line==table.left_border or v_line==table.right_border:
                continue
            # find left and right neighbor line
            left_neighbor_line = Utils.vertical_left_neighbor_line(v_line, connected_v_lines, invalid_lines)
            right_neighbor_line = Utils.vertical_right_neighbor_line(v_line, connected_v_lines_for_right, invalid_lines) #13729
            # expand v_line to bottom border line
            expanded_v_line = Line(v_line.start_point, (v_line.end_point[0], table.bottom_border.end_point[1]), 0, orientation="v")

            # check invalid line
            if left_neighbor_line and right_neighbor_line:
                # v_line append to invalid_lines,
                left_tmp_rect = Utils.bounding_rect_lines(None, [v_line, left_neighbor_line]) # create rect from v_line and left_neighbor_line
                right_tmp_rect = Utils.bounding_rect_lines(None, [v_line, right_neighbor_line]) # create rect from v_line and right_neighbor_line #13729
                left_has_content_rect  = False
                right_has_content_rect = False
                countdown = COUNTDOWN # limit of divide content_rect #13729
                for content_rect in content_rects:
                    # if has not content_rect
                    if not left_has_content_rect and Utils.rect_inside_rect(left_tmp_rect, content_rect):
                        left_has_content_rect = True
                    if not right_has_content_rect and Utils.rect_inside_rect(right_tmp_rect, content_rect): #13729
                        right_has_content_rect = True
                    # if divide content_rect #13729
                    if Utils.v_line_overlap_rect(expanded_v_line, content_rect):
                        countdown -= 1
                    if countdown<=0:
                        break
                if not left_has_content_rect or not right_has_content_rect or countdown<=0:
                    invalid_lines.append(v_line)

        # remove invalid_line from header v_lines
        for invalid_line in invalid_lines:
            if invalid_line in v_lines:
                v_lines.remove(invalid_line)
        self.set_table_vertical_lines(table, v_lines)
        return table

    def same_indent_groups(self, all_column_groups, boxes):
        """
        Extract same indent level groups
        
        :param all_column_groups:
        :param boxes: real boxes
        :return indent_groups: [[same_group0, ...], [same_groups1, ...]]
        """
        THRESH_WIDTH = 10

        all_column_groups = sorted(all_column_groups, key=lambda group:(group.bounding_rect()[0], group.bounding_rect()[1])) # sort x,y
        all_column_rects  = [group.bounding_rect() for group in all_column_groups]
        indent_groups     = []
        added_groups      = []
        for i, head_rect in enumerate(all_column_rects):
            current_indent_groups = [all_column_groups[i]]
            if all_column_groups[i] in added_groups:
                continue
            for j, next_rect in enumerate(all_column_rects[i+1:], start=i+1):
                if Utils.rect_between_two_rects(head_rect, next_rect, boxes, orientation="v"):
                    break
                if head_rect[0]-THRESH_WIDTH<=next_rect[0]<=head_rect[0]+THRESH_WIDTH: # check same width
                    current_indent_groups.append(all_column_groups[j])
            added_groups.extend(current_indent_groups)
            indent_groups.append(current_indent_groups)
        return indent_groups

    def merge_indent_groups(self, same_indent_groups, boxes, indent_length):
        """
        Merge indent groups by indent length

        :param same_indent_groups:
        :param indent_length:
        :param boxes:
        :return merged_indent_groups: [merged_group0, merged_group1, ...]
        """
        merged_indent_groups = []
        added_indent_groups  = []
        invalid_groups       = []
        for i, head_groups in enumerate(same_indent_groups):
            if head_groups in added_indent_groups:
                continue
            merge_flag = False
            head_rect  = Utils.bounding_rect([group.bounding_rect() for group in head_groups])
            current_indent_length = head_rect[0]+indent_length
            added_indent_groups.append(head_groups)
            for j, next_groups in enumerate(same_indent_groups[i+1:], start=i+1):
                next_rect = Utils.bounding_rect([group.bounding_rect() for group in next_groups])
                if head_rect[1]>=next_rect[1]+next_rect[3]: # skip if next_rect upper head rect
                    continue
                if Utils.rect_between_two_rects(head_rect, next_rect, boxes, orientation="v"):
                    break
                if head_rect[0]<=next_rect[0]<=current_indent_length: # check indent
                    head_groups.extend(next_groups) # merge groups
                    added_indent_groups.append(next_groups)
                    current_indent_length = next_rect[0]+indent_length # update indent length
                    merge_flag = True
            if merge_flag and len(head_groups)>1: # merge into head_group
                head_group = copy.deepcopy(head_groups[0])
                for group in head_groups[1:]:
                    head_group.extend_content_blocks(group.content_blocks)
                merged_indent_groups.append(head_group)
                invalid_groups.extend(head_groups[1:])
                break # extract only first indent group
            else:
                invalid_groups.extend(head_groups)
        return merged_indent_groups, invalid_groups

    def make_indent_groups(self, all_column_groups, column_groups, boxes, content_blocks, indent_length):
        """
        Make one group including indents

        :param column_groups:
        :param boxes: real boxes
        :param accept_indent: accept number of indent in same group
        :return: merged culumn groups
        """
        # extract same indent groups
        same_indent_groups = sorted(self.same_indent_groups(all_column_groups, boxes), key=lambda groups:groups[0].bounding_rect()[0]) # sort x
        # merge indent groups as same indent range
        merged_indent_groups, invalid_groups = self.merge_indent_groups(same_indent_groups, boxes, indent_length)
        # add not indent groups
        merged_indent_groups.extend(list(set(column_groups)-set(invalid_groups)))
        # merge overlap groups
        merged_column_groups = self.merge_content_groups(merged_indent_groups, content_blocks, group_type="column")
        return merged_column_groups

    def header_rows(self, row_groups): #13968
        blocks_list = [[block.bounding_rect for block in group.content_blocks] for group in row_groups]
        header_rows = []
        for i, blocks in enumerate(blocks_list):
            if len(blocks)>1 and Utils.is_text_blocks_header_by_header_dict(blocks, self.crnn_chars, self.header_regex): # is header blocks?
                header_rows.append(row_groups[i])
        return header_rows

    def search_total_str_row(self, header_row, next_header_row, row_groups):
        """Search row containing total string
        """
        row_rects = [row_group.bounding_rect() for row_group in row_groups]
        header_rect = header_row.bounding_rect()
        # extract target groups
        if next_header_row:
            target_row_rects = Utils.rect_between_two_rects(header_rect, next_header_row.bounding_rect(), row_rects, return_rects=True)
        else:
            target_row_rects = Utils.rects_under_rect(header_rect, row_rects, return_rects=True)
        target_row_groups = [row_groups[row_rects.index(row_rect)] for row_rect in target_row_rects if row_rect in row_rects]
        target_row_groups.sort(key=lambda group:group.bounding_rect()[1])
        for group in target_row_groups:
            text_list = [Utils.search_text_by_box(self.crnn_chars, block.bounding_rect) for block in group.content_blocks]
            text_list = Utils.merge_single_chars(text_list)
            text_list = [text.replace(' ', '') for text in text_list]
            for text in text_list:
                if re.search("(total|合計|小計)", text.lower()): #TODO:use footer dict
                    return group
        return False

    def adjust_first_column_height(self, column_groups, header_row): #13993
        """Adjust height too long first column
        """
        column_groups = [g for g in column_groups if Utils.rect_overlap_rect(g.bounding_rect(), header_row.bounding_rect())] #column valid only it overlap to header_row
        if len(column_groups)<=1:
            return column_groups
        column_groups = sorted(column_groups, key=lambda group:group.bounding_rect()[0]) # sort x
        first_column_group = column_groups[0]
        first_column_rect  = first_column_group.bounding_rect()
        if Utils.distance_from_point_to_point(header_row.bounding_rect()[:2], first_column_rect[:2])>first_column_rect[3]: # return if far from header's top left to first_column's top left than first column's width #14403
            return column_groups
        rect = list(first_column_group.bounding_rect())
        max_bottom = max([g.bounding_rect()[1]+g.bounding_rect()[3] for g in column_groups[1:]]) # max bottom from second column
        if rect[1]+rect[3]>max_bottom:
            rect[3] = max_bottom-rect[1]
            content_rects = [block.bounding_rect for block in first_column_group.content_blocks]
            first_column_group.content_blocks = Utils.get_rect_contains_blocks(rect, first_column_group.content_blocks) # adjust
        return column_groups

    def find_posible_table_box_by_header_dict(self, table_boxes, single_content_blocks, text_stats_dict): #13968
        """Try to find out all bounding box of available tables from content blocks by header dict
        """
        boxes = [table_box.bounding_rect for table_box in table_boxes]
        single_content_rects = [block.bounding_rect for block in single_content_blocks]

        row_groups = self.group_content_blocks_by_row(boxes, single_content_blocks, False) #14403(add False)
        row_groups = self.merge_content_groups(row_groups, single_content_blocks, "row")

        # Ignore two small rows #13632->#14222->#14403(comment)
        # row_groups = [row_group for row_group in row_groups if row_group.bounding_rect()[2] > 70 and row_group.bounding_rect()[3] > text_stats_dict["ave_h"]*0.8]
        # extract header rows
        header_rows = self.header_rows(row_groups)
        if not header_rows:
            return []
        header_rows.sort(key=lambda group:group.bounding_rect()[1]) # sort y

        # DEBUG
        if Debug.debug_flag==1:
            header_rows_image = self.input_image.copy()
            Utils.draw_groups(header_rows_image, header_rows, color=(0, 0, 255), thickness=1)
            Debug.write_image(header_rows_image, self.debug_save_path + "3.2.11 header_rows_image.jpg")

        table_boxes = []
        for i, header_row in enumerate(header_rows):
            # extract content blocks between header row and next header row
            next_header_row = None if i+1>=len(header_rows) else header_rows[i+1]
            # or search row containing total string
            total_str_row = self.search_total_str_row(header_row, next_header_row, row_groups) #14322
            # resize header_row, because want to contain header content rect
            x,y,w,h = header_row.bounding_rect()
            resized_header_rect = (x,y-2,w,1)
            if total_str_row:
                content_rects = Utils.rect_between_two_rects(resized_header_rect, total_str_row.bounding_rect(), single_content_rects, return_rects=True)
            elif next_header_row:
                content_rects = Utils.rect_between_two_rects(resized_header_rect, next_header_row.bounding_rect(), single_content_rects, return_rects=True)
            else:
                content_rects = Utils.rects_under_rect(resized_header_rect, single_content_rects, return_rects=True)
            content_blocks = [ContentBlock(content_rect, i) for i, content_rect in enumerate(content_rects)]

            column_groups = self.group_content_blocks_by_column(boxes, content_blocks)
            column_groups = self.merge_groups(column_groups, group_type="column")
            # Ignore two small columns #13632
            column_groups = [column_group for column_group in column_groups if column_group.bounding_rect()[2] > text_stats_dict["ave_w"] and column_group.bounding_rect()[3] > 70] #13501
            column_groups = self.adjust_first_column_height(column_groups, header_row) #13993

            # TODO:optimize
            image_size = self.input_image.shape
            blank_image = np.zeros((image_size[0], image_size[1], 1), np.uint8)
            for i, column_group in enumerate(column_groups):
                for row_group in row_groups:
                    if Utils.rect_overlap_rect(column_group.bounding_rect(), row_group.bounding_rect()): #13409
                        Utils.draw_box(blank_image, row_group.bounding_rect(), (255, 255, 255), 1)
                        Utils.draw_box(blank_image, column_group.bounding_rect(), (255, 255, 255), 1)
            contours = cv2.findContours(blank_image.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]
            rects = [cv2.boundingRect(c) for c in contours]
            rects = [Utils.expand_width_rect(rect, 5) for rect in rects]
            if not rects: #14782
                continue

            invalid_rects = []
            # The valid box contain at least 2 columns or 2 rows
            col_count = 0
            row_count = 0
            columns_in_rect = []
            rows_in_rect = []
            header_rect  = rects[0]
            for column_group in column_groups:
                if Utils.rect_inside_rect(header_rect, column_group.bounding_rect()):
                    columns_in_rect.append(column_group.bounding_rect())
                    col_count += 1
            for row_group in row_groups:
                if Utils.rect_inside_rect(header_rect, row_group.bounding_rect()):
                    rows_in_rect.append(row_group.bounding_rect())
                    row_count += 1

            # table is valid when it contains at least 2 rows have same width and x position and
            # 2 columns have same height and y position
            valid_table_column_top    = False #12564
            # valid_table_column_bottom = False #12564
            valid_table_row = False
            threshold = 100
            # check table has valid column
            for i in range(len(columns_in_rect) - 1):
                for j in range(i + 1, len(columns_in_rect)):
                    a_rect = columns_in_rect[i]
                    b_rect = columns_in_rect[j]
                    if abs(a_rect[1] - b_rect[1]) < threshold: #13501
                        valid_table_column_top = True
                    # if abs(a_rect[3] - b_rect[3]) < threshold:
                    #     valid_table_column_bottom = True
                    # if valid_table_column_top and valid_table_column_bottom:
                    if valid_table_column_top:
                        break
                # if valid_table_column_top and valid_table_column_bottom:
                if valid_table_column_top:
                    break
            # check table has valid row
            for i in range(len(rows_in_rect) - 1):
                for j in range(i + 1, len(rows_in_rect)):
                    a_rect = rows_in_rect[i]
                    b_rect = rows_in_rect[j]
                    if abs(a_rect[0] - b_rect[0]) < threshold / 3 and abs(a_rect[2] - b_rect[2]) < threshold: #14222(5->3)
                        valid_table_row = True
                        break
                if valid_table_row:
                    break

            # if row_count < 2 or col_count < 2 or not valid_table_row or not valid_table_column_top or not valid_table_column_bottom:
            if row_count < 2 or col_count < 2 or not valid_table_row or not valid_table_column_top:
                if len(rects)>=2: # force create box if find header #14782
                    new_rect = Utils.bounding_rect([header_rect, rect[1]])
                    if len(rects)>=3:
                        rects = [new_rect]+rects[2:]
                    else:
                        rects = [new_rect]
                # invalid_rects.append(header_rect) #14782(comment)

            # The valid box doesn't overlap with any other existing boxes
            for box in boxes:
                if Utils.rect_overlap_rect_with_percent(header_rect, box, 2):
                    invalid_rects.append(header_rect)

            valid_rects = list(set(rects) - set(invalid_rects))

            for rect in valid_rects:
                table_box = TableBox(rect, False)

                for content_block in single_content_blocks:
                    if Utils.rect_inside_rect(rect, content_block.bounding_rect):
                        table_box.content_blocks.append(content_block)

                table_boxes.append(table_box)

        return table_boxes

    def find_posible_table_box_from_content_blocks(self, table_boxes, single_content_blocks, text_stats_dict, header_virtual_boxes):
        """Try to find out all bounding box of available tables from content blocks
        """
        boxes = [table_box.bounding_rect for table_box in table_boxes]

        # DEBUG
        if Debug.debug_flag==1:
            single_content_blocks_image = self.input_image.copy()
            boxes_image                 = self.input_image.copy()
            Utils.draw_content_blocks(single_content_blocks_image, single_content_blocks, color=(255, 0, 255), thickness=1)
            Utils.draw_boxes(boxes_image, boxes, color=(0, 255, 0), thickness=1)
            Debug.write_image(single_content_blocks_image, self.debug_save_path + "3.1.1 single_content_blocks_image.jpg")
            Debug.write_image(boxes_image, self.debug_save_path + "3.1.2 real_table_boxes_image.jpg")

        column_groups = self.group_content_blocks_by_column(boxes, single_content_blocks)
        row_groups = self.group_content_blocks_by_row(boxes, single_content_blocks)

        # DEBUG
        if Debug.debug_flag==1:
            row_image        = self.input_image.copy()
            column_image     = self.input_image.copy()
            Utils.draw_groups(row_image, row_groups, color=(0, 0, 255), thickness=1)
            Utils.draw_groups(column_image, column_groups, color=(0, 0, 255), thickness=1)
            Debug.write_image(row_image, self.debug_save_path + "3.1.3 raw_row_image.jpg")
            Debug.write_image(column_image, self.debug_save_path + "3.1.4 raw_column_image.jpg")

        column_groups = self.merge_content_groups(column_groups, single_content_blocks, "column")
        row_groups = self.merge_content_groups(row_groups, single_content_blocks, "row")

        # DEBUG
        if Debug.debug_flag==1:
            row_image        = self.input_image.copy()
            column_image     = self.input_image.copy()
            Utils.draw_groups(row_image, row_groups, color=(0, 0, 255), thickness=1)
            Utils.draw_groups(column_image, column_groups, color=(0, 0, 255), thickness=1)
            Debug.write_image(row_image, self.debug_save_path + "3.1.5 merged_row_image.jpg")
            Debug.write_image(column_image, self.debug_save_path + "3.1.6 merged_column_image.jpg")

        # Ignore two small columns and rows #13632
        single_word_blocks = [block for block in single_content_blocks if block.single_word()]
        column_groups = [column_group for column_group in column_groups if column_group.bounding_rect()[2] > text_stats_dict["ave_w"] and column_group.bounding_rect()[3] > 70] #13501
        row_groups = [row_group for row_group in row_groups if row_group.bounding_rect()[2] > 70 and row_group.bounding_rect()[3] > text_stats_dict["ave_h"]]

        # DEBUG
        if Debug.debug_flag==1:
            row_image         = self.input_image.copy()
            column_image      = self.input_image.copy()
            Utils.draw_groups(row_image, row_groups, color=(0, 0, 255), thickness=1)
            Utils.draw_groups(column_image, column_groups, color=(0, 0, 255), thickness=1)
            Debug.write_image(row_image, self.debug_save_path + "3.1.7 removed_row_image.jpg")
            Debug.write_image(column_image, self.debug_save_path + "3.1.8 removed_column_image.jpg")

        image_size = self.input_image.shape
        blank_image = np.zeros((image_size[0], image_size[1], 1), np.uint8)

        overlapping_groups = []

        for column_group in column_groups:
            for row_group in row_groups:
                if Utils.rect_overlap_rect(column_group.bounding_rect(), row_group.bounding_rect()): #13409
                    overlapping_groups.append(row_group)
                    overlapping_groups.append(column_group)

        for group in overlapping_groups:
            Utils.draw_box(blank_image, group.bounding_rect(), (255, 255, 255), 1)

        contours = cv2.findContours(blank_image.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]
        rects = [Utils.expand_width_rect(rect, 5) for rect in rects]

        invalid_rects = []
        for rect in rects:

            # The valid box contain at least 2 columns or 2 rows
            col_count = 0
            row_count = 0
            columns_in_rect = []
            rows_in_rect = []
            for column_group in column_groups:
                if Utils.rect_inside_rect(rect, column_group.bounding_rect()):
                    columns_in_rect.append(column_group.bounding_rect())
                    col_count += 1
            for row_group in row_groups:
                if Utils.rect_inside_rect(rect, row_group.bounding_rect()):
                    rows_in_rect.append(row_group.bounding_rect())
                    row_count += 1

            # table is valid when it contains at least 2 rows have same width and x position and
            # 2 columns have same height and y position
            valid_table_column_top    = False #12564
            valid_table_column_bottom = False #12564
            valid_table_row = False
            threshold = 100
            # check table has valid column
            for i in range(len(columns_in_rect) - 1):
                for j in range(i + 1, len(columns_in_rect)):
                    a_rect = columns_in_rect[i]
                    b_rect = columns_in_rect[j]
                    if abs(a_rect[1] - b_rect[1]) < threshold: #13501
                        valid_table_column_top = True
                    if abs(a_rect[3] - b_rect[3]) < threshold:
                        valid_table_column_bottom = True
                    if valid_table_column_top and valid_table_column_bottom:
                        break
                if valid_table_column_top and valid_table_column_bottom:
                    break
            # check table has valid row
            for i in range(len(rows_in_rect) - 1):
                for j in range(i + 1, len(rows_in_rect)):
                    a_rect = rows_in_rect[i]
                    b_rect = rows_in_rect[j]
                    if abs(a_rect[0] - b_rect[0]) < threshold / 5 and abs(a_rect[2] - b_rect[2]) < threshold:
                        valid_table_row = True
                        break
                if valid_table_row:
                    break

            if row_count < 2 or col_count < 2 or not valid_table_row or not valid_table_column_top or not valid_table_column_bottom:
                invalid_rects.append(rect)

            # The valid box doesn't overlap with any other existing boxes (and header_virtual_boxes #13968)
            for box in boxes+[b.bounding_rect for b in header_virtual_boxes]:
                if Utils.rect_overlap_rect_with_percent(rect, box, 2):
                    invalid_rects.append(rect)

        valid_rects = list(set(rects) - set(invalid_rects))

        table_boxes = []

        for rect in valid_rects:
            table_box = TableBox(rect, False)

            for content_block in single_content_blocks:
                if Utils.rect_inside_rect(rect, content_block.bounding_rect):
                    table_box.content_blocks.append(content_block)

            table_boxes.append(table_box)

        return table_boxes

    def merge_real_and_virtual_table_boxes(self, table_boxes, header_virtual_boxes):
        """Find all possible pattern like: one real table is header of virtual table and merge both to one
        """
        threshold = 10

        virtual_boxes = [table_box for table_box in table_boxes if not table_box.real_table]
        real_boxes = [table_box for table_box in table_boxes if table_box.real_table]

        # Sort list by Y postion
        sorted(virtual_boxes, key=lambda table_box: table_box.bounding_rect[1])
        sorted(real_boxes, key=lambda table_box: table_box.bounding_rect[1])

        """
        Try to find pattern:
        1. Real box nearby virtual box
        2. Real box and virtual box have same start or end X position
        Merge these boxes into one
        """
        invalid_boxes = []
        overlap_rects = []

        for real_box in real_boxes:
            r_column_groups = self.group_content_blocks_by_column([], real_box.content_blocks, False)
            for virtual_box in virtual_boxes:
                r_rect = real_box.bounding_rect
                v_rect = virtual_box.bounding_rect

                # Check two box near enought by Y postion
                if abs(r_rect[1] + r_rect[3] - v_rect[1]) > threshold and abs(v_rect[1] + v_rect[3] - r_rect[1]) > threshold:
                    continue

                # Check two box have same start or end X postion
                if abs(r_rect[0] - v_rect[0]) > 2 * threshold and abs(v_rect[0] + v_rect[2] - r_rect[0] - r_rect[2]) > 2 * threshold:
                    continue

                # If two box have large different of width, just continue
                if abs(r_rect[2] - v_rect[2]) / (r_rect[2] if r_rect[2] > v_rect[2] else v_rect[2]) > 0.3:
                    continue

                v_column_groups = self.group_content_blocks_by_column([], virtual_box.content_blocks, False)

                # Continue if real box or virtual box have just one column
                if len(v_column_groups) < 2 or len(r_column_groups) < 2:
                    continue

                overlap_rects.append(Utils.bounding_rect([r_rect, v_rect]))
                invalid_boxes.append(real_box)
                invalid_boxes.append(virtual_box)

        merged_rects = Utils.external_rects(self.input_image.shape, overlap_rects)

        for rect in merged_rects:
            table_boxes.append(TableBox(rect, False))

        for table_box in invalid_boxes:
            if table_box in table_boxes:
                table_boxes.remove(table_box)

        table_boxes.extend(header_virtual_boxes) # not merge header_virtual_boxes #13968

        # Create new borders (left, right) for new virtual box. Don't need top/bottom border because the real-table already have top/bottom border
        border_lines = []
        for table_box in table_boxes:

            # if the table box is real-table, continue
            if table_box.real_table:
                continue

            x, y, w, h = table_box.bounding_rect
            left_border = Line((x, y), (x, y + h), 0, "v")
            left_border.divider_line = True

            right_border = Line((x + w, y), (x + w, y + h), 0, "v")
            right_border.divider_line = True

            border_lines.extend([left_border, right_border])

        return table_boxes, border_lines

    def equal_distance_blocks(self, row_content_blocks, row_multiple_word_rects, thresh=10): #13625
        """
        Extract equal distance content blocks

        :param row_content_blocks:
        :param multiple_word_blocks:
        :param thresh: allow excess distance
        :return equal_distance_blocks_list:
        """
        def is_too_high(a_rect, b_rect):
            top_min    = min(a_rect[1], b_rect[1])
            bottom_max = max(a_rect[1]+a_rect[3], b_rect[1]+b_rect[3])
            max_height = bottom_max-top_min
            min_height = min(a_rect[3], b_rect[3])
            if max_height>min_height*2:
                return True
            else:
                return False

        equal_distance_blocks_list = []
        searched_blocks = []
        get_distance_f    = lambda from_rect, to_rect: to_rect[0]-(from_rect[0]+from_rect[2]) # calculate disntace function
        for i, head_block in enumerate(row_content_blocks):
            if head_block in searched_blocks:
                continue
            equal_distance_blocks = [head_block]
            head_rect = head_block.bounding_rect
            if len(row_content_blocks[i+1:])>1:
                current_block = row_content_blocks[i+1]
                if (Utils.rect_between_two_rects(head_rect, current_block.bounding_rect, row_multiple_word_rects, orientation="h") or # TODO:Optimize
                    is_too_high(head_rect, current_block.bounding_rect)):
                    continue
                equal_distance_blocks.append(current_block)
                interval_head2next = get_distance_f(head_rect, current_block.bounding_rect) # distance head block to next block
                for next_block in row_content_blocks[i+2:]:
                    distance = get_distance_f(current_block.bounding_rect, next_block.bounding_rect) # distance current block to next block
                    if (abs(distance-interval_head2next)<=thresh and # distance is similar interval
                        not Utils.rect_between_two_rects(current_block.bounding_rect, next_block.bounding_rect, row_multiple_word_rects, orientation="h") and # TODO:Optimize
                        not is_too_high(current_block.bounding_rect, next_block.bounding_rect)):
                        equal_distance_blocks.append(next_block)
                        current_block = next_block # update current block
                    else:
                        break
                if len(equal_distance_blocks)>2:
                    equal_distance_blocks_list.append(equal_distance_blocks)
                    searched_blocks.extend(equal_distance_blocks)
        return equal_distance_blocks_list

    def merge_content_blocks(self, content_blocks):
        """
        Merge content blocks

        :param content_blocks:
        :return merged_content_block:
        """
        merged_rect          = Utils.bounding_rect([block.bounding_rect for block in content_blocks])
        merged_content_block = ContentBlock(merged_rect, -1)
        return merged_content_block

    def merge_equal_distance_blocks(self, table_boxes, content_blocks): #13625
        """
        Merge content blocks if equal distance

        :param table_boxes:
        :param content_blocks:
        :return merged_content_blocks:
        """
        merged_content_blocks = content_blocks

        boxes               = [table_box.bounding_rect for table_box in table_boxes]
        single_word_blocks  = [block for block in content_blocks if block.single_word()]
        multiple_word_rects = [block.bounding_rect for block in list(set(content_blocks)-set(single_word_blocks))]
        row_groups          = self.group_content_blocks_by_row(boxes, single_word_blocks) # row group by single word blocks
        row_groups          = self.merge_content_groups(row_groups, single_word_blocks, "row")

        invalid_blocks = []
        for row_group in row_groups:
            row_content_blocks = row_group.content_blocks
            row_multiple_word_rects = [rect for rect in multiple_word_rects if Utils.rect_inside_rect(row_group.bounding_rect(), rect)] # extract multiple words in row
            if len(row_content_blocks)>2:
                row_content_blocks.sort(key=lambda block:block.bounding_rect[0]) # sort left x
                equal_distance_blocks_list = self.equal_distance_blocks(row_content_blocks, row_multiple_word_rects)
                for blocks in equal_distance_blocks_list:
                    merged_content_blocks.append(self.merge_content_blocks(blocks))
                    invalid_blocks.extend(blocks)
        # remove blocks
        for block in invalid_blocks:
            if block in content_blocks:
                merged_content_blocks.remove(block)
        # reset idx
        for i, block in enumerate(merged_content_blocks):
            block.idx = i
        return merged_content_blocks

    def process(self, table_boxes, lines, content_blocks, use_virtual_lines_for_blocks):
        """The main method to process all table functions
        """
        content_blocks_in_box = []
        for table_box in table_boxes:
            box = table_box.bounding_rect
            box = Utils.expand_rect(box, 10)
            # assign which text block inside which table
            tmp_inside_blocks = []
            for content_block in content_blocks:
                if Utils.rect_inside_rect(box, content_block.bounding_rect, 5):
                    content_blocks_in_box.append(content_block)
                    table_box.append_content_block(content_block)

        # Get all content blocks not in any founded boxes
        single_content_blocks = list(set(content_blocks) - set(content_blocks_in_box))

        # content_blocks calculate average
        single_word_blocks = [block for block in single_content_blocks if block.single_word()]
        if single_content_blocks:
            ave_h = sum([block.bounding_rect[3] for block in single_content_blocks])//len(single_content_blocks)
        else:
            ave_h = 30
        if len(single_word_blocks)>=5:
            ave_w    = sum([block.bounding_rect[2] for block in single_word_blocks])//len(single_word_blocks)
            ave_area = sum([block.bounding_rect[2]*block.bounding_rect[3] for block in single_word_blocks])//len(single_word_blocks)
        else:
            ave_w    = ave_h
            ave_area = 500
        text_stats_dict = {"ave_area":ave_area, "ave_w":ave_w, "ave_h":ave_h}

        header_virtual_boxes = []
        if single_content_blocks:
            # Remove noise content blocks(#13625)
            single_content_blocks = Utils.remove_noise_content_blocks(single_content_blocks, text_stats_dict)
            # Merge blocks if equal distance(#13625)
            single_content_blocks = self.merge_equal_distance_blocks(table_boxes, single_content_blocks)
            # Try to find all available tables from single content blocks, extend to the current boxes
            if use_virtual_lines_for_blocks:
                header_virtual_boxes = self.find_posible_table_box_by_header_dict(table_boxes, single_content_blocks, text_stats_dict) #13968
                # DEBUG
                if Debug.debug_flag==1:
                    header_boxes_image = self.input_image.copy()
                    Utils.draw_boxes(header_boxes_image, [table_box.bounding_rect for table_box in header_virtual_boxes], color=(0, 0, 255), thickness=1)
                    Debug.write_image(header_boxes_image, self.debug_save_path + "3.1.9 header_boxes_image.jpg")
                tmp_blocks = []
                for table_box in header_virtual_boxes:
                    tmp_blocks.extend(table_box.content_blocks)
                single_content_blocks = list(set(single_content_blocks)-set(tmp_blocks))
                virtual_boxes = self.find_posible_table_box_from_content_blocks(table_boxes, single_content_blocks, text_stats_dict, header_virtual_boxes)
                table_boxes.extend(virtual_boxes)

        table_boxes, border_lines = self.merge_real_and_virtual_table_boxes(table_boxes, header_virtual_boxes)

        lines.extend(border_lines)

        tables = self.process_table(table_boxes, lines, content_blocks, text_stats_dict)

        # split boxes if really different boxes (#12592)
        if not use_virtual_lines_for_blocks and not self.flag_semi_virtual: #13409->#14814
            self.split_tables(tables)
        return tables

    def split_tables(self, tables): #12592
        """
        Split boxes if really different boxes

        :param tables:
        """
        invalid_tables  = []
        splitted_tables = []
        for i, table in enumerate(tables):
            # find share lines
            share_lines, connect_border_lines = self.find_share_lines(table)

            # find split lines
            split_lines = []
            if share_lines:
                split_lines = self.find_split_lines(share_lines, connect_border_lines)
            else:
                continue

            # split table
            if split_lines:
                tmp_splitted_tables = []
                for split_line in split_lines:
                    front_table, back_table = (None, None)
                    if tmp_splitted_tables: # resplit if aleady splitted table
                        for splitted_table in tmp_splitted_tables:
                            if Utils.line_inside_table_box(splitted_table.bounding_rect(), split_line, 3):
                                front_table, back_table = self.split_table(split_line, splitted_table)
                                if front_table and back_table:
                                    tmp_splitted_tables.remove(splitted_table)
                                break
                    else: # first split
                        front_table, back_table = self.split_table(split_line, table)
                    if front_table and back_table:
                        invalid_tables.append(table)
                        tmp_splitted_tables.extend([front_table, back_table])

                splitted_tables.extend(tmp_splitted_tables)

        # remove invalid tables
        for invalid_table in invalid_tables:
            if invalid_table in tables:
                tables.remove(invalid_table)
        # set new tables
        tables.extend(splitted_tables)
        return tables

    def find_share_lines(self, table): #12592
        """
        Find share lines in table

        :param table:
        :return share_lines, connect_border_lines:
        
        image:
        
        ------------------------- <= border line
        |       |               |
        |       | <= share line |
        ------------------------- <= border line
        """
        share_lines          = []
        connect_border_lines = []

        h_lines = table.all_horizontal_lines()
        v_lines = table.all_vertical_lines()
        border_lines = table.all_border_lines() # => (top, bottom, left, right)

        # search horizontal lines
        for line in h_lines:
            if line in border_lines:
                continue
            if Utils.is_point_in_line(line.start_point, border_lines[2]) and Utils.is_point_in_line(line.end_point, border_lines[3]):
                    share_lines.append(line)
                    connect_border_lines.append((border_lines[2], border_lines[3]))
        # search vertical lines
        for line in v_lines:
            if line in border_lines:
                continue
            if Utils.is_point_in_line(line.start_point, border_lines[0]) and Utils.is_point_in_line(line.end_point, border_lines[1]):
                    share_lines.append(line)
                    connect_border_lines.append((border_lines[0], border_lines[1]))
        return share_lines, connect_border_lines

    def find_split_lines(self, share_lines, connect_border_lines): #12592
        def expand_rect(rect, line, excess):
            if line.orientation=="h":
                return Utils.expand_width_rect(rect, excess)
            elif line.orientation=="v":
                return Utils.expand_height_rect(rect, excess)
                
        LINE_RECT              = 20
        NO_BORDER_LINE_PERCENT = 80

        split_lines = []
        for share_line, connect_border_line in zip(share_lines, connect_border_lines):
            # get line rects
            share_rect = Utils.convert_line_to_box(share_line, threshold=LINE_RECT, orientation=share_line.orientation)
            share_rect = expand_rect(share_rect, share_line, LINE_RECT)
            front_border_rect = Utils.convert_line_to_box(connect_border_line[0], threshold=LINE_RECT, orientation=connect_border_line[0].orientation)
            front_border_rect = expand_rect(front_border_rect, connect_border_line[0], LINE_RECT)
            back_border_rect = Utils.convert_line_to_box(connect_border_line[1], threshold=LINE_RECT, orientation=connect_border_line[1].orientation)
            back_border_rect = expand_rect(back_border_rect, connect_border_line[1], LINE_RECT)
            # get rect overlap share rect and border rect
            front_overlap_rect = Utils.rect_overlap_two_rects(share_rect, front_border_rect)
            back_overlap_rect  = Utils.rect_overlap_two_rects(share_rect, back_border_rect)

            if not (front_overlap_rect or back_overlap_rect):
                continue
            # calc histogram
            if share_line.orientation=="h":
                front_border_hist   = ImageProcessing.horizontal_histogram(self.binary_image, front_border_rect)
                back_border_hist    = ImageProcessing.horizontal_histogram(self.binary_image, back_border_rect)
                front_overlap_hist  = ImageProcessing.horizontal_histogram(self.binary_image, front_overlap_rect)
                back_overlap_hist   = ImageProcessing.horizontal_histogram(self.binary_image, back_overlap_rect)
            elif share_line.orientation=="v":
                front_border_hist  = ImageProcessing.vertical_histogram(self.binary_image, front_border_rect)
                back_border_hist   = ImageProcessing.vertical_histogram(self.binary_image, back_border_rect)
                front_overlap_hist = ImageProcessing.vertical_histogram(self.binary_image, front_overlap_rect)
                back_overlap_hist  = ImageProcessing.vertical_histogram(self.binary_image, back_overlap_rect)
            else:
                continue

            # split share line if lack in line
            if ((np.sum(front_border_hist==0)/len(front_border_hist))*100<=NO_BORDER_LINE_PERCENT and
                (np.sum(back_border_hist==0)/len(back_border_hist))*100<=NO_BORDER_LINE_PERCENT): # Table has not real border line if hist has many 0
                if np.any(front_overlap_hist==0) and np.any(back_overlap_hist==0):
                    split_lines.append(share_line)
        return split_lines

    def split_table(self, split_line, table): #12592
        """
        Split table by split line

        :param split_line:
        :param table:

        image:
        [table]
        -------------------------------             --------------- ----------------
        |             | <= split_line |             |             | |              |
        |             |               |      =>     |             | |              |
        |   (front)   |    (back)     |             |             | |              |
        |             |               |             |             | |              |
        -------------------------------             --------------- ----------------
        """
        front_table = table
        back_table  = table.copy()
        invalid_lines = [split_line]
        v_lines = table.all_vertical_lines()
        h_lines = table.all_horizontal_lines()

        # get intersect lines
        intersect_lines = []
        if split_line.orientation=="h":
            intersect_lines = Utils.lines_intersect_line(v_lines, split_line)
        elif split_line.orientation=="v":
            intersect_lines = Utils.lines_intersect_line(h_lines, split_line)
        else:
            return (None, None)

        # separate front or back lines
        front_lines = []
        back_lines  = []
        if intersect_lines:
            for intersect_line in intersect_lines:
                invalid_lines.append(intersect_line)
                lines = Utils.line_split_line(intersect_line, split_line) # split intersect line
                if lines:
                    front_lines.append(lines[0])
                    back_lines.append(lines[1])
                elif Utils.is_point_in_line(intersect_line.end_point, split_line):
                    front_lines.append(intersect_line)
                else:
                    back_lines.append(intersect_line)

        if not front_lines or not back_lines:
            return (None, None)

        # readjust lines
        front_split_line = split_line.copy()
        back_split_line  = split_line.copy()
        self.readjust_lines(split_line, front_split_line, back_split_line, front_lines, back_lines)

        # remove invalid lines
        for line in invalid_lines:
            if line in h_lines:
                h_lines.remove(line)
            if line in v_lines:
                v_lines.remove(line)
        
        # set table adjusted lines
        if split_line.orientation=="h":
            front_h_lines = Utils.lines_over_line(split_line, h_lines+[front_split_line], direction="top")  # front table h_lines
            front_v_lines = Utils.lines_over_line(split_line, v_lines+front_lines, direction="top")         # front table v_lines
            back_h_lines  = list(set(h_lines)-set(front_h_lines))+[back_split_line]                         # back  table h_lines
            back_v_lines  = list(set(v_lines+back_lines)-set(front_v_lines))                                # back  table v_lines
        else:
            front_h_lines = Utils.lines_over_line(split_line, h_lines+front_lines, direction="left")        # front table h_lines
            front_v_lines = Utils.lines_over_line(split_line, v_lines+[front_split_line], direction="left") # front table v_lines
            back_h_lines  = list(set(h_lines+back_lines)-set(front_h_lines))                                # back  table h_lines
            back_v_lines  = list(set(v_lines)-set(front_v_lines))+[back_split_line]                         # back  table v_lines

        self.set_table_horizontal_lines(front_table, front_h_lines)
        self.set_table_horizontal_lines(back_table,  back_h_lines)
        self.set_table_vertical_lines(front_table, front_v_lines)
        self.set_table_vertical_lines(back_table,  back_v_lines)

        return front_table, back_table

    def readjust_lines(self, split_line, front_split_line, back_split_line, front_lines, back_lines): #12592
        def ret_x(line):
            return line.start_point[0]

        def ret_y(line):
            return line.start_point[1]

        SPACING = 2
        if split_line.orientation=="h":
            front_left_x  = min(front_lines, key=ret_x)
            front_right_x = max(front_lines, key=ret_x)
            x, y = split_line.start_point
            front_split_line.start_point = (x, y-SPACING)
            back_split_line.start_point  = (x, y+SPACING)
            x, y = split_line.end_point
            front_split_line.end_point   = (x, y-SPACING)
            back_split_line.end_point    = (x, y+SPACING)
            self.readjust_vertical_lines(front_split_line, front_lines, place="front")
            self.readjust_vertical_lines(back_split_line, back_lines, place="back")
        else:
            front_top_y    = min(front_lines, key=ret_y).end_point[1]
            front_bottom_y = max(front_lines, key=ret_y).end_point[1]
            back_top_y     = min(back_lines,  key=ret_y).end_point[1]
            back_bottom_y  = max(back_lines,  key=ret_y).end_point[1]
            x, y = split_line.start_point
            front_split_line.start_point = (x-SPACING, front_top_y)
            back_split_line.start_point  = (x+SPACING, back_top_y)
            x, y = split_line.end_point
            front_split_line.end_point   = (x-SPACING, front_bottom_y)
            back_split_line.end_point    = (x+SPACING, back_bottom_y)
            self.readjust_horizontal_lines(front_split_line, front_lines, place="front")
            self.readjust_horizontal_lines(back_split_line, back_lines, place="back")

    def readjust_horizontal_lines(self, v_line, lines, place="front"): #12592
        if place=="front":
            for line in lines:
                x, y = line.end_point
                line.end_point = (v_line.end_point[0], y)
        else:
            for line in lines:
                x, y = line.start_point
                line.start_point = (v_line.start_point[0], y)

    def readjust_vertical_lines(self, h_line, lines, place="front"): #12592
        if place=="front":
            for line in lines:
                x, y = line.end_point
                line.end_point = (x, h_line.end_point[1])
        else:
            for line in lines:
                x, y = line.start_point
                line.start_point = (x, h_line.start_point[1])

    def group_content_blocks_by_column(self, boxes, content_blocks, flag=True):
        """Group all the content blocks to seperate columns

        Parameters
        ----------
        boxes : list
            The list of existing table bounding box
        content_blocks : list
            The list of content blocks
        flag : bool, optional
            A flag used to detect if one content block count as one group

        Returns
        -------
        list
            a list of grouped columns 

        """
        THRESHOLD = 10
        column_groups = []
        ungroup_content_blocks = copy.deepcopy(content_blocks)

        # Sort all content blocks by Y, X position #13652 Y=>Y, X
        content_blocks = sorted(content_blocks, key=lambda content_block: (content_block.bounding_rect[1], content_block.bounding_rect[0]))

        for i, head_block in enumerate(content_blocks):
            if Utils.content_block_in_groups(column_groups, head_block):
                continue

            col_alignments = []
            group_content_block = ContentGroupBlock("column")
            group_content_block.append_content_block(head_block)

            for next_block in content_blocks[i+1:]:
                group_content_block.content_blocks = sorted(group_content_block.content_blocks, key=lambda content_block: (content_block.bounding_rect[1], content_block.bounding_rect[0])) #13652 Y=>Y, X

                if next_block.is_below(group_content_block.content_blocks[-1]): #13652
                    alignments = group_content_block.content_blocks[-1].align_vertical_with(next_block, threshold=THRESHOLD) #13409
                else:
                    alignments = head_block.align_vertical_with(next_block, threshold=THRESHOLD)

                if len(alignments) > 0 and len(col_alignments) == 0:
                    col_alignments.extend(alignments)

                if Utils.alignments_contain(col_alignments, alignments):
                    ungroup_content_blocks = list(set(content_blocks)-set(group_content_block.content_blocks)) #13652
                    if not Utils.has_box_between_content_blocks(group_content_block.content_blocks[-1], next_block, ungroup_content_blocks, boxes, "vertical"):
                        group_content_block.append_content_block(next_block)

            if flag:
                # Only keep the column which has at least 2 content blocks
                if len(group_content_block.content_blocks) > 1:
                    column_groups.append(group_content_block)
            else:
                column_groups.append(group_content_block)

        return column_groups

    def group_content_blocks_by_row(self, boxes, content_blocks, flag=True):
        """Group all the content blocks to seperate columns

        Parameters
        ----------
        boxes : list
            The list of existing table bounding box
        content_blocks : list
            The list of content blocks
        flag : bool, optional
            A flag used to detect if one content block count as one group
            
        Returns
        -------
        list
            a list of grouped rows 

        """
        THRESHOLD  = 10
        MULTI_ROWS = 2 # number of multiple rows
        row_groups = []

        # Sort all content blocks by X, Y position #13652 X=>X, Y
        content_blocks = sorted(content_blocks, key=lambda content_block: (content_block.bounding_rect[0], content_block.bounding_rect[1]))

        for i, head_block in enumerate(content_blocks):
            # If this content_block has already checked, continue
            if Utils.content_block_in_groups(row_groups, head_block):
                continue

            row_alignments   = []
            collision_blocks = [] #13968
            group_content_block = ContentGroupBlock("row")
            group_content_block.append_content_block(head_block)

            for next_block in content_blocks[i+1:]:
                group_content_block.content_blocks = sorted(group_content_block.content_blocks, key=lambda content_block: (content_block.bounding_rect[0], content_block.bounding_rect[1]))
                if next_block.is_right(group_content_block.content_blocks[-1]) and not collision_blocks: #13652->#14369
                    alignments = group_content_block.content_blocks[-1].align_horizontal_with(next_block, threshold=THRESHOLD) #13409
                else:
                    alignments = head_block.align_horizontal_with(next_block, threshold=THRESHOLD)

                if len(alignments) > 0 and len(row_alignments) == 0:
                    row_alignments.extend(alignments)

                if Utils.alignments_contain(row_alignments, alignments):
                    ungroup_content_blocks = list(set(content_blocks)-set(group_content_block.content_blocks+collision_blocks)) #13652->#13968
                    if not Utils.has_box_between_content_blocks(group_content_block.content_blocks[-1], next_block, ungroup_content_blocks, boxes, "horizontal"):
                        group_content_block.append_content_block(next_block)
                    if collision_blocks and len(collision_blocks)==MULTI_ROWS: #13968->#14369
                        group_content_block.extend_content_blocks(collision_blocks)
                    collision_blocks = []
                elif Utils.rect_vertical_overlap_rect(head_block.bounding_rect, next_block.bounding_rect, thresh=0): # allow multiple rows #13968
                    if len(collision_blocks)<MULTI_ROWS:
                        collision_blocks.append(next_block)
                    else:
                        if not any([Utils.rect_horizontal_overlap_rect(block.bounding_rect, next_block.bounding_rect) for block in collision_blocks]): #14369
                            if len(collision_blocks)==MULTI_ROWS:
                                group_content_block.extend_content_blocks(collision_blocks)
                            collision_blocks = [next_block]
            if flag:
                # Only keep the row which has at least 2 content blocks
                if len(group_content_block.content_blocks) > 1:
                    row_groups.append(group_content_block)
            else:
                row_groups.append(group_content_block)

        return row_groups

    def refine_row_groups(self, table):
        """Connect all seperate rows with same Y possition and same height
        
        -----------------   -----------------
        |     a_row     |   |      b_row    | -> one new row
        -----------------   -----------------

        """
        merged_row_groups = []

        row_groups = table.row_groups
        content_blocks = table.content_blocks

        threshold = 10

        rects = [row_group.bounding_rect() for row_group in row_groups]

        rects = sorted(rects, key=lambda rect: rect[1])

        invalid_rects = []

        for i in range(len(rects) - 1):
            a_rect = rects[i]
            b_rect = rects[i+1]

            if abs(a_rect[1] - b_rect[1]) <= threshold and abs(a_rect[3] - b_rect[3]) <= 2 * threshold:
                rects.append(Utils.bounding_rect([a_rect, b_rect]))
                invalid_rects.append(a_rect)
                invalid_rects.append(b_rect)

        for rect in invalid_rects:
            if rect in rects:
                rects.remove(rect)

        # Try to remove the sub row of the bigger row.
        rects = sorted(rects, key=lambda rect: rect[1])

        invalid_rects = []
        for i in range(len(rects) - 1):
            a_rect = rects[i]
            b_rect = rects[i+1]

            if a_rect[1] + a_rect[3] > b_rect[1] and b_rect[2] / a_rect[2] < 0.4:
                invalid_rects.append(b_rect)

        for rect in invalid_rects:
            if rect in rects:
                rects.remove(rect)

        # Re-group the ContentBlocks to the new ContentGroup
        for group_rect in rects:
            group_content_block = ContentGroupBlock("row")

            for content_block in content_blocks:
                if Utils.rect_inside_rect(group_rect, content_block.bounding_rect):
                    group_content_block.append_content_block(content_block)

            merged_row_groups.append(group_content_block)

        table.row_groups = merged_row_groups
