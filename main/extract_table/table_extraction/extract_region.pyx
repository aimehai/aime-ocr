import cv2
import time
import argparse
import os
import glob
import ntpath
import numpy as np
import datetime
import re

#import matplotlib
#matplotlib.use('TkAgg')
#from matplotlib import pyplot as plt

from resource.config import CommonData
from table_extraction.image_processing import ImageProcessing
from table_extraction.table_processing import TableProcessing
from table_extraction.table_box import TableBox
from table_extraction.table import Table
from table_extraction.line import Line
from table_extraction.content_block import ContentBlock
from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug
import json

class ExtractRegion(object):
    input_image = None
    debug_save_path = None
    binary_image = None

    def __init__(self, image, crnn_chars, debug_save_path, file_name, debug_flag):
                  
        # convert
        text_blocks = [(crnn_char['x'], crnn_char['y'], crnn_char['w'], crnn_char['h']) for crnn_char in crnn_chars]

        self.input_image = image

        self.text_blocks    = text_blocks
        self.crnn_chars     = crnn_chars #13968
        # self.header_regex   = CommonData.read_table_header_dict(path="./resource/table_header.dict") #13968
        self.header_regex   = CommonData.read_table_header_dict(path="./resource/header.dict") #13968

        self.flag_semi_virtual = False #14814
                                      
        if debug_save_path:
            Debug.debug_flag = debug_flag
        else:
            if debug_flag:
                print("[!] Debug directory path is empty")
            Debug.debug_flag = 0

        self.debug_save_path = debug_save_path
        Debug.debug_save_path = debug_save_path

        # In debug mode, create debug folder
        if Debug.debug_flag == 1:
            if not os.path.exists(debug_save_path):
                os.makedirs(debug_save_path)

            print(self.debug_save_path)

            files = glob.glob(debug_save_path + "/*")
            for file in files:
                os.remove(file)

            import json
            with open(self.debug_save_path + "{}_text_blocks.json".format(file_name), "w") as output_file:
                json.dump(self.text_blocks, output_file)

            original_text_block_image = self.input_image.copy()
            original_text_block_image = Utils.draw_boxes(original_text_block_image, self.text_blocks, (0, 0, 255))
            Debug.write_image(original_text_block_image, self.debug_save_path + "3.0 original_text_block_image.jpg")


    def complement_boxes_by_alignment(self, boxes, lines): #13664
        """
        Complement boxes by similar alignment lines(only enambled VIRTUAL and horizontal lines)

        :param boxes:
        :param lines:
        :return complemented_boxes

        ------------------------                ------------------------
                                                |                      | 
        ------------------------       =>       ------------------------
                                                |                      | 
        ------------------------                ------------------------
        """
        complemented_boxes = []
        DISTANCE_THRESH    = 10
        RATIO_THRESH       = 0.1

        h_lines = [line for line in lines if line.orientation=="h"]
        h_line_pairs = Utils.line_pairs(h_lines, [], distance_threshold=DISTANCE_THRESH, ratio_threshold=RATIO_THRESH)[0]
        if not h_line_pairs or not h_line_pairs[0]:
            return boxes
        h_line_groups = [[h_line_pairs[0][0]]]
        for src_line, dst_line in h_line_pairs:
            if src_line not in h_line_groups[-1] and dst_line not in h_line_groups[-1]:
                h_line_groups.append([src_line]) # append new group
            if src_line not in h_line_groups[-1]:
                h_line_groups[-1].append(src_line) # append src_line into current group
            if dst_line not in h_line_groups[-1]:
                h_line_groups[-1].append(dst_line) # append dst_line into current group

        complemented_boxes = []
        h_line_groups = [sorted(h_line_group, key=lambda h_line:h_line.start_point[1]) for h_line_group in h_line_groups if len(h_line_group)>=2] # number of lines in group>=2 and sort group by y
        for h_line_group in h_line_groups:
            bounding_rect    = Utils.bounding_rect_lines(rect=None, lines=h_line_group)
            top_line_rect    = h_line_group[0].bounding_rect()
            bottom_line_rect = h_line_group[-1].bounding_rect()
            if (not Utils.is_rect_contains_rects(bounding_rect, boxes) and
                not Utils.rect_between_two_rects(top_line_rect, bottom_line_rect, boxes)):
                contain_rects = Utils.get_rect_contains_rects(bounding_rect, self.text_blocks)
                if len(contain_rects)>=len(h_line_group)-1:
                    complemented_boxes.append(bounding_rect)
        return complemented_boxes

    def remove_header_boxes_lines(self, boxes, lines):
        """
        Remove header boxes

        :param boxes:
        :param lines:
        :return removed_boxes:

                     -----------------------    
        header box-> |   aaa    |    bbb   | =>     aaa         bbb   
                     -----------------------    
        """
        # extract invalid header boxes
        invalid_boxes = []
        for box in boxes:
            tmp_inside_blocks = []
            for block in self.text_blocks:
                if Utils.rect_inside_rect(box, block, 5):
                    tmp_inside_blocks.append(block)
            if tmp_inside_blocks:
                if Utils.is_text_blocks_header_by_header_dict(tmp_inside_blocks, self.crnn_chars, self.header_regex): # is header box?
                    invalid_boxes.append(box)
        # extract invalid lines in header box
        invalid_lines = []
        for invalid_box in invalid_boxes:
            for line in lines:
                if Utils.line_inside_box(invalid_box, line, 5):
                    invalid_lines.append(line)
        # remove invalid lines
        for invalid_line in invalid_lines:
            if invalid_line in lines:
                lines.remove(invalid_line)
        # remove invalid boxes
        for invalid_box in invalid_boxes:
            if invalid_box in boxes:
                boxes.remove(invalid_box)
        return boxes, lines

    def create_verticaly_same_boxes_group(self, boxes): #14802
        """Create verticaly same area boxes group
        """
        W_THRESH = 10 # thresh of width
        H_THRESH = 10 # thresh of height
        # create group which has same area boxes
        same_area_group  = []
        added_boxes      = []
        boxes            = sorted(boxes, key=lambda box:(box[1], box[0])) # sort by y, x
        for i, src_box in enumerate(boxes):
            if src_box in added_boxes:
                continue
            tmp_group = [src_box]
            added_boxes.append(src_box)
            for dst_box in boxes[i+1:]:
                if (src_box[2]-W_THRESH<=dst_box[2]<=src_box[2]+W_THRESH and # width  check
                    src_box[3]-H_THRESH<=dst_box[3]<=src_box[3]+H_THRESH and # height check
                    src_box[1]+src_box[3]<=dst_box[1]):                      # dst_box lower than src_box
                    tmp_group.append(dst_box)
                    added_boxes.append(dst_box)
            same_area_group.append(tmp_group)
        return same_area_group

    def remove_fill_boxes(self, boxes): #14802
        """Remove fill area boxes
        """
        G_THRESH = 3  # thresh of number of group
        # extract fill box
        gray_image   = cv2.cvtColor(self.input_image, cv2.COLOR_BGR2GRAY)
        binary_image = ImageProcessing.binalize(gray_image, adaptive=False)
        fill_boxes   = [box for box in boxes if Utils.is_fill_area(box, binary_image)]
        # create group which has same area boxes
        same_area_group = self.create_verticaly_same_boxes_group(fill_boxes)
        # ignore group less than GROUP_THRESH
        same_area_group = [g for g in same_area_group if len(g)>=G_THRESH]
        # remove boxes
        for group_boxes in same_area_group:
            boxes = list(set(boxes)-set(group_boxes))
        return boxes

    def create_column_from_title_box(self, title_box, contents, alignment="left", alignment_thresh=10): #14814
        col = []
        title_content = Utils.get_rect_contains_rects(title_box, self.text_blocks)
        if len(title_content)!=1:
            return col
        title_content = title_content[0]
        col.append(title_content)
        invalid_y = -1
        for content in sorted(contents, key=lambda c:(c[0], c[1])):
            content_alignment = Utils.align_vertical(title_content, content, threshold=alignment_thresh) # get alignment
            if content_alignment==alignment:
                if invalid_y==-1 or invalid_y>content[1]: # not append if content below invalid content
                    col.append(content)
            else:
                # set invalid content y
                if title_content[0]>content[0]:
                    if invalid_y==-1:
                        invalid_y = content[1]
                    elif invalid_y>content[1]:
                        invalid_y = content[1] # update
        return col

    def enclose_title_and_content(self, boxes): #14814
        """
        Enclose title box and content area

        :param boxes:
        :retrun boxes:

        Enclose conditions:
        1. There is only one line within the title box.
        2. Title and contents are left alignment.
        3. Contents within title box's width.
        """
        # extract box which have one row
        title_boxes = [box for box in boxes if len(Utils.get_rows_from_content_boxes(Utils.get_rect_contains_rects(box, self.text_blocks)))==1]
        title_boxes = sorted(title_boxes, key=lambda box:(box[1], box[0])) # sort by y,x
        # extract contents belong box
        belong_contents_list = [] # [[title_box, belong_contents], ...]
        if len(title_boxes)>=1:
            for src_box, dst_box in zip(title_boxes, title_boxes[1:]):
                belong_contents_list.append(
                    [src_box, Utils.rect_between_two_rects(src_box, dst_box, self.text_blocks, orientation="v", return_rects=True)]
                )
        elif len(title_boxes)==1:
            belong_contents_list.append(
                [title_boxes[0], Utils.rects_under_rect(title_boxes[0], self.text_blocks, orientation="v", return_rects=True)]
            )
        for title_box, belong_contents in belong_contents_list:
            if not belong_contents:
                continue
            # check aliment that title_content and belong_contents
            col = self.create_column_from_title_box(title_box, belong_contents, alignment="left", alignment_thresh=10)
            if len(col)<=1:
                continue
            # check contents within title box's width.
            new_box = Utils.bounding_rect(col+[title_box])
            flag_divide_content = False # divide a content or not
            for belong_content in belong_contents:
                if not Utils.rect_inside_rect(new_box, belong_content) and Utils.rect_horizontal_overlap_rect(new_box, belong_content, inside_box=True): # does new_box divide content
                    flag_divide_content = True
            if flag_divide_content:
                continue
            # check new_box collision other box
            flag_collision = False
            for box in boxes:
                if title_box!=box and Utils.rect_overlap_rect(new_box, box):
                    flag_collision = True
            if flag_collision:
                continue
            # append new_box and remove title_box
            boxes = list(set(boxes)-{title_box}|{new_box})
            self.flag_semi_virtual = True
        return boxes

    def extract_table_boxes(self, lines):
        """Find all posible table bounding boxes
        """

        # Redraw the input image base on the lines
        lines_image = np.ones((self.input_image.shape[0], self.input_image.shape[1]), dtype=np.uint8) * 255
        lines_image = Utils.draw_lines(lines_image, lines, (0, 0, 0), 2)

        # DEBUG
        if Debug.debug_flag == 1:
            Debug.write_image(lines_image, self.debug_save_path + "2.0 lines_image.jpg")
        # END

        # First, find all posible bounding boxes in the input image
        boxes = self.extract_contours_rects(lines_image)

        # Second, Remove boxes inside boxes
        boxes = self.remove_box_inside_box(boxes)

        # Third, extend boxes to singles lines
        single_lines = Utils.single_lines(boxes, lines)
        boxes = self.extend_boxes_by_lines(boxes, single_lines)

        # # (VIRTUAL) complement boxes by similar alignment lines (#13664)
        # if self.use_virtual_lines_for_blocks:
        #     single_lines = Utils.single_lines(boxes, lines)
        #     boxes.extend(self.complement_boxes_by_alignment(boxes, single_lines))

        # Fourth, merge all overlap boxes
        boxes = self.merge_overlap_boxes(boxes, orientation='h')
        boxes = self.merge_overlap_boxes(boxes, orientation='v')
        boxes = self.remove_box_inside_box(boxes)

        # Final, find missing boxes (normal rounded table)
        single_lines = Utils.single_lines(boxes, lines)

        # find possible box of a table, which made by broken lines
        boxes = self.extend_boxes(boxes, single_lines)

        # bounding boxes if broken boxes (only external boxes) #13200
        boxes = self.bounding_or_remove_broken_boxes(boxes, single_lines, orientation="h")
        # boxes = self.bounding_or_remove_broken_boxes(boxes, single_lines, orientation="v")

        # remove fill area boxes (only virtual) #14802
        if self.use_virtual_lines_for_blocks:
            boxes = self.remove_fill_boxes(boxes)

        # enclose title box and content area #14814
        boxes = self.enclose_title_and_content(boxes)

        # make the the box do not go acroos any text block
        # boxes = self.extend_boxes_with_text_blocks(boxes, self.text_blocks.copy())

        # split table into smaller table. table must be a rectangle
        # boxes = self.split_top_table_boxes(boxes, lines) # 14611(comment)
        boxes = self.split_bottom_table_boxes(boxes, lines)

        # remove header boxes and lines #13968
        boxes, lines = self.remove_header_boxes_lines(boxes, lines)

        # remove boxes that divide a text block #14560
        content_blocks = self.content_blocks()
        boxes = [box for box in boxes  if not Utils.is_rect_divide_content(box, content_blocks, expand_size=15, overlap_percent=30, cnt=1)]

        return boxes

    def split_top_table_boxes(self, boxes, lines):
        """Split box contain two real-tables to 2 boxes
                -------------
                |           | -> a_box
        ---------------------
        |       |           |
        |       |           | -> b_box
        |       |           |
        ---------------------

        """
        boxes.sort(key=lambda rect: rect[2] * rect[3])

        invalid_boxes = []
        splitted_boxes = []
        invalid_lines = []

        threshold = 15

        for box in boxes:
            box_lines = []

            for line in lines:
                if Utils.line_inside_box(box, line, 10) and not line.table_line:
                    line.table_line = True
                    box_lines.append(line)

            h_lines, v_lines = Utils.split_lines(box_lines)

            # Sort the horizontal lines
            h_lines = sorted(h_lines, key=lambda line: line.start_point[1])

            v_lines = sorted(v_lines, key=lambda line: line.start_point[0])

            if len(h_lines) == 0 or len(v_lines) < 2:
                continue

            # Find all left and right border lines
            left_border_lines = []
            right_border_lines = []
            for line in v_lines:
                if Utils.distance_from_line_to_box(box, line, "left") < threshold:
                    left_border_lines.append(line)

                if Utils.distance_from_line_to_box(box, line, "right") < threshold:
                    right_border_lines.append(line)
																 
									 
							

            # If no border lines, just continue
            if len(left_border_lines) == 0 or len(right_border_lines) == 0:
                continue

            left_border_lines = sorted(left_border_lines, key=lambda line: line.start_point[1])
            right_border_lines = sorted(right_border_lines, key=lambda line: line.start_point[1])

            # Check if start point of left and right borders are same Y position, continue
            if abs(left_border_lines[0].start_point[1] - right_border_lines[0].start_point[1]) < threshold:
                continue

            top_line = h_lines[0]

            # If top line don't close enought with the top, or top line have the same width with box, just ignore this case
            if Utils.distance_from_line_to_box(box, top_line, "top") > threshold or top_line.length() / box[2] > 0.9:
                continue

            idx = 0
            # Find the top border of table 2
            for i, line in enumerate(h_lines):
                if line.length() / box[2] > 0.9:
                    idx = i
                    break

            if idx == 0:
                continue

            a_box = Utils.bounding_rect_lines(None, h_lines[0:idx])
            b_box = Utils.bounding_rect_lines(None, h_lines[idx:])

            # Extend the a_box height
            a_box = (a_box[0], a_box[1], a_box[2], h_lines[idx].start_point[1] - top_line.start_point[1])

            # Split the real vertical lines too
            for line in v_lines:
                if not Utils.line_inside_box(a_box, line, 0) and not Utils.line_inside_box(b_box, line, 0):
                    invalid_lines.append(line)
                    a_line = Line(line.start_point, (line.end_point[0], a_box[1] + a_box[3]), line.width, "v")
                    b_line = Line((line.start_point[0], b_box[1]), line.end_point, line.width, "v")
                    lines.append(a_line)
                    lines.append(b_line)

            splitted_boxes.append(a_box)
            splitted_boxes.append(b_box)
            invalid_boxes.append(box)

        for box in invalid_boxes:
            if box in boxes:
                boxes.remove(box)

        boxes.extend(splitted_boxes)

        for line in invalid_lines:
            if line in lines:
                lines.remove(line)

        # Reset table line
        for line in lines:
            line.table_line = False

        single_lines = Utils.single_lines(boxes, lines)
        boxes = self.extend_boxes_by_lines(boxes, single_lines)

        return boxes

    def split_bottom_table_boxes(self, boxes, lines):
        """Split box contain two real-tables to 2 boxes
        ---------------------
        |       |           |
        |       |           | -> b_box
        |       |           |
        ---------------------
                |           | -> a_box
                -------------

        """
        boxes.sort(key=lambda rect: rect[2] * rect[3])

        invalid_boxes = []
        splitted_boxes = []
        invalid_lines = []

        threshold = 15

        for box in boxes:
            box_lines = []

            for line in lines:
                if Utils.line_inside_box(box, line, 10) and not line.table_line:
                    line.table_line = True
                    box_lines.append(line)

            h_lines, v_lines = Utils.split_lines(box_lines)

            # Sort the horizontal lines
            h_lines = sorted(h_lines, key=lambda line: line.start_point[1], reverse=True)

            v_lines = sorted(v_lines, key=lambda line: line.start_point[0])

            if len(h_lines) == 0 or len(v_lines) < 2:
                continue

            # Find all left and right border lines
            left_border_lines = []
            right_border_lines = []

            for line in v_lines:
                if Utils.distance_from_line_to_box(box, line, "left") < threshold:
                    left_border_lines.append(line)

                if Utils.distance_from_line_to_box(box, line, "right") < threshold:
                    right_border_lines.append(line)

            # If no border lines, just continue
            if len(left_border_lines) == 0 or len(right_border_lines) == 0:
                continue

            left_border_lines = sorted(left_border_lines, key=lambda line: line.end_point[1])
            right_border_lines = sorted(right_border_lines, key=lambda line: line.end_point[1])

            # Check if end point of left and right borders are same Y position, continue
            if abs(left_border_lines[-1].end_point[1] - right_border_lines[-1].end_point[1]) < threshold:
                continue

            bottom_line = h_lines[0]

            # If top line don't close enought with the top, or top line have the same width with box, just ignore this case
            if Utils.distance_from_line_to_box(box, bottom_line, "bottom") > threshold or bottom_line.length() / box[2] > 0.9:
                continue

            idx = 0
            # Find the bottom border of a_box
            for i, line in enumerate(h_lines):
                if line.length() / box[2] > 0.9:
                    idx = i
                    break

            if idx == 0:
                continue

            a_box = Utils.bounding_rect_lines(None, h_lines[0:idx])
            b_box = Utils.bounding_rect_lines(None, h_lines[idx:])

            # Extend the a_box height
            a_box = (a_box[0], h_lines[idx].start_point[1], a_box[2], bottom_line.start_point[1] - h_lines[idx].start_point[1])

            # Split the real vertical lines too
            for line in v_lines:
                if not Utils.line_inside_box(a_box, line, 0) and not Utils.line_inside_box(b_box, line, 0):
                    invalid_lines.append(line)
                    a_line = Line((line.start_point[0], a_box[1]), line.end_point, line.width, "v")
                    b_line = Line(line.start_point, (line.end_point[0], b_box[1] + b_box[3]), line.width, "v")
                    lines.append(a_line)
                    lines.append(b_line)

            splitted_boxes.append(a_box)
            splitted_boxes.append(b_box)
            invalid_boxes.append(box)

        for box in invalid_boxes:
            if box in boxes:
                boxes.remove(box)
        boxes.extend(splitted_boxes)

        for line in invalid_lines:
            if line in lines:
                lines.remove(line)

        # Reset table line
        for line in lines:
            line.table_line = False

        return boxes

    def refine_boxes_and_lines(self, boxes, lines):
        """
        :param boxes: the boxes are became to table
        :param lines: the lines are in the document
        :return: remove the small boxes and all the lines inside those boxes
        """
        valid_boxes = []
        noise_boxes = []
        for box in boxes:
            if (box[2] > 100 and box[3] > 30) or (box[2] > 30 and box[3] > 100):
                valid_boxes.append(box)
            else:
                noise_boxes.append(box)

        invalid_lines = []
        for box in noise_boxes:
            for line in lines:
                if Utils.line_inside_box(box, line):
                    invalid_lines.append(line)

        for line in invalid_lines:
            if line in lines:
                lines.remove(line)

        return valid_boxes, lines

    def extend_box_with_text_blocks(self, box, text_blocks):

        text_blocks.append(box)
        new_box = Utils.external_rects(self.input_image.shape, text_blocks)[0]
        return (box[0], new_box[1], box[2], new_box[3])

    def extend_boxes_with_text_blocks(self, boxes, text_blocks):
        """
        :param boxes: these bounding rectangle of these table in the image
        :param text_blocks: bounding rectangle of these text in the image
        :return: bounding rectangle will be extended if the rectangle reach the text block
                For example:
                                                          ------------------
                ---- text block ----                     |     text block   |
                |                   | will be extended   |                  |
                |                   | -----------------> |                  |
                |                   |                    |                  |
                --------------------                      -------------------
        """
        boxes.sort(key=lambda box: box[2] + box[3])
        temp_text_blocks = text_blocks.copy()
        threshold = -10
        for i in range(len(boxes)):
						   
            temp_box = Utils.expand_rect(boxes[i], threshold)
            text_blocks_in_box = [text_block for text_block in temp_text_blocks if Utils.rect_overlap_rect(temp_box, text_block)]
            for text_block in text_blocks_in_box:
                if text_block in temp_text_blocks:
                    temp_text_blocks.remove(text_block)

            boxes[i] = self.extend_box_with_text_blocks(boxes[i], text_blocks_in_box)
        return boxes


    def remove_box_inside_box(self, boxes):
        box_inside_boxes = []
        boxes.sort(key=lambda box: box[2]*box[3], reverse=True)

        for i in range(len(boxes) - 1):
            for j in range(i + 1, len(boxes)):
                a_rect = boxes[i]
                b_rect = boxes[j]
                if Utils.rect_inside_rect(a_rect, b_rect, 3):
                    box_inside_boxes.append(b_rect)

        for box in box_inside_boxes:
            if box in boxes:
                boxes.remove(box)
        return boxes

    def merge_overlap_boxes(self, boxes, orientation='h', threshold_expand=3, threshold_percent=0):
        """Merge all overlapping boxes
        """
        overlap_boxes = []
        extend_boxes = []

        if orientation == 'h':
            boxes.sort(key=lambda box: box[0])
        else:
            boxes.sort(key=lambda box: box[1])

        for i in range(len(boxes) - 1):
            merge_rect = boxes[i]
            for j in range(i + 1, len(boxes)):
                b_rect = boxes[j]
                if Utils.rect_overlap_rect_with_percent(Utils.expand_rect(merge_rect, threshold_expand),
                            Utils.expand_rect(b_rect, threshold_expand), threshold_percent) \
                            and Utils.rect_can_be_merged(merge_rect, b_rect):
                    overlap_boxes.append(merge_rect)
                    overlap_boxes.append(b_rect)

                    # merge 2 overlaped boxes
                    merge_rect = Utils.bounding_rect([merge_rect, b_rect])
                    merge_rect = (merge_rect[0], merge_rect[1], merge_rect[2] - 1, merge_rect[3] - 1)
                    extend_boxes.append(merge_rect)

        for overlap_box in overlap_boxes:
            if overlap_box in boxes:
                boxes.remove(overlap_box)

        extend_boxes = list(set(extend_boxes))
        boxes.extend(extend_boxes)

        return boxes

    def extend_boxes_by_lines(self, boxes, single_lines):
        """Extend boxes by single nearby line
        """
        for idx, box in enumerate(boxes):
            box_lines = []
            for line in single_lines:
                if Utils.line_inside_box(box, line, 10) and Utils.line_belong_with_box(box, line):
                    box_lines.append(line)

            if len(box_lines) == 0:
                continue

            # In case have at least one line nearby box, extend it
            boxes[idx] = Utils.bounding_rect_lines(box, box_lines)

        return boxes

    def extract_contours_rects(self, image, all_rects=False):
        """Extract the bounding boxes from the input image
        """
        # Invert the image to prevent contours find the boundary box
        invert_image = 255 - image
        contours = cv2.findContours(invert_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]

        if all_rects:
            return rects
        else:
            # Igore too small and too big rects
            return [rect for rect in rects if
                    rect[2] > 20 and rect[3] > 20 and rect[2] < image.shape[1] - 5 and rect[3] < image.shape[0] - 5 and
                    rect[2] * rect[3] > 100 * 50]

    def remove_lines_contain_all(self, line_rects, image_size, text_blocks, orientation="v"): #13670
        """
        Remove lines if contain all elements(= not contain elements between outside line of image and min(or max) line)

        :param line_rects:
        :param image_size: (y, x) not (x, y)
        :param orientation: "v" or "h"
        :return removed_rects:
        """
        DISTANCE_THRESH = 30

        removed_line_rects = line_rects.copy()
        # setup and extract min and max line rects
        min_image_line_rect = ()
        max_image_line_rect = ()
        min_line_rect = ()
        max_line_rect = ()
        if orientation=="v":
            min_image_line_rect = (0, 0, 1, image_size[0])
            max_image_line_rect = (image_size[1], 0, 1, image_size[0])
            min_line_rect       = min(line_rects, key=lambda rect:rect[0])
            max_line_rect       = max(line_rects, key=lambda rect:rect[0]+rect[2])
            f_distance          = lambda left, right:right[0]-(left[0]+left[2])
            rev_orientation     = "h"
        elif orientation=="h":
            min_image_line_rect = (0, 0, image_size[1], 1)
            max_image_line_rect = (0, image_size[0], image_size[1], 1)
            min_line_rect       = min(line_rects, key=lambda rect:rect[1])
            max_line_rect       = max(line_rects, key=lambda rect:rect[1]+rect[3])
            f_distance          = lambda top, bottom:bottom[1]-(top[1]+top[3])
            rev_orientation     = "v"

        # return if not contain element between min_line_rect and max_line_rect
        if not Utils.rect_between_two_rects(min_line_rect, max_line_rect, self.text_blocks, orientation=rev_orientation):
            return removed_line_rects

        # check distance and wheter or not contain elements between outside line of image and min(or max) line
        invalid_line_rects = []
        ## check min line rect
        if min_image_line_rect and min_line_rect and f_distance(min_image_line_rect, min_line_rect)<=DISTANCE_THRESH:
            if not Utils.rect_between_two_rects(min_image_line_rect, min_line_rect, self.text_blocks, orientation=rev_orientation):
                invalid_line_rects.append(min_line_rect)
        ## check max line rect
        if min_image_line_rect and min_line_rect and f_distance(max_line_rect, max_image_line_rect)<=DISTANCE_THRESH:
            if not Utils.rect_between_two_rects(max_image_line_rect, max_line_rect, self.text_blocks, orientation=rev_orientation):
                invalid_line_rects.append(max_line_rect)

        # remove invalid line rects
        for line_rects in invalid_line_rects:
            if line_rects in removed_line_rects:
                removed_line_rects.remove(line_rects)

        return removed_line_rects

    def extract_line(self, image):
        """
        :param image:
        :return: extract all of line from the image
        """
        # extract horizontal, vertical, binary image from original image
        horizontal, vertical, binary_image = ImageProcessing.lines_image(image)
        self.binary_image = binary_image

        # extract bounding box of these horizontal lines in the image from horizontal line image
        h_rects = Utils.extract_line_rect(horizontal)
        # extract bounding box of these vertical lines in the image from vertical line image
        v_rects = Utils.extract_line_rect(vertical)

        # remove noise "vertical" line rects if it get from reverse area #12828
        v_rects = Utils.remove_reverse_line_rects(v_rects, self.binary_image, orientation="v")

        # remove lines if contain all elements #13670
        if h_rects:
            h_rects = self.remove_lines_contain_all(h_rects, self.binary_image.shape, self.text_blocks, orientation="h")
        if v_rects:
            v_rects = self.remove_lines_contain_all(v_rects, self.binary_image.shape, self.text_blocks, orientation="v")

        # # remove duplicated bounding rectangle of these horizontal lines
        # h_rects = Utils.remove_duplicate_line_rects(h_rects, "horizontal")
        # # remove duplicated bounding rectangle of these vertical lines
        # v_rects = Utils.remove_duplicate_line_rects(v_rects, "vertical")

        line_rects = h_rects + v_rects

        # find text blocks
        text_block_rects = self.text_blocks.copy()
        # refine the text blocks
        # text_block_rects = ImageProcessing.refine_text_blocks(~self.binary_image.copy(), text_block_rects) #13968(comment)

        # save the refined text blocks instead of the old text block from pixel link
        self.text_blocks = text_block_rects.copy()

        # merge the text block if these text blocks are reached to each others
        text_block_rects = Utils.external_rects(image.shape, text_block_rects)

        # extract the image without it's lines from the original image
        no_line_image = ImageProcessing.no_lines_image(image)

        # remove all text blocks in the no lines image
        new_no_line_image = Utils.fill_boxes(no_line_image.copy(), text_block_rects, (255, 255, 255))

        # detect the rest of the text in the image. Because the text blocks are detected by Infordio pixellink is not enough
        rest_text_blocks = ImageProcessing.text_blocks(new_no_line_image.copy())

        # All the text blocks was found
        text_block_rects = text_block_rects + rest_text_blocks

        # merge all the text block which are near each  others and have the same width or height
        text_block_rects = self.merge_overlap_boxes(text_block_rects, orientation='h', threshold_expand=0)
        text_block_rects = self.merge_overlap_boxes(text_block_rects, orientation='v', threshold_expand=0)

        # merge 2 types of text blocks: detected by Infordio pixellink and detected by morphology algorithm
        text_block_rects = Utils.merge_two_types_text_blocks(self.text_blocks.copy(), text_block_rects)

        # detect shape, logo in the image
        shape_blocks = ImageProcessing.detect_shape(image, horizontal, vertical, self.text_blocks)

        # text_block_rects = text_block_rects + shape_blocks
        text_block_rects = self.text_blocks #12588

        # remove line, which insides text blocks
        invalid_line_rects = []

        for text_block_rect in text_block_rects:
            for line_rect in line_rects:
                # Do not check the long line
                # if line_rect[2] > 180 or line_rect[3] > 100:
                #     continue
                # remove small line insides the text blocks, shape or logo, etc.
                if Utils.line_inside_text_block(text_block_rect, line_rect, 12) and Utils.real_text_block(text_block_rect):
                    invalid_line_rects.append(line_rect)

        # remove the invalid lines
        for line in invalid_line_rects:
            if line in line_rects:
                line_rects.remove(line)

        # find the position of the document in the image
        document_rect = ImageProcessing.document_detection(self.input_image.copy())
        # keep the lines which insides the document area
        line_rects = [line_rect for line_rect in line_rects if Utils.rect_inside_rect(document_rect, line_rect)]

        # remove the small and independence line
        line_rects = Utils.remove_noise_lines_rect(line_rects, text_block_rects)

        lines = []

        # extract the line, which is made by dots
        dot_rects = self.extract_dot_lines(image.copy(), no_line_image.copy(), self.text_blocks.copy())

        # convert bounding rectangle line to Line object
        for box in line_rects:
            lines.append(Utils.convert_box_to_line(box))

        # remove underline text if a line is center alignment with the text block
        lines, self.text_blocks = Utils.remove_underline_text(lines, self.text_blocks.copy())

        # add dotted lines to process like a normal line
        for box in dot_rects:
            lines.append(Utils.convert_box_to_line(box))
        # divide those line into 2 list of lines: horizontal lines and vertical lines
        h_lines, v_lines = Utils.split_lines(lines)

        # The horizontal line and vertical line is reduced if it's intersection is inside the line and
        # distance between start point (end point) and this intersection is smaller than threshold
        h_lines, v_lines = Utils.reduce_line(h_lines, v_lines, 18) #14560(15->18)

        # The horizontal line and vertical line is extended to each others when the distance between
        # start point (end point) of horizontal (vertical) and start point (end point) of vertical (horizontal)
        # is smaller than threshold
        h_lines, v_lines = Utils.extend_line_at_corner(h_lines, v_lines, 21, 21) #14560(15->21)

        # remove small invalid line
        h_lines = Utils.remove_invalid_signed(h_lines)

        # remove overlap text block lines (#12585)
        # h_lines = self.remove_lines_overlap_text_blocks(h_lines, self.text_blocks, orientation="h")
        v_lines = self.remove_lines_overlap_text_blocks(v_lines, self.text_blocks, orientation="v")

        lines = h_lines + v_lines

        # reset connect_at_corner attribute of a line for processing in the rear path
        lines = Utils.reset_connect_at_line_corner(lines)

        # create the image that contains horizontal lines and vertical lines, which is extracted before
        lines_image = horizontal.copy()
        lines_image[vertical == 0] = 0

        # DEBUG
        if Debug.debug_flag == 1:
            text_blocks_image = self.input_image.copy()

            Utils.draw_boxes(text_blocks_image, text_block_rects, (0, 255, 0), 1)

            Debug.write_image(self.binary_image, self.debug_save_path + "1.1 binary_image.jpg")
            Debug.write_image(no_line_image, self.debug_save_path + "2.1 no_line_image.jpg")
            Debug.write_image(text_blocks_image, self.debug_save_path + "2.2 text_blocks_image.jpg")

            text_blocks_and_rects_image = self.input_image.copy()
            Utils.draw_boxes(text_blocks_and_rects_image, text_block_rects, (0, 255, 0), 1)
            Utils.draw_boxes(text_blocks_and_rects_image, line_rects, (0, 0, 255), 1)
            Debug.write_image(text_blocks_and_rects_image, self.debug_save_path + "2.3 text_blocks_and_rects_image.jpg")
        # END

        return lines, lines_image, no_line_image

    def remove_lines_overlap_text_blocks(self, lines, text_blocks, orientation): #12585
        """
        remove line if it overlap text blocks
        
        :param lines: Line class list
        :param text_blocks:
        :param orientation:
        :param shrink_size: size of shrink text block
        :return: removed lines
        """
        def max_h_f(rect):
            return rect[2]

        def max_v_f(rect):
            return rect[3]

        SHRINK_SIZE = -3

        line_overlap_box_f = Utils.h_line_overlap_rect if orientation=="h" else Utils.v_line_overlap_rect
        removed_lines      = lines.copy()
        overlap_blocks     = []
        remove_idx         = []
        remove_cnt         = 0
        for i, line in enumerate(lines):
            for text_block in text_blocks:
                shrinked_text_block = Utils.expand_rect(text_block, SHRINK_SIZE)
                if line_overlap_box_f(line, shrinked_text_block, percent=50):
                    remove_idx.append(i)
                    overlap_blocks.append(text_block)
            if remove_idx:
                expand_length = 0
                if orientation=="h":
                    max_rect      = max(overlap_blocks, key=max_h_f)
                    expand_length = max_rect[2]//2
                elif orientation=="v":
                    max_rect = max(overlap_blocks, key=max_v_f)
                    expand_length = max_rect[3]//2
                else:
                    return removed_lines
                bounding_rect = Utils.bounding_rect(overlap_blocks)
                bounding_rect = Utils.expand_rect(bounding_rect, expand_length)
                if Utils.line_inside_box(bounding_rect, line):
                    removed_lines.pop(i-remove_cnt)
                    remove_cnt += 1
        return removed_lines


    def extract_dot_lines(self, image, no_line_image, text_blocks):
        """
        :param image:
        :param no_line_image:
        :param text_blocks:
        :return: lines, which is created from several dots
        """

        def extract_dot_line(dot_image):
            """
            :param dot_image:
            :return: bounding rectangle of the dot lines
            """
            contours = cv2.findContours(dot_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]
            rects = [cv2.boundingRect(c) for c in contours]
            return [rect for rect in rects if (rect[3] < 7 and rect[2] > 150) or (rect[2] < 7 and rect[3] > 150)]

        noise_dot_blocks = ImageProcessing.dot_noise_blocks(image.copy())

        no_noise_dot_image = Utils.fill_boxes(no_line_image.copy(), noise_dot_blocks, (0, 0, 0))

        # extract the dot lines image
        horizontal_dot_lines_image, vertical_dot_lines_image = ImageProcessing.dot_lines_image(no_noise_dot_image.copy())

        # find bounding rectangle line, which is made by horizontal dotted line in image
        horizontal_dot_rects = extract_dot_line(horizontal_dot_lines_image)

        # find bounding rectangle line, which is made by vertical dotted line in image
        vertical_dot_rects = extract_dot_line(vertical_dot_lines_image)

        dot_rects = horizontal_dot_rects + vertical_dot_rects

        text_blocks = [Utils.expand_rect(text_block, -1) for text_block in text_blocks] # fix at #12510 (-4 -> -1)

        # remove wrong line in the list of these dotted lines
        dot_rects = Utils.remove_dot_lines_noise(dot_rects, text_blocks)

        return dot_rects

    def extract_boxes(self, image_size, tables):
        table_image = np.ones((image_size[0], image_size[1]), np.uint8) * 255

        for table in tables:
            Utils.draw_table(table_image, table, (0, 0, 0), (0, 0, 0), (0, 0, 0), 1)

        contours = cv2.findContours(table_image, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[1]
        boxes = [cv2.boundingRect(c) for c in contours]

        # DEBUG
        if Debug.debug_flag == 1:
            boxes_image = cv2.cvtColor(table_image, cv2.COLOR_GRAY2BGR)
            Utils.draw_boxes(boxes_image, boxes, (0, 255, 0), 1)
            Debug.write_image(boxes_image, self.debug_save_path + "5.0 boxes_image.jpg")
        # END

        return boxes

    def extract_table_information(self, tables):
        """Extract all table information: table frame (bounding box), table real-lines, table virtual-lines
        :param tables: these bounding box of a tables

        :return table_frames: list of table bounding box
        :return table_real_lines: list of table real-lines as rectangle
        :return table_virtual_lines: list of table virtual-lines as rectangle
        """
        table_frames = []
        table_real_lines = []
        table_virtual_lines = []

        for table in tables:
            table_frames.append(table.bounding_rect())

            for line in table.all_vertical_lines() + table.all_horizontal_lines():
                table_real_lines.append(line.bounding_rect())

            for line in table.divider_vertical_lines + table.divider_horizontal_lines:
                table_virtual_lines.append(line.bounding_rect())

        return table_frames, table_real_lines, table_virtual_lines


    def extend_boxes(self, boxes, single_lines):
        """
        :param boxes: the bounding rectangle of these tables in the image
        :param single_lines: the list of the lines, which do not inside any bounding box above
        :return: finding more boxes which is created by serveral single_lines
                For example:
                these line will create the box of itself
                   --------
                |             |
                |             | --> generate bounding rectangle box of it
                |             |
                |             |
                   ---------

        """
        rects = []

        h_single_lines, v_single_lines = Utils.split_lines(single_lines)
        h_line_pairs, v_line_pairs = Utils.line_pairs(h_single_lines, v_single_lines)

        for h_line_pair in h_line_pairs:
            a_h_line, b_h_line = h_line_pair
            points = [a_h_line.start_point, a_h_line.end_point, b_h_line.start_point, b_h_line.end_point]
            for v_line in v_single_lines:
                if Utils.connect_at_corner(a_h_line, v_line) and Utils.connect_at_corner(b_h_line, v_line):
                    points.append(v_line.start_point)
                    points.append(v_line.end_point)

                    if a_h_line in h_single_lines:
                        h_single_lines.remove(a_h_line)
                    if b_h_line in h_single_lines:
                        h_single_lines.remove(b_h_line)

            if len(points) > 4:
                bounding_rect = cv2.boundingRect(np.array(points, np.float32))
                if not any([Utils.rect_overlap_rect(bounding_rect, box) for box in boxes]): # check new box wether collision other boxes #14818
                    if Utils.is_rect_divide_text_boxes(bounding_rect, self.text_blocks, cnt=1): # check bounding_box wether divide text_blocks #14814
                        rects.append(bounding_rect)

        for v_line_pair in v_line_pairs:
            a_v_line, b_v_line = v_line_pair
            points = [a_v_line.start_point, a_v_line.end_point, b_v_line.start_point, b_v_line.end_point]
            for h_line in h_single_lines:
                if Utils.connect_at_corner(a_v_line, h_line) and Utils.connect_at_corner(b_v_line, h_line):
                    points.append(h_line.start_point)
                    points.append(h_line.end_point)

            if len(points) > 4:
                bounding_rect = cv2.boundingRect(np.array(points, np.float32))
                if not any([Utils.rect_overlap_rect(bounding_rect, box) for box in boxes]): # check new box wether collision other boxes #14818
                    if Utils.is_rect_divide_text_boxes(bounding_rect, self.text_blocks, cnt=1): # check bounding_box wether divide text_blocks #14814
                        rects.append(bounding_rect)
        boxes.extend(rects)
        return boxes

    def bounding_or_remove_broken_boxes(self, boxes, single_lines, orientation="h"): #13200
        """
        Bounding boxes if some single lines between two broken boxes (only external boxes)
        Remove boxes if has not same boxes and overlap lines or text blocks (only external boxes)

        :param boxes:
        :param single_lines: independent lines
        :return bounded boxes:
        """
        same_rect_f, line_overlap_rect_f, idx = (Utils.same_h_rect, Utils.v_line_overlap_rect, 1) if orientation=="h" else (Utils.same_v_rect, Utils.h_line_overlap_rect, 0)

        # constants
        THRESH  = 20
        N_LINES = 3
        N_TEXTS = 5
        PERCENT_LINE = 10
        PERCENT_TEXT = 30
        EXPAND_SIZE  = 5
        LINE_LENGTH  = 80 #14818

        # initialize
        inv_orientation    = "v" if orientation=="h" else "h"
        single_lines       = [line for line in single_lines if line.orientation==inv_orientation and line.length()>LINE_LENGTH]
        single_text_blocks = Utils.single_text_blocks(boxes, self.text_blocks, expand=EXPAND_SIZE)
        external_boxes     = sorted(Utils.outside_rects(boxes), key=lambda box:(box[idx], box[idx^1]))

        remove_boxes   = []
        bounding_boxes = []
        for i, src_box in enumerate(external_boxes):
            if src_box in remove_boxes:
                continue
            # find same boxes
            same_boxes = [dst_box for dst_box in set(external_boxes)-set([src_box]) if same_rect_f(src_box, dst_box, thresh=THRESH)]
            if same_boxes: # bounding boxes
                for same_box in same_boxes:
                    # bounding two boxes if single lines between two boxes
                    between_lines = []
                    if src_box[idx]+src_box[idx+2]<same_box[idx]:
                        between_lines = Utils.line_between_two_rects(src_box, same_box, single_lines, orientation=orientation)
                    elif same_box[idx]+same_box[idx+2]<src_box[idx]:
                        between_lines = Utils.line_between_two_rects(same_box, src_box, single_lines, orientation=orientation)
                    else:
                        continue
                    if len(between_lines)>=N_LINES:
                        # check bounding_box do not divide a content #14611
                        bounding_box = Utils.bounding_rect([src_box, same_box])
                        if not Utils.is_rect_divide_content(bounding_box, self.content_blocks(), expand_size=15, overlap_percent=30, cnt=1):
                            remove_boxes.extend([src_box, same_box])
                            bounding_boxes.append(bounding_box)
            else: # remove boxes
                overlap_cnt = 0
                # if box overlap text blocks
                for text_block in single_text_blocks:
                    if Utils.rect_overlap_rect_with_percent(src_box, text_block, threshold=PERCENT_TEXT, min_rect=True):
                        overlap_cnt += 1
                        if overlap_cnt>=N_TEXTS:
                            remove_boxes.append(src_box)
                            break
                # if box overlap lines
                if not remove_boxes or (remove_boxes and remove_boxes[-1]!=src_box):
                    overlap_cnt = 0
                    for line in single_lines:
                        if line_overlap_rect_f(line, src_box, percent=PERCENT_LINE):
                            overlap_cnt += 1
                            if overlap_cnt>=N_LINES:
                                remove_boxes.append(src_box)
                                break

        if remove_boxes:
            for remove_box in remove_boxes:
                if remove_box in boxes:
                    boxes.remove(remove_box)
        if bounding_boxes:
            boxes.extend(bounding_boxes)
        # remove boxes inside box
        boxes = self.remove_box_inside_box(boxes)
        return boxes

    def content_blocks(self):
        """Find all possible text blocks as content blocks

        Returns:
            content_blocks: List of all content blocks
        """
        content_rects = self.text_blocks

        content_rects = sorted(content_rects, key=lambda rect: rect[1])

        # content_rects = [Utils.expand_width_rect(content_rect, -5) if content_rect[2] > 50 else content_rect for content_rect in content_rects] #13244

        # Only small rect convert to content block (height < 60 pixel)
        # return [ContentBlock(content_rect, idx) for idx, content_rect in enumerate(content_rects) if content_rect[3] < 120]
        return [ContentBlock(content_rect, idx) for idx, content_rect in enumerate(content_rects) if content_rect[2] > 10 or content_rect[3] > 10]

    def extract_box_line_region(self, use_virtual_lines_for_blocks=False):
        """The main method to extract table bouding box, table real-lines, table virtual-lines

        set use_virtual_lines_for_blocks if you want to use actual + virtual lines
        when returning table blocks

        Returns:
            table_blocks: this would be the equivalent of a cell in a spreadsheet
            table_frames: list of table bounding box
            table_real_lines: list of table real-lines as rectangle
            table_virtual_lines: list of table virtual-lines as rectangle

        :return table_frames: list of table bounding box
        :return table_real_lines: list of table real-lines as rectangle
        :return table_virtual_lines: list of table virtual-lines as rectangle

        """
        # enable/disable virtual line (SHOULD MOVE to __init__)
        self.use_virtual_lines_for_blocks = use_virtual_lines_for_blocks

        # DEBUG
        if Debug.debug_flag == 1:
            Debug.write_image(self.input_image, self.debug_save_path + "1.0 original_image.jpg")
        # END

        gray_image = cv2.cvtColor(self.input_image, cv2.COLOR_BGR2GRAY)

        # extract list of lines object(coordination)
        # image contains horizontal lines and vertical lines
        # image do not contain any lines
        lines, lines_image, no_line_image = self.extract_line(gray_image)

        # extract the bounding rectangle of these tables inside the image
        boxes = self.extract_table_boxes(lines)

        # remove the small boxes and all the lines inside those boxes
        boxes, lines = self.refine_boxes_and_lines(boxes, lines)

        # Find all possible text blocks (as content blocks)
        content_blocks = self.content_blocks()

        # DEBUG
        if Debug.debug_flag == 1:
            boxes_lines_image = self.input_image.copy()
            Utils.draw_boxes(boxes_lines_image, boxes, color=(0, 255, 0), thickness=1)
            Utils.draw_lines(boxes_lines_image, lines, color=(0, 0, 255), thickness=1)
            Debug.write_image(boxes_lines_image, self.debug_save_path + "2.4 boxes_lines_image.jpg")

            debug = self.input_image.copy()
            Utils.draw_content_blocks(debug, content_blocks, (0, 0, 255), 1)
            Debug.write_image(debug, self.debug_save_path + "3.1 content_blocks.jpg")

        # END

        table_processing = TableProcessing(self.input_image, self.binary_image, self.crnn_chars, self.header_regex, self.flag_semi_virtual, self.debug_save_path)

        table_boxes = [TableBox(box, True) for box in boxes]
        tables = table_processing.process(table_boxes, lines, content_blocks, self.use_virtual_lines_for_blocks)

        boxes = self.extract_boxes(gray_image.shape, tables)
        
        if Debug.debug_flag == 1:
            boxes_image = self.input_image.copy()
            Utils.draw_boxes(boxes_image, boxes, color=(255,0,255), thickness=1)
            Debug.write_image(boxes_image, self.debug_save_path + "3.2 boxes_image.jpg")
        
        # single_lines = []
        # for line in lines:
        #     if not line.table_line:
        #         single_lines.append(line)

        lines_processed_image = np.zeros(self.input_image.shape,dtype=np.uint8)
        lines_processed_image.fill(0) # or img[:] = 255        

        # this will draw all the lines (frame, real, maybe virtual) for each table object
        for idx, table in enumerate(tables):
            Utils.draw_table(lines_processed_image, table, draw_virtual_lines = self.use_virtual_lines_for_blocks)

        #binarize
        lines_gray_image = cv2.cvtColor(lines_processed_image, cv2.COLOR_BGR2GRAY)
        ret, lines_bin_image = cv2.threshold(lines_gray_image,1,255,cv2.THRESH_BINARY)

        Debug.write_image(lines_bin_image, self.debug_save_path + "3.3 lines_bin_image.jpg")
        # get the cells
        image, contours, hierarchy = cv2.findContours(lines_bin_image,cv2.RETR_CCOMP,cv2.CHAIN_APPROX_NONE)

        # get the inner contours
        inner_contour_indexes = []
        if hierarchy is not None:
            hierarchy = hierarchy[0] # noOfContour x 4
            for contour_idx in range(hierarchy.shape[0]):
                if hierarchy[contour_idx][3] != -1:
                    inner_contour_indexes.append(contour_idx)

        bounding_boxes = []
        # get the bounding rect
        for contour_idx in inner_contour_indexes:
            bounding_rect = cv2.boundingRect(contours[contour_idx])
            bounding_rect = (bounding_rect[0]+1,bounding_rect[1]+1,bounding_rect[2]-2,bounding_rect[3]-2)
            if not Utils.is_rect_divide_content(bounding_rect, content_blocks): # ignore rect if divide content #13993
                bounding_boxes.append(bounding_rect)

        # DEBUG
        if Debug.debug_flag == 1:
            table_image = self.input_image.copy()
            table_column_block_image = self.input_image.copy()
            table_row_block_image = self.input_image.copy()
            table_column_row_block_image = self.input_image.copy()
            table_content_blocks_image = self.input_image.copy()
            table_blocks_image = self.input_image.copy()

            #boxes_image = self.input_image.copy()
            Utils.draw_boxes(table_blocks_image, bounding_boxes, (0,0,255),1)

            # a table is a rectangle containing real, virtual, hor/vert lines
            for idx, table in enumerate(tables):
                Utils.draw_table(table_image, table, draw_virtual_lines=0)
                Utils.draw_content_blocks(table_content_blocks_image, table.content_blocks, (0, 0, 255), 1)
                #Utils.draw_boxes(table_blocks_image, table_processing.get_table_blocks(table), thickness=2)
                for group_content_block in table.column_groups:
                    Utils.draw_box(table_column_block_image, group_content_block.bounding_rect(), (0, 255, 0), 1)
                    Utils.draw_box(table_column_row_block_image, group_content_block.bounding_rect(), (255, 0, 255), 1)

                for group_content_block in table.row_groups:
                    Utils.draw_box(table_row_block_image, group_content_block.bounding_rect(), (255, 0, 255), 1)
                    Utils.draw_box(table_column_row_block_image, group_content_block.bounding_rect(), (0, 255, 0), 1)

            # Utils.draw_lines(table_image, single_lines, (0, 0, 255), 1)

            Debug.write_image(table_image, self.debug_save_path + "4.0 table_lines_image.jpg")
            Debug.write_image(table_column_block_image, self.debug_save_path + "4.1 table_column_block_image.jpg")
            Debug.write_image(table_row_block_image, self.debug_save_path + "4.2 table_row_block_image.jpg")
            Debug.write_image(table_column_row_block_image, self.debug_save_path + "4.3 table_column_row_block_image.jpg")
            Debug.write_image(table_content_blocks_image, self.debug_save_path + "4.4 table_content_blocks_image.jpg")
            Debug.write_image(table_blocks_image, self.debug_save_path + "4.5 table_blocks_image.jpg")

        # END
        # return boxes, single_lines
        table_frames, table_real_lines, table_virtual_lines = self.extract_table_information(tables)
        return bounding_boxes, table_frames, table_real_lines, table_virtual_lines

def read_text_blocks_from_file(path_file):
    with open(path_file) as input:
        data = json.load(input)
    return data

if __name__ == "__main__":
    start_time = time.time()
    parser = argparse.ArgumentParser()
    parser.add_argument("--image_path", "-p", dest="image_file_path", type=str, default="images/04.jpg",
                        help="image file path")
    parser.add_argument("--debug", "-g", type=int, default=1, help="Execute the debugging process. 0: Normal 1: Debug")

    args = parser.parse_args()
    path_file = args.image_file_path
    Debug.debug_flag = args.debug

    #text_blocks_image = path_file.split(".")[0] + "_text_blocks.json"

    #text_blocks = read_text_blocks_from_file(text_blocks_image)

    text_blocks = ""# 引数で対象データをもらうように変更する
    image_size_processing = ""# 引数で対象データをもらうように変更する
                                               

    file_name = ntpath.basename(path_file).split('.')[0]
    start_timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H_%M_%S")
    debug_path = 'debug/' + file_name + '.' + start_timestamp + '/'

    if args.image_file_path:
        file_path = args.image_file_path
        if not file_path.endswith(".jpg"):
            file_path = file_path + ".jpg"

        image = cv2.imread(file_path)
        if image is not None:
            extract_region = ExtractRegion(image, text_blocks, image_size_processing, debug_path, file_name)
            # extract all boxes and lines in the image
            bounding_boxes, table_frames, table_real_lines, table_virtual_lines = extract_region.extract_box_line_region()

            # DEBUG
            if Debug.debug_flag == 1:
                frame_image = extract_region.input_image.copy()
                real_lines_image = extract_region.input_image.copy()
                virtual_lines_image = extract_region.input_image.copy()
                
                Utils.draw_boxes(extract_region.input_image, table_real_lines, (0, 255, 0), 2)
                Utils.draw_boxes(extract_region.input_image, table_virtual_lines, (255, 0, 0), 1)
                Utils.draw_boxes(extract_region.input_image, table_frames, (0, 0, 255), 3)
                Debug.write_image(extract_region.input_image, extract_region.debug_save_path + "6.0 output_image.jpg")
                
                Utils.draw_boxes(frame_image, table_frames, (0,0,255), 2)
                Utils.draw_boxes(real_lines_image, table_real_lines, (0,255,0), 2)
                Utils.draw_boxes(virtual_lines_image, table_virtual_lines, (255,0,0), 2)
                Debug.write_image(frame_image, extract_region.debug_save_path + "7.0 frames_image.jpg")
                Debug.write_image(real_lines_image, extract_region.debug_save_path + "7.1 real_lines_image.jpg")
                Debug.write_image(virtual_lines_image, extract_region.debug_save_path + "7.2 virtual_lines_image.jpg")
                
            # END

            print('Done! Processing time: ', time.time() - start_time)
        else:
            print("Invalid input image")
