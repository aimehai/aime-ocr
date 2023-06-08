import cv2
import math
import itertools
import re
import numpy as np

from table_extraction.debug import Debug

class Utils(object):

    @staticmethod
    def is_noise(rect):
        """
        :param rect:
        :return: the all of the rectangles if rectangle's square is greater than a threshold
        """
        THRESH_SIZE = 115
        w, h = rect[2:]
        is_noise = True if w * h < THRESH_SIZE else False
        return is_noise

    @staticmethod
    def resize_image(image, width=1936, height=2730):
        if image.shape[0] > image.shape[1]:
            size = (width, height)
        else:
            size = (height, width)
        return cv2.resize(image, size)

    @staticmethod
    def refill_rects(image):
        contours = cv2.findContours(image.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]
        rects = [rect for rect in rects if rect[2] < 20 or rect[3] < 20]

    @staticmethod
    def shrink_line(h_lines, v_lines, threshold=10):
        """
        :param h_lines: those horizontal lines in the table
        :param v_lines: those vertical lines in the table
        :param threshold: maximum of vertical line or horizontal line can be extended.
                 the horizontal line and vertical line can be extended or shrunk
                 the start point(end point) of the line will be set at intersection point of these lines
                 when the distance between start point(end point) of horizontal(vertical) and
                 start point (end point) of vertical (horizontal) to the intersection point is smaller than threshold.
        :return: horizontal lines, vertical lines in the table
        """
        for v_line in v_lines:
            for h_line in h_lines:
                if h_line.start_point[1] < v_line.start_point[1] - threshold or h_line.start_point[1] > v_line.end_point[1] + threshold:
                    continue

                 # if line is a point, bail out
                if h_line.start_point[0] == h_line.end_point[0] or v_line.start_point[1] == v_line.end_point[1]:
                    continue

                if Utils.distance_from_line_to_line(h_line, v_line) <= threshold:

                    intersection_point = Utils.line_intersection(h_line, v_line)
                    if not intersection_point[0]:
                        continue

                    if Utils.distance_from_point_to_point(h_line.start_point, intersection_point) < threshold:
                        h_line.original_start_point = h_line.start_point # add at #112511
                        h_line.start_point = intersection_point
                        h_line.connect_at_start_point = True

                    if Utils.distance_from_point_to_point(h_line.end_point, intersection_point) < threshold:
                        h_line.original_end_point = h_line.end_point # add at #112511
                        h_line.end_point = intersection_point
                        h_line.connect_at_end_point = True

                    if Utils.distance_from_point_to_point(v_line.start_point, intersection_point) < threshold:
                        v_line.original_start_point = v_line.start_point # add at #112511
                        v_line.start_point = intersection_point
                        v_line.connect_at_start_point = True

                    if Utils.distance_from_point_to_point(v_line.end_point, intersection_point) < threshold:
                        v_line.original_end_point = v_line.end_point # add at #112511
                        v_line.end_point = intersection_point
                        v_line.connect_at_end_point = True

        # Remove all lines with length = 0
        h_lines = [line for line in h_lines if line.length() > 0]
        v_lines = [line for line in v_lines if line.length() > 0]

        return h_lines, v_lines

    @staticmethod
    def reduce_line(h_lines, v_lines, threshold=15):
        """
        :param h_lines: all of the horizontal lines
        :param v_lines: all of the vertical lines
        :param threshold: maximum of a line's length can be reduced
        :return: the list of horizontal lines and vertical lines
                 The horizontal line and vertical line is reduced if it's intersection is inside the line and
                 distance between start point (end point) and this intersection is smaller than threshold
        """
        for v_line in v_lines:
            for h_line in h_lines:
                if Utils.is_intersect(h_line, v_line):
                    intersection_point = Utils.line_intersection(h_line, v_line)
                    if not intersection_point[0]:
                        continue
                    if Utils.distance_from_point_to_point(h_line.start_point, intersection_point) < threshold:
                        h_line.start_point = intersection_point
                        h_line.connect_at_start_point = True
                    if Utils.distance_from_point_to_point(v_line.start_point, intersection_point) < threshold:
                        v_line.start_point = intersection_point
                        v_line.connect_at_start_point = True
                    if Utils.distance_from_point_to_point(h_line.end_point, intersection_point) < threshold:
                        h_line.end_point = intersection_point
                        h_line.connect_at_end_point = True
                    if Utils.distance_from_point_to_point(v_line.end_point, intersection_point) < threshold:
                        v_line.end_point = intersection_point
                        v_line.connect_at_end_point = True

        # Remove all lines with length = 0
        h_lines = [line for line in h_lines if line.length() > 0]
        v_lines = [line for line in v_lines if line.length() > 0]

        return h_lines, v_lines

    @staticmethod
    def is_intersect(h_line, v_line):
        h_start_point = h_line.start_point
        h_end_point = h_line.end_point
        v_start_point = v_line.start_point
        v_end_point = v_line.end_point
        return h_start_point[0] <= v_start_point[0] and v_start_point[0] <= h_end_point[0] \
               and v_start_point[1] <= h_start_point[1] and h_start_point[1] <= v_end_point[1]

    @staticmethod
    def line_intersection(a_line, b_line):
        line1 = (a_line.start_point, a_line.end_point)
        line2 = (b_line.start_point, b_line.end_point)

        xdiff = (line1[0][0] - line1[1][0], line2[0][0] - line2[1][0])
        ydiff = (line1[0][1] - line1[1][1], line2[0][1] - line2[1][1])  # Typo was here

        def det(a, b):
            return a[0] * b[1] - a[1] * b[0]

        div = det(xdiff, ydiff)
        if div == 0:
            return None, None #14560
            # raise Exception('lines do not intersect')

        d = (det(*line1), det(*line2))
        x = int(det(d, xdiff) / div)
        y = int(det(d, ydiff) / div)
        return x, y

    @staticmethod
    def lines_intersect_line(lines, line):
        if line.orientation=="h":
            return [other_line for other_line in lines if Utils.is_intersect(line, other_line)]
        elif line.orientation=="v":
            return [other_line for other_line in lines if Utils.is_intersect(other_line, line)]
        else:
            return []

    @staticmethod
    def line_split_line(line, split_line):
        """ Split line by split_line
        """
        front_line = line.copy()
        back_line  = line.copy()
        if line.orientation=="h":
            if Utils.is_intersect(line, split_line):
                x, y = Utils.line_intersection(line, split_line)
                if not x:
                    return None
                if line.start_point[0]==x or line.end_point[0]==x:
                    return None
                front_line.end_point  = (x, front_line.end_point[1])
                back_line.start_point = (x, back_line.start_point[1])
                return front_line, back_line
            return None
        else:
            if Utils.is_intersect(split_line, line):
                x, y = Utils.line_intersection(line, split_line)
                if not x:
                    return None
                if line.start_point[1]==y or line.end_point[1]==y:
                    return None
                front_line.end_point  = (front_line.end_point[0], y)
                back_line.start_point = (back_line.start_point[0], y)
                return front_line, back_line
        return None

    @staticmethod
    def duplicate_line_rects(a_line_rect, b_line_rect, orientation="horizontal", threshold=5):
        """
        :param a_line_rect: the bounding rectangle of a line
        :param b_line_rect: the bounding rectangle of the line
        :param orientation: the orientation of the line
        :param threshold: if the distance between two lines is smaller than this parameter, these two lines are one line.
        :return: Whether or not two lines are duplicated.
        """
        a_x, a_y, a_w, a_h = a_line_rect
        b_x, b_y, b_w, b_h = b_line_rect
        if orientation == "horizontal":
            return (a_x <= b_x or a_x - b_x <= threshold) and (b_x + b_w <= a_x + a_w or b_x + b_w - a_x - a_w <= threshold) and abs(b_y + b_h / 2 - a_y - a_h / 2) <= (a_h + b_h) / 2
        else:
            return (a_y <= b_y or a_y - b_y <= threshold) and (b_y + b_h <= a_y + a_h or b_y + b_h - a_y - a_h <= threshold) and abs(b_x + b_w / 2 - a_x - a_w / 2) <= (a_w + b_w) / 2

    @staticmethod
    def get_area_from_binary_image(rect, image):
        x, y, w, h = rect
        return image[y:y+h,x:x+w]

    @staticmethod
    def remove_reverse_line_rects(line_rects, binary_image, orientation="v"):
        """
        remove noise line rects if reverse area

        :param line_rects:
        :param binary_image: background is black
        :param orientation: "v" or "h"
        :return removed_rects:
        """
        REVERSE_NOISE_SIZE   = 40
        REVERSE_AREA_PERCENT = 70
        count = 0
        removed_line_rects = line_rects.copy()
        for i, line_rect in enumerate(line_rects):
            size = line_rect[2] if orientation=="h" else line_rect[3]
            if size>REVERSE_NOISE_SIZE:
                continue
            part_area  = Utils.get_area_from_binary_image(line_rect, binary_image)
            max_white  = line_rect[2]*line_rect[3]*255 # max number of white on line_rect
            area_white = np.sum(part_area)
            if area_white/max_white*100>=REVERSE_AREA_PERCENT:
                removed_line_rects.pop(i-count)
                count += 1
        return removed_line_rects

    @staticmethod
    def remove_duplicate_line_rects(rects, orientation="horizontal"):
        """
        :param rects: the list bounding rectangle of lines
        :param orientation: the orientation of the list of lines.
        :return: the list bounding rectangle of the lines without duplicated lines
        """
        if orientation == "horizontal":
            rects = sorted(rects, key=lambda rect: rect[2], reverse=True)
        else:
            rects = sorted(rects, key=lambda rect: rect[3], reverse=True)

        # list bounding rectangle of duplicated line
        duplicate_line_rects = []
        # check the line is duplicated or not
        for rect_pair in itertools.combinations(rects, r=2):
            if Utils.duplicate_line_rects(rect_pair[0], rect_pair[1], orientation):
                duplicate_line_rects.append(rect_pair[1])

        # remove duplicated line
        for rect in duplicate_line_rects:
            if rect in rects:
                rects.remove(rect)
        return rects

    @staticmethod
    def same_line(a_line, b_line):
        return a_line.start_point == b_line.start_point and a_line.end_point == b_line.end_point

    @staticmethod
    def same_rect(a_rect, b_rect):
        return a_rect[0] == b_rect[0] and a_rect[1] == b_rect[1] and a_rect[2] == b_rect[2] and a_rect[3] == b_rect[3]

    @staticmethod
    def same_h_rect(a_rect, b_rect, thresh=0):
        return a_rect[0]-thresh<=b_rect[0]<=a_rect[0]+thresh and a_rect[2]-thresh<=b_rect[2]<=a_rect[2]+thresh

    @staticmethod
    def same_v_rect(a_rect, b_rect, thresh=0):
        return a_rect[1]-thresh<=b_rect[1]<=a_rect[1]+thresh and a_rect[3]-thresh<=b_rect[3]<=a_rect[3]+thresh

    @staticmethod
    def same_position(a_line, b_line, threshold=5):
        if a_line.orientation == "h":
            return Utils.distance_from_point_to_point(a_line.start_point, b_line.start_point) <= threshold \
                    and  abs(Utils.width_line(a_line) - Utils.width_line(b_line)) <= threshold
        else:
            return Utils.distance_from_point_to_point(a_line.start_point, b_line.start_point) <= threshold \
                    and abs(Utils.height_line(a_line) - Utils.height_line(b_line)) <= threshold

    @staticmethod
    def merge_duplicate_lines(a_line, b_line):
        from .table_processing import Line
        if a_line.orientation == "h":
            start_point = (a_line.start_point[0], int((a_line.start_point[1] + b_line.start_point[1]) / 2))
            end_point = (a_line.end_point[0], int((a_line.end_point[1] + b_line.end_point[1]) / 2))
            return Line(start_point, end_point, 0, "h")
        else:
            start_point = (int((a_line.start_point[0] + b_line.start_point[0]) / 2), a_line.start_point[1])
            end_point = (int((a_line.end_point[0] + b_line.end_point[0]) / 2), a_line.end_point[1])
            return Line(start_point, end_point, 0, "v")

    @staticmethod
    def distance_from_point_to_point(a_point, b_point):
        x1, y1 = a_point
        x2, y2 = b_point
        return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

    @staticmethod
    def distance_from_line_to_line(h_line, v_line):
        if Utils.is_intersect(h_line, v_line):
            return 0
        else:
            d11 = Utils.distance_from_point_to_line(h_line.start_point, v_line)
            d12 = Utils.distance_from_point_to_line(h_line.end_point, v_line)
            d1 = min(d11, d12)

            d21 = Utils.distance_from_point_to_line(v_line.start_point, h_line)
            d22 = Utils.distance_from_point_to_line(v_line.end_point, h_line)
            d2 = min(d21, d22)

            if Utils.horizontal_line_cut_vertical_line(h_line, v_line):
                return d1
            elif Utils.vertical_line_cut_horiontal_line(v_line, h_line):
                return d2
            else:
                return max(d1, d2)

    @staticmethod
    def distance_from_point_to_line(point, line):
        x1, y1 = line.start_point
        x2, y2 = line.end_point
        x0, y0 = point
        return abs((x2 - x1) * (y1 - y0) - (x1 - x0) * (y2 - y1)) / np.sqrt(np.square(x2 - x1) + np.square(y2 - y1))

    @staticmethod
    def distance_from_line_to_box(box, line, direction):
        distance = 1000
        box_x, box_y, box_w, box_h = box
        if line.orientation == "h":
            position = line.start_point[1]
        else:
            position = line.start_point[0]

        if direction == "left":
            distance = position - box_x
        elif direction == "top":
            distance = position - box_y
        elif direction == "right":
            distance = box_x + box_w - position
        elif direction == "bottom":
            distance = box_y + box_h - position

        return abs(distance)

    @staticmethod
    def distance_from_box_to_box(src_box, dst_box):
         c1 = Utils.calc_centroid(src_box)
         c2 = Utils.calc_centroid(dst_box)
         return Utils.distance_from_point_to_point(c1, c2)

    @staticmethod
    def is_box_far_box(src_box, dst_box, times=1):
        distance = Utils.distance_from_box_to_box(src_box, dst_box)
        if src_box[2]*times<distance:
            return True
        return False

    @staticmethod
    def calc_centroid(box):
        x, y, w, h = box
        return x+w/2, y+h/2

    @staticmethod
    def split_lines(lines):
        """
        :param lines: the list of the lines
        :return: divide those line into 2 list: horizontal lines and vertical lines
        """
        h_lines = [line for line in lines if line.orientation == "h"]
        v_lines = [line for line in lines if line.orientation == "v"]
        return h_lines, v_lines

    @staticmethod
    def merge_lines(a_line, b_line, orientation="horizontal"):
        from table_extraction.line import Line

        if orientation == "horizontal":
            start_x = a_line.start_point[0] if a_line.start_point[0] < b_line.start_point[0] else b_line.start_point[0]
            end_x = b_line.end_point[0] if a_line.end_point[0] < b_line.end_point[0] else a_line.end_point[0]
            y = int((a_line.start_point[1] + b_line.start_point[1]) / 2)
            width = int((a_line.width + b_line.width) / 2)

            line = Line((start_x, y), (end_x, y), width, orientation)

        else:
            start_y = a_line.start_point[1] if a_line.start_point[1] < b_line.start_point[1] else b_line.start_point[1]
            end_y = b_line.end_point[1] if a_line.end_point[1] < b_line.end_point[1] else a_line.end_point[1]
            x = int((a_line.start_point[0] + b_line.start_point[0]) / 2)
            width = int((a_line.width + b_line.width) / 2)

            line = Line((x, start_y), (x, end_y), width, orientation)

        line.connect_at_start_point = a_line.connect_at_start_point
        line.connect_at_end_point = b_line.connect_at_end_point
        return line

    def merge_border_lines(lines, orientation="horizontal"):
        if len(lines) == 1:
            return lines[0]
        else:
            if orientation == "horizontal":
                lines = sorted(lines, key=lambda line: line.start_point[0])
            else:
                lines = sorted(lines, key=lambda line: line.start_point[1])
            start_line = lines[0]
            end_line = lines[-1]

            return Utils.merge_lines(start_line, end_line, orientation)

    @staticmethod
    def extend_lines(a_line, b_line, orientation="horizontal"):
        if orientation == "horizontal":
            b_line.start_point = (a_line.start_point[0], b_line.start_point[1])
        else:
            b_line.start_point = (b_line.start_point[0], a_line.start_point[1])
        b_line.connect_at_start_point = a_line.connect_at_start_point

    @staticmethod
    def sort_lines(h_lines, v_lines, type="position"):
        if type == "position":
            h_lines = sorted(h_lines, key=lambda line: line.start_point[1])
            v_lines = sorted(v_lines, key=lambda line: line.start_point[0])
        elif type == "length":
            h_lines = sorted(h_lines, key=lambda line: line.end_point[1] - line.start_point[1])
            v_lines = sorted(v_lines, key=lambda line: line.end_point[0] - line.start_point[0])
        return h_lines, v_lines

    @staticmethod
    def horizontal_line_cut_vertical_line(h_line, v_line):
        return h_line.start_point[1] >= v_line.start_point[1] and h_line.start_point[1] <= v_line.end_point[1]

    @staticmethod
    def vertical_line_cut_horiontal_line(v_line, h_line):
        return v_line.start_point[0] >= h_line.start_point[0] and v_line.start_point[0] <= h_line.end_point[0]

    @staticmethod
    def create_virtual_vertical_line(h_line, neighbor_line, direction="start"):
        from .table_processing import Line

        if direction == "start":
            if neighbor_line.connect_at_start_point:
                virtual_v_line = Line(h_line.start_point, (h_line.start_point[0], neighbor_line.start_point[1]), 0, 'v')
                virtual_v_line.virtual_line = True
                virtual_v_line.connect_at_start_point = True
                virtual_v_line.connect_at_end_point = True
                h_line.connect_at_start_point = True
                return virtual_v_line
            else:
                x_position = 0
                if h_line.start_point[0] > neighbor_line.start_point[0]:
                    x_position = neighbor_line.start_point[0]
                    h_line.start_point = (x_position, h_line.start_point[1])
                else:
                    x_position = h_line.start_point[0]
                    neighbor_line.start_point = (x_position, neighbor_line.start_point[1])
                neighbor_line.connect_at_start_point = True
                h_line.connect_at_start_point = True

                virtual_v_line = Line((x_position, h_line.start_point[1]), (x_position, neighbor_line.start_point[1]), 0, 'v')
                virtual_v_line.virtual_line = True
                virtual_v_line.connect_at_start_point = True
                virtual_v_line.connect_at_end_point = True

                return virtual_v_line

        elif direction == "end":
            if neighbor_line.connect_at_end_point:
                virtual_v_line = Line(h_line.end_point, (h_line.end_point[0], neighbor_line.end_point[1]), 0, 'v')
                virtual_v_line.virtual_line = True
                virtual_v_line.connect_at_start_point = True
                virtual_v_line.connect_at_end_point = True
                h_line.connect_at_end_point = True
                return virtual_v_line
            else:
                x_position = 0
                if h_line.end_point[0] > neighbor_line.end_point[0]:
                    x_position = h_line.end_point[0]
                    neighbor_line.end_point = (x_position, neighbor_line.end_point[1])
                else:
                    x_position = neighbor_line.end_point[0]
                    h_line.end_point = (x_position, h_line.end_point[1])
                neighbor_line.connect_at_end_point = True
                h_line.connect_at_end_point = True

                virtual_v_line = Line((x_position, h_line.end_point[1]), (x_position, neighbor_line.end_point[1]), 0, 'v')
                virtual_v_line.virtual_line = True
                virtual_v_line.connect_at_start_point = True
                virtual_v_line.connect_at_end_point = True

                return virtual_v_line

    @staticmethod
    def create_virtual_horizontal_line(v_line, neighbor_line, direction="start"):
        from .table_processing import Line

        if direction == "start":
            if neighbor_line.connect_at_start_point:
                virtual_h_line = Line(v_line.start_point, (neighbor_line.start_point[0], v_line.start_point[1]), 0, 'h')
                virtual_h_line.virtual_line = True
                virtual_h_line.connect_at_start_point = True
                virtual_h_line.connect_at_end_point = True
                v_line.connect_at_start_point = True
                return virtual_h_line
            else:
                y_position = 0
                if v_line.start_point[1] > neighbor_line.start_point[1]:
                    y_position = neighbor_line.start_point[1]
                    v_line.start_point = (v_line.start_point[0], y_position)
                else:
                    y_position = v_line.start_point[1]
                    neighbor_line.start_point = (neighbor_line.start_point[0], y_position)
                neighbor_line.connect_at_start_point = True
                v_line.connect_at_start_point = True

                virtual_h_line = Line((v_line.start_point[0], y_position), (neighbor_line.start_point[0], y_position), 0, 'h')
                virtual_h_line.virtual_line = True
                virtual_h_line.connect_at_start_point = True
                virtual_h_line.connect_at_end_point = True

                return virtual_h_line

        elif direction == "end":
            if neighbor_line.connect_at_end_point:
                virtual_h_line = Line(v_line.end_point, (neighbor_line.end_point[0], v_line.end_point[1]), 0, 'h')
                virtual_h_line.virtual_line = True
                virtual_h_line.connect_at_start_point = True
                virtual_h_line.connect_at_end_point = True
                v_line.connect_at_end_point = True
                return virtual_h_line
            else:
                y_position = 0
                if v_line.end_point[1] > neighbor_line.end_point[1]:
                    y_position = v_line.end_point[1]
                    neighbor_line.end_point = (neighbor_line.end_point[0], y_position)
                else:
                    y_position = neighbor_line.end_point[1]
                    v_line.end_point = (v_line.end_point[0], y_position)

                neighbor_line.connect_at_end_point = True
                v_line.connect_at_end_point = True

                virtual_h_line = Line((v_line.end_point[0], y_position), (neighbor_line.end_point[0], y_position), 0, 'h')
                virtual_h_line.virtual_line = True
                virtual_h_line.connect_at_start_point = True
                virtual_h_line.connect_at_end_point = True

                return virtual_h_line

    @staticmethod
    def vertical_left_neighbor_line(v_line, v_lines, invalid_lines=None):
        left_lines = []
        for line in v_lines:
            if line!=v_line and line.start_point[0] < v_line.start_point[0]:
                if invalid_lines and line not in invalid_lines:
                    left_lines.append(line)
                elif not invalid_lines:
                    left_lines.append(line)

        if len(left_lines) > 0:
            return left_lines[-1]
        else:
            return None

    @staticmethod
    def vertical_right_neighbor_line(v_line, v_lines, invalid_lines=None):
        right_lines = []
        for line in v_lines:
            if line!=v_line and line.start_point[0] > v_line.start_point[0]:
                if invalid_lines and line not in invalid_lines:
                    right_lines.append(line)
                elif not invalid_lines:
                    right_lines.append(line)

        if len(right_lines) > 0:
            return right_lines[0]
        else:
            return None

    @staticmethod
    def vertical_neighbor_line(v_line, v_lines):
        left_lines = []
        right_lines = []

        for line in v_lines:
            if line.start_point[0] < v_line.start_point[0]:
                left_lines.append(line)
            elif line.start_point[0] > v_line.start_point[0]:
                right_lines.append(line)

        if len(left_lines) > 0 and len(right_lines) == 0:
            return left_lines[-1]
        elif len(left_lines) == 0 and len(right_lines) > 0:
            return right_lines[0]
        elif len(left_lines) > 0 and len(right_lines) > 0:
            if left_lines[0].connect_at_start_and_end_point() and not right_lines[-1].connect_at_start_and_end_point():
                return right_lines[-1]
            if not left_lines[0].connect_at_start_and_end_point() and right_lines[-1].connect_at_start_and_end_point():
                return left_lines[0]
            if not v_line.connect_at_start_point:
                return left_lines[0] if left_lines[0].end_point[1] < right_lines[-1].end_point[1] else right_lines[-1]
            if not v_line.connect_at_end_point:
                return left_lines[0] if left_lines[0].end_point[1] > right_lines[-1].end_point[1] else right_lines[-1]
        else:
            return None

    @staticmethod
    def horizontal_top_neighbor_line(h_line, h_lines, invalid_lines=None):
        top_lines = []
        for line in h_lines:
            if line!=h_line and line.start_point[1] < h_line.start_point[1]:
                if invalid_lines and line not in invalid_lines:
                    top_lines.append(line)
                elif not invalid_lines:
                    top_lines.append(line)

        if len(top_lines) > 0:
            return top_lines[-1]
        else:
            return None

    @staticmethod
    def horizontal_bottom_neighbor_line(h_line, h_lines, invalid_lines=None):
        bottom_lines = []
        for line in h_lines:
            if line!=h_line and line.start_point[1] > h_line.start_point[1]:
                if invalid_lines and line not in invalid_lines:
                    bottom_lines.append(line)
                elif not invalid_lines:
                    bottom_lines.append(line)

        if len(bottom_lines) > 0:
            return bottom_lines[0]
        else:
            return None

    @staticmethod
    def horizontal_neighbor_line(h_line, h_lines):
        """
        :param h_line:
        :param h_lines:
        :return: try to find neighbor horizontal line of input line.
                The neighbor line is nearest line and does not connect to any others lines
        """
        top_lines = []
        bottom_lines = []

        for line in h_lines:
            if line.start_point[1] < h_line.start_point[1]:
                top_lines.append(line)
            elif line.start_point[1] > h_line.start_point[1]:
                bottom_lines.append(line)

        if len(top_lines) > 0 and len(bottom_lines) == 0:
            return top_lines[-1]
        elif len(top_lines) == 0 and len(bottom_lines) > 0:
            return bottom_lines[0]
        elif len(top_lines) > 0 and len(bottom_lines) > 0:
            if bottom_lines[0].connect_at_start_and_end_point() and not top_lines[-1].connect_at_start_and_end_point():
                return top_lines[-1]
            if not bottom_lines[0].connect_at_start_and_end_point() and top_lines[-1].connect_at_start_and_end_point():
                return bottom_lines[0]
            if not h_line.connect_at_start_point:
                return bottom_lines[0] if bottom_lines[0].end_point[0] < top_lines[-1].end_point[0] else top_lines[-1]
            if not h_line.connect_at_end_point:
                return bottom_lines[0] if bottom_lines[0].end_point[0] > top_lines[-1].end_point[0] else top_lines[-1]
        else:
            return None

    @staticmethod
    def is_line_cut_rects(line, rects, orientation='v', threshold=-2):
        for rect in rects:
            rect = Utils.expand_rect(rect, threshold)
            rect_line = Utils.convert_line_to_box(line, threshold=2, orientation=orientation)
            if Utils.rect_overlap_rect(rect_line, rect):
                return True

        return False


    @staticmethod
    def vertical_stop_line(h_line, v_lines, content_rects, threshold=5):

        left_stop_line = None
        right_stop_line = None
        invalid_horizontal_line = False

        left_lines = []
        right_lines = []
        for v_line in v_lines:
            if Utils.horizontal_line_cut_vertical_line(h_line, v_line):
                # Find the left stop line if horizontal line is not connected at start point
                if not h_line.connect_at_start_point and v_line.start_point[0] < h_line.start_point[0]:
                    left_lines.append(v_line)

                # Find the right stop line if horizontal line is not connected at end point
                if not h_line.connect_at_end_point and v_line.start_point[0] > h_line.end_point[0]:
                    right_lines.append(v_line)

        if len(left_lines) > 0:
            left_stop_line = left_lines[-1]

        if len(right_lines) > 0:
            right_stop_line = right_lines[0]

        # Make sure the expanding not cut any content blocks. In case the line cut a content blocks, stop it.
        for content_rect in content_rects:
            if left_stop_line is not None:
                if left_stop_line.start_point[0] <= content_rect[0] and content_rect[0] + content_rect[2] <= h_line.start_point[0] \
                    and content_rect[1] + threshold <= h_line.start_point[1] <= content_rect[1] + content_rect[3] - threshold:
                        left_stop_line = None
                        invalid_horizontal_line = True
                        h_line.connect_at_start_point = True

            if right_stop_line is not None:
                if h_line.end_point[0] <= content_rect[0] and content_rect[0] + content_rect[2] <= right_stop_line.end_point[0] \
                    and content_rect[1] + threshold <= h_line.end_point[1] <= content_rect[1] + content_rect[3] - threshold:
                        right_stop_line = None
                        invalid_horizontal_line = True
                        h_line.connect_at_end_point = True

        return left_stop_line, right_stop_line, invalid_horizontal_line

    @staticmethod
    def horizontal_stop_line(v_line, h_lines, content_rects, threshold=5):
        top_stop_line = None
        bottom_stop_line = None
        invalid_vertical_line = False

        top_lines = []
        bottom_lines = []
        for h_line in h_lines:
            if Utils.vertical_line_cut_horiontal_line(v_line, h_line):
                # Find the top stop line if vertical line is not connected at start point
                if not v_line.connect_at_start_point and v_line.start_point[1] > h_line.start_point[1]:
                    top_lines.append(h_line)

                # Find the bottom stop line if vertical line is not connected at end point
                if not v_line.connect_at_end_point and v_line.end_point[1] < h_line.start_point[1]:
                    bottom_lines.append(h_line)

        if len(top_lines) > 0:
            top_stop_line = top_lines[-1]

        if len(bottom_lines) > 0:
            bottom_stop_line = bottom_lines[0]

        # Make sure the expanding not cut any content blocks. In case the line cut a content blocks, stop it.
        for content_rect in content_rects:
            if top_stop_line is not None:
                if top_stop_line.start_point[1] <= content_rect[1] and content_rect[1] + content_rect[3] <= v_line.start_point[1] \
                    and content_rect[0] + threshold <= v_line.start_point[0] <= content_rect[0] + content_rect[2] - threshold:
                        top_stop_line = None
                        v_line.connect_at_start_point = True
                        invalid_vertical_line = True

            if bottom_stop_line is not None:
                if v_line.end_point[1] <= content_rect[1] and content_rect[1] + content_rect[3] <= bottom_stop_line.end_point[1] \
                    and content_rect[0] + threshold <= v_line.end_point[0] <= content_rect[0] + content_rect[2] - threshold:
                        bottom_stop_line = None
                        v_line.connect_at_end_point = True
                        invalid_vertical_line = True

        return top_stop_line, bottom_stop_line, invalid_vertical_line

    @staticmethod
    def line_pairs(h_single_lines, v_single_lines, distance_threshold=20, ratio_threshold=0.1):
        """
        :param h_single_lines: the list of horizontal lines
        :param v_single_lines: the list of vertical lines
        :param distance_threshold: deviation between start point of the line
        :param ratio_threshold: ratio of the length of the line
        :return: these pair lines.
                -------------

                                -----> this is horizontal pair line

                -------------

                or

                |             |
                |             |
                |             | -----> this is vertical pair line
                |             |
                |             |
        """
        h_line_pairs = []
        v_line_pairs = []

        for line_pair in itertools.combinations(h_single_lines, r=2):
            a_line, b_line = line_pair
            if abs(a_line.start_point[0] - b_line.start_point[0]) <= distance_threshold and abs(a_line.length() / b_line.length() - 1) <= ratio_threshold:
                if a_line.start_point[1] < b_line.start_point[1]:
                    h_line_pairs.append((a_line, b_line))
                else:
                    h_line_pairs.append((b_line, a_line))

        for line_pair in itertools.combinations(v_single_lines, r=2):
            a_line, b_line = line_pair
            if abs(a_line.start_point[1] - b_line.start_point[1]) <= distance_threshold and abs(a_line.length() / b_line.length() - 1) <= ratio_threshold:
                v_line_pairs.append((a_line, b_line))
                if a_line.start_point[0] < b_line.start_point[0]:
                    v_line_pairs.append((a_line, b_line))
                else:
                    v_line_pairs.append((b_line, a_line))

        return h_line_pairs, v_line_pairs

    @staticmethod
    def connect_at_corner(h_line, v_line, threshold=60):
        return Utils.distance_from_point_to_point(h_line.start_point, v_line.start_point) <= threshold \
                or Utils.distance_from_point_to_point(h_line.start_point, v_line.end_point) <= threshold \
                or Utils.distance_from_point_to_point(h_line.end_point, v_line.start_point) <= threshold \
                or Utils.distance_from_point_to_point(h_line.end_point, v_line.end_point) <= threshold

    @staticmethod
    def stop_point_at_top(table, point):
        """Find the stop point for divider line at the top
        If the divider line cut a column, the stop point will be the point with the neast table horizontal line,
        otherwise the stop point will be at the table top border
        """
        threshold = 5
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        content_rects.sort(key=lambda rect: rect[1] + rect[3], reverse=True)
        for rect in content_rects:
            # In case the divider line is blocked by a column content
            if rect[0] + threshold <= point[0] <= rect[0] + rect[2] - threshold and rect[1] + rect[3] - threshold <= point[1]:
                # Loop all table hozirontal lines to find nearest horizontal line at top
                h_lines = [h_line for h_line in table.horizontal_lines if h_line.start_point[1] > rect[1]]
                h_lines = sorted(h_lines, key=lambda line: line.start_point[1]).copy()

                # Create a temp line list to keep all lines above/below point (Y postion)
                upper_lines = []
                lower_lines = []
                for line in h_lines:
                    if line.start_point[1] < point[1]:
                        upper_lines.append(line)
                    else:
                        lower_lines.append(line)

                if len(upper_lines) > 0:
                    lines = sorted(upper_lines, key=lambda line: line.start_point[1])
                    top_point = (point[0], lines[0].start_point[1])
                    if Utils.is_point_in_line(top_point, lines[0]):
                        return top_point
                    else:
                        return None
                
                if len(lower_lines) > 0:
                    lines = sorted(lower_lines, key=lambda line: line.start_point[1])
                    top_point = (point[0], lines[0].start_point[1])
                    if Utils.is_point_in_line(top_point, lines[0]):
                        return top_point
                    else:
                        return None

                # do not have stop point
                return None

        # In case no block lines, just connect to the top border
        return (point[0], table.top_border.start_point[1])

    @staticmethod
    def stop_point_at_bottom(table, point):
        """Find the stop point for divider line at the bottom
        If the divider line cut a column, the stop point will be the point with the neast table horizontal line,
        otherwise the stop point will be at the table bottom border
        """
        threshold = 5
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        content_rects.sort(key=lambda rect: rect[1])

        for rect in content_rects:
            # In case the divider line is blocked by a column content
            if rect[0] + threshold <= point[0] <= rect[0] + rect[2] - threshold and point[1] <= rect[1] + threshold:
                # Loop all table hozirontal lines to find nearest horizontal line at top
                h_lines = [h_line for h_line in table.horizontal_lines if h_line.start_point[1] < rect[1] + rect[3]]
                h_lines = sorted(h_lines, key=lambda line: line.start_point[1]).copy()
                # Create a temp line list to keep all lines above point (Y postion)
                upper_lines = []
                lower_lines = []
                for line in h_lines:
                    if line.start_point[1] < point[1]:
                        upper_lines.append(line)
                    else:
                        lower_lines.append(line)

                if len(lower_lines) > 0:
                    lines = sorted(lower_lines, key=lambda line: line.start_point[1])
                    bottom_point = (point[0], lines[-1].start_point[1])
                    if Utils.is_point_in_line(bottom_point, lines[-1]):
                        return bottom_point
                    else:
                        return None

                if len(upper_lines) > 0:
                    lines = sorted(upper_lines, key=lambda line: line.start_point[1])
                    bottom_point = (point[0], lines[-1].start_point[1])
                    if Utils.is_point_in_line(bottom_point, lines[-1]):
                        return bottom_point
                    else:
                        return None

                return None

        # In case no block lines, just connect to the bottom border
        return (point[0], table.bottom_border.start_point[1])

    @staticmethod
    def stop_point_at_left(table, point):
        """Find the stop point for divider line at the left
        If the divider line cut a row, the stop point will be the point with the neast table vertical line,
        otherwise the stop point will be at the table left border
        """
        threshold = 5
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        content_rects.sort(key=lambda rect: rect[0] + rect[2], reverse=True)
        for rect in content_rects:
            # In case the divider line is blocked by a row content
            if rect[1] + threshold <= point[1] <= rect[1] + rect[3] - threshold and rect[0] + rect[2] - threshold <= point[0]:
                # Loop all table vertical lines to find nearest vertical line at left
                v_lines = [v_line for v_line in table.vertical_lines if v_line.start_point[0] > rect[0] + rect[2]]
                v_lines.sort(key=lambda line: line.start_point[0])
                # Create a temp line list to keep all lines above point (X postion)
                left_lines = []
                right_lines = []
                for line in v_lines:
                    if line.start_point[0] < point[0]:
                        left_lines.append(line)
                    else:
                        right_lines.append(line)

                if len(left_lines) > 0:
                    left_lines.sort(key=lambda line: line.start_point[0])
                    left_point = (left_lines[0].start_point[0], point[1])
                    if Utils.is_point_in_line(left_point, left_lines[0]):
                        return left_point
                    else:
                        return None
                if len(right_lines) > 0:
                    right_lines.sort(key=lambda line: line.start_point[0])
                    right_point = (right_lines[0].start_point[0], point[1])
                    if Utils.is_point_in_line(right_point, right_lines[0]):
                        return right_point
                    else:
                        return None

                return None

        # In case no block lines, just connect to the left border
        return (table.left_border.start_point[0], point[1])

    @staticmethod
    def stop_point_at_right(table, point):
        """Find the stop point for divider line at the right
        If the divider line cut a row, the stop point will be the point with the neast table vertical line,
        otherwise the stop point will be at the table right border
        """
        threshold = 5
        content_rects = [content_block.bounding_rect for content_block in table.content_blocks]
        content_rects.sort(key=lambda rect: rect[0])
        for rect in content_rects:
            # In case the divider line is blocked by a row content
            if rect[1] + threshold <= point[1] <= rect[1] + rect[3] - threshold and rect[0] + threshold >= point[0]:
                # Loop all table vertical lines to find nearest vertical line at left
                v_lines = [v_line for v_line in table.vertical_lines if v_line.start_point[0] < rect[0]]
                v_lines.sort(key=lambda line: line.start_point[0])
                # Create a temp line list to keep all lines above point (X postion)
                left_lines = []
                right_lines = []
                for line in v_lines:
                    if line.start_point[0] < point[0]:
                        left_lines.append(line)
                    else:
                        right_lines.append(line)

                if len(right_lines) > 0:
                    right_lines.sort(key=lambda line: line.start_point[0])
                    right_point = (right_lines[-1].start_point[0], point[1])
                    if Utils.is_point_in_line(right_point, right_lines[-1]):
                        return right_point
                    else:
                        return None

                if len(left_lines) > 0:
                    left_lines.sort(key=lambda line: line.start_point[0])
                    left_point = (left_lines[-1].start_point[0], point[1])
                    if Utils.is_point_in_line(left_point, left_lines[-1]):
                        return left_point
                    else:
                        return None

                return None

        # In case no block lines, just connect to the left border
        return (table.right_border.start_point[0], point[1])

    @staticmethod
    def single_text_blocks(boxes, text_blocks, expand=0):
        """Find all single text blocks (text block not in a box)
        """
        single_text_blocks = []
        for box in boxes:
            box = Utils.expand_rect(box, expand)
            for text_block in text_blocks:
                if Utils.rect_inside_rect(box, text_block):
                    single_text_blocks.append(text_block)
        return list(set(text_blocks)-set(single_text_blocks))

    @staticmethod
    def single_lines(boxes, lines):
        """Find all single lines (line not in a box)
        """
        box_lines = []
        for box in boxes:
            for line in lines:
                if Utils.line_inside_box(box, line, 0):
                    box_lines.append(line)
        return list(set(lines) - set(box_lines))

    @staticmethod
    def lines_inside_box(box, lines, threshold=5, return_lines=False):
        inside_lines = [line for line in lines if Utils.line_inside_box(box, line, threshold)]
        if return_lines:
            return inside_lines
        else:
            return True if inside_lines else False

    @staticmethod
    def line_inside_box(box, line, threshold=5):
        """
        :param box: the box's position
        :param line:
        :param threshold: the line insides a box with error number, which is this parameter
        :return: True: if the line insides the box
                 False: Otherwise
        """
        box_x, box_y, box_w, box_h = box
        return line.start_point[0] >= box_x - threshold and line.end_point[0] <= box_x + box_w + threshold \
                and line.start_point[1] >= box_y - threshold and line.end_point[1] <= box_y + box_h + threshold

    @staticmethod
    def v_line_inside_box(box, line, threshold=5):
        box = Utils.expand_height_rect(box, threshold)
        box = Utils.expand_width_rect(box, -threshold)
        return Utils.line_inside_box(box, line, 0)

    @staticmethod
    def h_line_inside_box(box, line, threshold=5):
        box = Utils.expand_height_rect(box, -threshold)
        box = Utils.expand_width_rect(box, threshold)
        return Utils.line_inside_box(box, line, 0)

    @staticmethod
    def expand_rect(rect, expand):
        """
        :return: add padding to the rect
        """
        return rect[0] - expand, rect[1] - expand, rect[2] + 2 * expand, rect[3] + 2 * expand

    @staticmethod
    def expand_width_rect(rect, expand):
        """
        :return: add horizontal padding to the rect only.
        """
        return rect[0] - expand, rect[1], rect[2] + 2 * expand, rect[3]

    @staticmethod
    def expand_height_rect(rect, expand):
        """
        :return: add vertical padding to the rect only
        """
        return rect[0], rect[1] - expand, rect[2], rect[3] + 2 * expand

    @staticmethod
    def line_inside_table_box(rect, line, expand):
        if line.orientation == 'h':
            rect = Utils.expand_width_rect(rect, expand)
            return Utils.line_inside_box(rect, line, 0)
        else:
            rect = Utils.expand_height_rect(rect, expand)
            return Utils.line_inside_box(rect, line, 0)

    @staticmethod
    def rect_inside_rect(a_rect, b_rect, expand=0):
        """Check if b_rect inside a_rect
        """
        a_x, a_y, a_w, a_h = Utils.expand_rect(a_rect, expand)
        b_x, b_y, b_w, b_h = b_rect
        return b_x - a_x >= 0 and b_y - a_y >= 0 and (a_x + a_w) - (b_x + b_w) >= 0 and (a_y + a_h) - (b_y + b_h) >= 0

    @staticmethod
    def rect_horizontal_inside_rect(a_rect, b_rect, expand=0):
        """Check if b_rect horizontaly inside a_rect
        """
        a_x, _, a_w, _ = Utils.expand_rect(a_rect, expand)
        b_x, _, b_w, _ = b_rect
        return b_x - a_x >= 0 and (a_x + a_w) - (b_x + b_w) >= 0

    @staticmethod
    def rect_vertical_inside_rect(a_rect, b_rect, expand=0):
        """Check if b_rect verticaly inside a_rect
        """
        _, a_y, _, a_h = Utils.expand_rect(a_rect, expand)
        _, b_y, _, b_h = b_rect
        return b_y - a_y >= 0 and (a_y + a_h) - (b_y + b_h) >= 0

    @staticmethod
    def is_rect_contains_rects(a_rect, rects, reverse=False):
        for rect in rects:
            if not reverse and Utils.rect_inside_rect(a_rect, rect):
                return True
            elif reverse and Utils.rect_inside_rect(rect, a_rect):
                return True
        return False

    @staticmethod
    def get_rect_contains_rects(a_rect, rects, reverse=False):
        ret_rects = []
        for rect in rects:
            if not reverse and Utils.rect_inside_rect(a_rect, rect):
                ret_rects.append(rect)
            elif reverse and Utils.rect_inside_rect(rect, a_rect):
                ret_rects.append(rect)
        return ret_rects

    @staticmethod
    def get_rect_contains_blocks(a_rect, blocks, reverse=False):
        rects = [block.bounding_rect for block in blocks]
        ret_blocks = []
        for i, rect in enumerate(rects):
            if not reverse and Utils.rect_inside_rect(a_rect, rect):
                ret_blocks.append(blocks[i])
            elif reverse and Utils.rect_inside_rect(rect, a_rect):
                ret_blocks.append(blocks[i])
        return ret_blocks


    @staticmethod
    def lines_over_line(line, lines, direction="left"):
        """
        Get lines over line
        """
        over_lines = []

        if direction=="top":
            over_f = lambda a_line, b_line:a_line.start_point[1]<=b_line.start_point[1] and a_line.end_point[1]<=b_line.end_point[1]
        elif direction=="bottom":
            over_f = lambda a_line, b_line:a_line.start_point[1]>=b_line.start_point[1] and a_line.end_point[1]>=b_line.end_point[1]
        elif direction=="left":
            over_f = lambda a_line, b_line:a_line.start_point[0]<=b_line.start_point[0] and a_line.end_point[0]<=b_line.end_point[0]
        elif direction=="right":
            over_f = lambda a_line, b_line:a_line.start_point[0]>=b_line.start_point[0] and a_line.end_point[0]>=b_line.end_point[0]
        else:
            return over_lines

        for other_line in lines:
            if line!=other_line and over_f(other_line, line):
                over_lines.append(other_line)
        return over_lines

    @staticmethod
    def line_inside_text_block(text_block, line, expand=0):
        """
        :param text_block: the text block's position
        :param line: the line's position
        :param expand: maximum text_block is added more padding
        :return: whether or not line is inside text block
        """
        # padding rect. it's depend on
        def expand_with_horizontal_line(rect, expand):
            """
            :return: add more padding for text block to check horizontal line
            """
            return rect[0] - expand / 2, rect[1] - expand / 2, rect[2] + expand, rect[3] + expand

        def expand_with_vertical_line(rect, expand):
            """
            :return: add more padding for text block to check vertical line
            """
            return rect[0] - expand / 3, rect[1] - expand, rect[2] + 2 * expand / 3, rect[3] + 2 * expand

        b_x, b_y, b_w, b_h = line
        if b_w > b_h:
            a_x, a_y, a_w, a_h = expand_with_horizontal_line(text_block, expand)
        else:
            a_x, a_y, a_w, a_h = expand_with_vertical_line(text_block, expand)

        return b_x - a_x >= 0 and b_y - a_y >= 0 and (a_x + a_w) - (b_x + b_w) >= 0 and (a_y + a_h) - (b_y + b_h) >= 0

    @staticmethod
    def rect_overlap_rect(a_rect, b_rect):
        """Check if two rectangles are overlapping
        """
        # a_x, a_y, a_w, a_h = a_rect
        # b_x, b_y, b_w, b_h = b_rect
        x = max(a_rect[0], b_rect[0])
        y = max(a_rect[1], b_rect[1])
        w = min(a_rect[0] + a_rect[2], b_rect[0] + b_rect[2]) - x
        h = min(a_rect[1] + a_rect[3], b_rect[1] + b_rect[3]) - y
        if w < 0 or h < 0:
            return False
        return True

    @staticmethod
    def rect_horizontal_overlap_rect(a_rect, b_rect, thresh=0, inside_box=False):
        """Check if two rectangles are horizontal overlapping
        """
        max_h_rect = max(a_rect, b_rect, key=lambda rect:rect[3])
        min_h_rect = min(a_rect, b_rect, key=lambda rect:rect[3])
        x          = max(a_rect[0], b_rect[0])
        w          = min(a_rect[0] + a_rect[2], b_rect[0] + b_rect[2]) - x
        if inside_box:
            if w < thresh or not Utils.rect_vertical_inside_rect(max_h_rect, min_h_rect): #14814
                return False
            return True
        else:
            if w < thresh:
                return False
            return True

    @staticmethod
    def rect_vertical_overlap_rect(a_rect, b_rect, thresh=0, inside_box=False):
        """Check if two rectangles are vertical overlapping
        """
        max_w_rect = max(a_rect, b_rect, key=lambda rect:rect[2])
        min_w_rect = min(a_rect, b_rect, key=lambda rect:rect[2])
        y = max(a_rect[1], b_rect[1])
        h = min(a_rect[1] + a_rect[3], b_rect[1] + b_rect[3]) - y
        if inside_box:
            if h < thresh or not Utils.rect_horizontal_inside_rect(max_w_rect, min_w_rect): #14814
                return False
            return True
        else:
            if h < thresh:
                return False
            return True

    @staticmethod
    def line_overlap_rects(line, rects, orientation, percent=50, shrink_size=0): #12585
        """Check line overlap rect
        """
        line_overlap_box_f = Utils.h_line_overlap_rect if orientation=="h" else Utils.v_line_overlap_rect
        for rect in rects:
            rect = Utils.expand_rect(rect, shrink_size)
            if line_overlap_box_f(line, rect, percent):
                return True
        return False

    @staticmethod
    def is_rect_divide_content(bounding_rect, content_blocks, expand_size=10, overlap_percent=30, cnt=3): #13993->#14560(cnt)
        """ 
        Check rect divide horizontally content

        :param bounding_rect:
        :param content_blocks:
        :return: True if divide, otherwise False
        """
        OVERLAP_SIZE = expand_size
        cnt = cnt #14560
        for content_block in content_blocks:
            content_rect = content_block.bounding_rect
            if not Utils.rect_inside_rect(bounding_rect, content_rect, expand=expand_size) and \
               Utils.rect_overlap_rect_with_percent(bounding_rect, content_rect, threshold=overlap_percent, min_rect=True) and \
               Utils.rect_horizontal_overlap_rect(bounding_rect, content_rect, thresh=OVERLAP_SIZE) and \
               Utils.rect_vertical_overlap_rect(bounding_rect, content_rect, thresh=OVERLAP_SIZE): #14560
                cnt -= 1
                if cnt<=0:
                    return True
        return False

    @staticmethod
    def is_rect_divide_text_boxes(bounding_rect, text_boxes, expand_size=10, overlap_percent=30, cnt=3): #13993->#14560(cnt)
        """ 
        Check rect divide horizontally text boxes

        :param bounding_rect:
        :param text_boxes: => [[x,y,w,h], ...]
        :return: True if divide, otherwise False
        """
        OVERLAP_SIZE = expand_size
        cnt = cnt #14560
        for text_box in text_boxes:
            if not Utils.rect_inside_rect(bounding_rect, text_box, expand=expand_size) and \
               Utils.rect_overlap_rect_with_percent(bounding_rect, text_box, threshold=overlap_percent, min_rect=True) and \
               Utils.rect_horizontal_overlap_rect(bounding_rect, text_box, thresh=OVERLAP_SIZE) and \
               Utils.rect_vertical_overlap_rect(bounding_rect, text_box, thresh=OVERLAP_SIZE): #14560
                cnt -= 1
                if cnt<=0:
                    return True
        return False

    @staticmethod
    def h_line_overlap_rect(line, rect, percent=50): #12585
        """
        v_line overlap rect
        
        :param line:
        :param rect:
        :param percent: degree of overlap
        :return: True if overlaped else False

        ---------             ---------               ---------           
        |       |             |       |               |       |           
      *-----------* => True   |       |   => False  ------*   | => True or False (depend on degree of overlap)
        |       |             |       |               |       |           
        ---------           *-----------*             ---------         
        """
        line_start_x, line_start_y = line.start_point
        line_end_x,   line_end_y   = line.end_point
        line_start_x, line_end_x   = min(line_start_x, line_end_x), max(line_start_x, line_end_x)
        line_start_y, line_end_y   = min(line_start_y, line_end_y), max(line_start_y, line_end_y)
        rect_start_x, rect_end_x   = rect[0], rect[0]+rect[2]
        rect_start_y, rect_end_y   = rect[1], rect[1]+rect[3]
        rect_w                     = rect[2]+1 if rect[2]==0 else rect[2]
        rect_h                     = rect[3]+1 if rect[3]==0 else rect[3]

        if rect_start_y<line_start_y<rect_end_y and rect_start_y<line_end_y<rect_end_y: # line y inside rect y
            if (line_start_x<=rect_end_x and line_end_x>=rect_start_x and
                (rect_end_x-line_start_x)*100/rect_w>percent and (line_end_x-rect_start_x)*100/rect_w>percent): # line overlap rect by percent
                return True
        return False

    @staticmethod
    def v_line_overlap_rect(line, rect, percent=50): #12585
        """
        v_line overlap rect
        
        :param line:
        :param rect:
        :param percent: degree of overlap
        :return: True if overlaped else False

            *                       *                 |             
        ----|----           --------|             ----|----         
        |   |   |           |       |             |   |   |         
        |   |   | => True   |       | => False    |   *   | => True or False (depend on degree of overlap)
        |   |   |           |       |             |       |         
        ----|----           --------|             ---------         
            *                       *                              
        """
        line_start_x, line_start_y = line.start_point
        line_end_x,   line_end_y   = line.end_point
        line_start_x, line_end_x   = min(line_start_x, line_end_x), max(line_start_x, line_end_x)
        line_start_y, line_end_y   = min(line_start_y, line_end_y), max(line_start_y, line_end_y)
        rect_start_x, rect_end_x   = rect[0], rect[0]+rect[2]
        rect_start_y, rect_end_y   = rect[1], rect[1]+rect[3]
        rect_w                     = rect[2]+1 if rect[2]==0 else rect[2]
        rect_h                     = rect[3]+1 if rect[3]==0 else rect[3]

        if rect_start_x<line_start_x<rect_end_x and rect_start_x<line_end_x<rect_end_x: # line x inside rect x
            if (line_start_y<=rect_end_y and line_end_y>=rect_start_y and
                (rect_end_y-line_start_y)*100/rect_h>percent and (line_end_y-rect_start_y)*100/rect_h>percent): # line overlap rect by percent
                return True
        return False

    @staticmethod
    def rect_overlap_two_rects(a_rect, b_rect):
        """Get rect overlap two rects
        """
        if Utils.rect_overlap_rect(a_rect, b_rect):
            x = max(a_rect[0], b_rect[0])
            y = max(a_rect[1], b_rect[1])
            return x, y, min(a_rect[0]+a_rect[2], b_rect[0]+b_rect[2])-x, min(a_rect[1]+a_rect[3], b_rect[1]+b_rect[3])-y
        else:
            return None

    @staticmethod
    def line_overlap_line(a_line, b_line, orientation, threshold=10):
        """Check if two lines near enought both vertical and horizontal
        """
        if orientation == "h":
            if abs(a_line.start_point[1] - b_line.start_point[1]) > threshold:
                return False

            lines = sorted([a_line, b_line], key=lambda line: line.start_point[0])

            return lines[0].end_point[0] + threshold > lines[1].start_point[0]
        else:
            if abs(a_line.start_point[0] - b_line.start_point[0]) > threshold:
                return False

            lines = sorted([a_line, b_line], key=lambda line: line.start_point[1])

            return lines[0].end_point[1] + threshold > lines[1].start_point[1]

    @staticmethod
    def bounding_rect(rects):
        """Get the biggest rect contains all rects
        """
        points = []
        for rect in rects:
            x, y, w, h = rect
            points.append((x, y))
            points.append((x + w, y + h))
        return cv2.boundingRect(np.array(points, np.float32))

    @staticmethod
    def bounding_rect_lines(rect, lines):
        """Get the biggest rect contains rect and all lines
        """
        points = []
        if rect is not None:
            x, y, w, h = rect
            points.append((x, y))
            points.append((x + w, y + h))
            
        for line in lines:
            points.append(line.start_point)
            points.append(line.end_point)

        return cv2.boundingRect(np.array(points, np.float32))

    @staticmethod
    def bounding_lines_virtual_line_real_line(virtual_line, real_line, orientation='v'):
        points = []
        points.append(virtual_line.start_point)
        points.append(virtual_line.end_point)
        if orientation == 'v':
            points.append((real_line.start_point[0], virtual_line.start_point[1]))
            points.append((real_line.end_point[0], virtual_line.end_point[1]))
        else:
            points.append((virtual_line.start_point[0], real_line.start_point[1]))
            points.append((virtual_line.end_point[0], real_line.end_point[1]))

        return cv2.boundingRect(np.array(points, np.float32))


    @staticmethod
    def external_rects(image_size, rects):
        """Group overlapping boxes and return all external rects
        """
        # Create a empty image with the input size
        blank_image = np.zeros((image_size[0], image_size[1], 1), np.uint8)

        # Draw all rects
        Utils.fill_boxes(blank_image, rects, (255, 255, 255))

        # Fill all external rects
        contours = cv2.findContours(blank_image.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[1]

        return [cv2.boundingRect(c) for c in contours]

    @staticmethod
    def outside_rects(rects):
        """Get outside rects
        """
        def max_sort_f(rect):
            return rect[2]*rect[3]

        rects         = sorted(rects, key=max_sort_f, reverse=True)
        outside_boxes = []
        for i, src_rect in enumerate(rects):
            for dst_rect in rects[:i]:
                if Utils.rect_inside_rect(src_rect, dst_rect):
                    break
            else:
                outside_boxes.append(src_rect)
        return outside_boxes

    @staticmethod
    def convert_box_to_line(box):
        from table_extraction.line import Line
        x, y, w, h = box
        if w > h:
            width = h
            orientation = "h"
            start_point = (x, y + int(h / 2))
            end_point = (x + w, y + int(h / 2))
        else:
            width = w
            orientation = "v"
            start_point = (x + int(w / 2), y)
            end_point = (x + int(w / 2), y + h)
        return Line(start_point, end_point, width, orientation)

    @staticmethod
    def convert_line_to_box(line, threshold=1, orientation='v'):
        x1, y1 = line.start_point
        x2, y2 = line.end_point
        if orientation == 'h':
            return (x1, y1 - threshold, x2 - x1, 2 * threshold)
        else:
            return (x1 - threshold, y1, 2 * threshold, y2 - y1)

    @staticmethod
    def fill_rects(image, color=(255, 255, 255)):
        """Fill all rects in the input image with the color
        """
        contours = cv2.findContours(image.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]
        rects = [rect for rect in rects if rect[2] < 10 or rect[3] < 10]

        for rect in rects:
            x, y, w, h = rect
            cv2.rectangle(image, (x, y), (x + w, y + h), color, cv2.FILLED)
        return image

    @staticmethod
    def rect_in_list(rect, all_rects):
        for rects in all_rects:
            if rect in rects:
                return True
        return False

    @staticmethod
    def line_between_two_rects(a_rect, b_rect, lines, orientation="v", threshold=15):
        line_list = []
        for line in lines:
            if orientation == "v" and line.start_point[0] >= a_rect[0] + a_rect[2] - threshold and line.start_point[0] <= b_rect[0] + threshold:
                line_list.append(line)
            elif orientation == "h" and line.start_point[1] >= a_rect[1] + a_rect[3] - threshold and line.start_point[1] <= b_rect[1] + threshold:
                line_list.append(line)
        return line_list

    @staticmethod
    def rect_between_two_rects(a_rect, b_rect, rects, orientation="v", threshold=0, return_rects=False):
        if orientation=="h":
            a_rect, b_rect = (a_rect, b_rect) if a_rect[0]<=b_rect[0] else (b_rect, a_rect)
            f_between = lambda a_rect, b_rect, rect: rect[0]>=a_rect[0]+a_rect[2]-threshold and rect[0]+rect[2]<=b_rect[0]+threshold
        else:
            a_rect, b_rect = (a_rect, b_rect) if a_rect[1]<=b_rect[1] else (b_rect, a_rect)
            f_between = lambda a_rect, b_rect, rect: rect[1]>=a_rect[1]+a_rect[3]-threshold and rect[1]+rect[3]<=b_rect[1]+threshold
        if return_rects: #13968
            rect_list = []
            for rect in rects:
                if f_between(a_rect, b_rect, rect):
                    rect_list.append(rect)
            return rect_list
        else:
            for rect in rects:
                if f_between(a_rect, b_rect, rect):
                    return True
            return False

    @staticmethod
    def rects_under_rect(src_rect, rects, orientation="v", threshold=0, return_rects=False):
        if orientation=="h":
            f_under = lambda src_rect, dst_rect: src_rect[0]+src_rect[2]-threshold<=dst_rect[0]
        else:
            f_under = lambda src_rect, dst_rect: src_rect[1]+src_rect[3]-threshold<=dst_rect[1]
        if return_rects:
            rect_list = []
            for dst_rect in rects:
                if f_under(src_rect, dst_rect):
                    rect_list.append(dst_rect)
            return rect_list
        else:
            for dst_rect in rects:
                if f_under(src_rect, dst_rect):
                    return True
            return False

    @staticmethod
    def alignments_contain(col_alignments, alignments):
        for alignment in alignments:
            if alignment in col_alignments:
                return True
        return False

    @staticmethod
    def remove_content_block_by_id(idx, content_blocks):
        for content_block in content_blocks:
            if content_block.idx == idx:
                content_blocks.remove(content_block)

    @staticmethod
    def remove_noise_content_blocks(content_blocks, text_stats_dict): #13625
        ave_area = text_stats_dict["ave_area"]
        ave_w    = text_stats_dict["ave_w"]
        ave_h    = text_stats_dict["ave_h"]

        noise_blocks = []
        for content_block in content_blocks:
            rect = content_block.bounding_rect
            if content_block.area()<ave_area//2 and (rect[2]<ave_w//2 or rect[3]<ave_h//2): #14802
                noise_blocks.append(content_block)
        return list(set(content_blocks)-set(noise_blocks))

    @staticmethod
    def has_box_between_content_blocks(a_content_block, b_content_block, content_blocks, boxes, orientation="horizontal"):
        """Check if between two content blocks exist at least a content block or a table bouding box
        """
        threshold = 5

        bounding_rect = Utils.bounding_rect([a_content_block.bounding_rect, b_content_block.bounding_rect])
        bounding_rect = Utils.expand_rect(bounding_rect, -threshold)

        if orientation == "vertical":
            if a_content_block.bounding_rect[1] < b_content_block.bounding_rect[1]:
                a_rect = a_content_block.bounding_rect
                b_rect = b_content_block.bounding_rect
            else:
                a_rect = b_content_block.bounding_rect
                b_rect = a_content_block.bounding_rect

            # Sort all content blocks by Y position
            content_blocks = sorted(content_blocks, key=lambda content_block: content_block.bounding_rect[1])
            for content_block in content_blocks:
                rect = content_block.bounding_rect
                #13652 add threshold
                if a_rect[1] + a_rect[3] - threshold <= rect[1] and rect[1] + rect[3] <= b_rect[1] + threshold \
                    and Utils.rect_overlap_rect(Utils.expand_rect(bounding_rect, -threshold), rect):
                    return True

            for box in boxes:
                # if a_rect[1] + a_rect[3] <= box[1] and box[1] + box[3] <= b_rect[1] and Utils.rect_overlap_rect(bounding_rect, box):
                if Utils.rect_overlap_rect(bounding_rect, box):
                    return True

        elif orientation == "horizontal":
            if a_content_block.bounding_rect[0] < b_content_block.bounding_rect[0]:
                a_rect = a_content_block.bounding_rect
                b_rect = b_content_block.bounding_rect
            else:
                a_rect = b_content_block.bounding_rect
                b_rect = a_content_block.bounding_rect

            # Sort all content blocks by X position
            content_blocks = sorted(content_blocks, key=lambda content_block: content_block.bounding_rect[0])
            for content_block in content_blocks:
                rect = Utils.expand_rect(content_block.bounding_rect, -threshold)

                if a_rect[0] + a_rect[2] <= rect[0] and rect[0] + rect[2] <= b_rect[0] \
                    and Utils.rect_overlap_rect(bounding_rect, rect):
                    return True

            for box in boxes:
                # if a_rect[0] + a_rect[2] <= box[0] and box[0] + box[2] <= b_rect[0] and Utils.rect_overlap_rect(bounding_rect, box):
                if Utils.rect_overlap_rect(bounding_rect, box):
                    return True

        return False

    def draw_group(image, group, color=(255, 0, 255), thickness=1):
        """
        Draw content block bounding box and id
        """
        Utils.draw_box(image, group.bounding_rect(), color, thickness)
        return image

    @staticmethod
    def draw_groups(image, groups, color=(255, 0, 255), thickness=1):
        for group in groups:
            Utils.draw_group(image, group, color, thickness)
        return image

    @staticmethod
    def draw_content_block(image, content_block, color=(255, 0, 255), thickness=1):
        """
        Draw content block bounding box and id
        """
        x, y, w, h = content_block.bounding_rect
        Utils.draw_box(image, content_block.bounding_rect, color, thickness)
        cv2.putText(image, str(content_block.idx), (x, y), cv2.FONT_HERSHEY_COMPLEX, 0.5, 0)
        return image

    @staticmethod
    def draw_content_blocks(image, content_blocks, color=(255, 0, 255), thickness=1):
        for content_block in content_blocks:
            Utils.draw_content_block(image, content_block, color, thickness)
        return image

    @staticmethod
    def draw_box(image, box, color=(255, 0, 255), thickness=1):
        '''
        Draw bounding box for debugging
        '''
        x, y, w, h = box
        cv2.rectangle(image, (x, y), (x + w, y + h), color, thickness)
        return image

    @staticmethod
    def fill_box(image, box, color=(255, 0, 255)):
        '''
        fill bounding box
        '''
        x, y, w, h = box
        cv2.rectangle(image, (x, y), (x + w, y + h), color, cv2.FILLED)
        return image

    @staticmethod
    def draw_boxes(image, boxes, color=(255, 0, 255), thickness=1):
        '''
        Draw bounding box for debugging
        '''
        for box in boxes:
            Utils.draw_box(image, box, color, thickness)
        return image

    @staticmethod
    def fill_boxes(image, boxes, color=(0, 0, 255)):
        for box in boxes:
            Utils.fill_box(image, box, color)
        return image

    @staticmethod
    def draw_line(image, line, color=(255, 0, 255), thickness=1):
        cv2.line(image, line.start_point, line.end_point, color, thickness)
        return image

    @staticmethod
    def draw_lines(image, lines, color=(255, 0, 255), thickness=1):
        for line in lines:
            Utils.draw_line(image, line, color, thickness)
        return image

    @staticmethod
    def draw_table(image, table, border_color=(0, 0, 255), line_color=(0, 255, 0), divider_line_color=(255, 0, 0), thickness=2, draw_virtual_lines = True):

        if table.left_border is not None:
            Utils.draw_line(image, table.left_border, border_color, thickness)

        if table.top_border is not None:
            Utils.draw_line(image, table.top_border, border_color, thickness)

        if table.right_border is not None:
            Utils.draw_line(image, table.right_border, border_color, thickness)

        if table.bottom_border is not None:
            Utils.draw_line(image, table.bottom_border, border_color, thickness)

        #if draw_virtual_lines == 1:
            #table_vertical_lines = table.vertical_lines + table.horizontal_lines
            #table_divider_vectical_lines = table.divider_vertical_lines + table.divider_horizontal_lines
        #else:
            #table_vertical_lines = table.vertical_lines
            #table_divider_vectical_lines = table.divider_vertical_lines
            
        for line in table.vertical_lines + table.horizontal_lines:
            Utils.draw_line(image, line, line_color, thickness)

        #for line in table_vertical_lines:
        #    Utils.draw_line(image, line, line_color, thickness)

        if draw_virtual_lines == 1:
            for line in table.divider_vertical_lines + table.divider_horizontal_lines:
                Utils.draw_line(image, line, divider_line_color, thickness)

        #for line in table_divider_vectical_lines:
        #    Utils.draw_line(image, line, divider_line_color, thickness)

        return image

    @staticmethod
    def rect_overlap_rect_with_percent(a_rect, b_rect, threshold=2, min_rect=False):
        """ calculate overlap percentage between 2 rect
        params: a_rect coordination, b_rect coordination
        :returns: True: if overlap ratio between a_rect and b_rect is greater than threshold
                  False: Otherwise"""
        x, y, w, h = a_rect
        a_rect_area = w * h
        a_rect_x1, a_rect_y1, a_rect_x2, a_rect_y2 = x, y, x + w, y + h

        x, y, w, h = b_rect
        b_rect_area = w * h
        b_rect_x1, b_rect_y1, b_rect_x2, b_rect_y2 = x, y, x + w, y + h

        dx = min(a_rect_x2, b_rect_x2) - max(a_rect_x1, b_rect_x1)
        dy = min(a_rect_y2, b_rect_y2) - max(a_rect_y1, b_rect_y1)

        if dx > 0 and dy > 0:
            overlap_area = dx * dy
            # calculate overlap ratio
            if min_rect:
                tmp_area = min(a_rect_area, b_rect_area) - overlap_area
            else:
                tmp_area = a_rect_area + b_rect_area - overlap_area
            if tmp_area<=0:
                tmp_area = overlap_area
            overlap_ratio = overlap_area / tmp_area * 100

            return overlap_ratio > threshold

        return False

    @staticmethod
    def rect_overlap_rect_with_width_height(a_rect, b_rect, width, height):
        """ calculate overlap percentage between 2 rect
        params: a_rect coordination, b_rect coordination
        :returns: True: if overlap ratio between a_rect and b_rect is greater than threshold
                  False: Otherwise"""
        x, y, w, h = a_rect
        a_rect_x1, a_rect_y1, a_rect_x2, a_rect_y2 = x, y, x + w, y + h

        x, y, w, h = b_rect
        b_rect_x1, b_rect_y1, b_rect_x2, b_rect_y2 = x, y, x + w, y + h

        dx = min(a_rect_x2, b_rect_x2) - max(a_rect_x1, b_rect_x1)
        dy = min(a_rect_y2, b_rect_y2) - max(a_rect_y1, b_rect_y1)

        return dx > width and dy > height



    @staticmethod
    def rect_can_be_merged(a_rect, b_rect, threshold=50):
        """:return: whether or not 2 boxes has same position, width or height"""
        a_rect_x, a_rect_y, a_rect_w, a_rect_h = a_rect
        b_rect_x, b_rect_y, b_rect_w, b_rect_h = b_rect
        if abs(a_rect_w - b_rect_w) < threshold and \
                (abs(a_rect_x - b_rect_x) < threshold or abs((a_rect_x + a_rect_w) - (b_rect_x + b_rect_w)) < threshold):
            return True
        if abs(a_rect_h - b_rect_h) < threshold and \
                (abs(a_rect_y - b_rect_y) < threshold or abs((a_rect_y + a_rect_h) - (b_rect_y + b_rect_h)) < threshold):
            return True
        return False

    @staticmethod
    def extend_line_at_corner(h_lines, v_lines, threshold_v=10, threshold_h=10):
        """
        :param h_lines: the horizontal lines in the image
        :param v_lines: the vertical lines in the image
        :param threshold_v: maximum of vertical line's length can be extended
        :param threshold_h: maximum of horizontal line's length can be extended
        :return: the list of horizontal lines and vertical lines
                 The horizontal line and vertical line is extended to each others when the distance between
                 start point (end point) of horizontal (vertical) and start point (end point) of vertical (horizontal)
                 is smaller than threshold
        """
        v_lines.sort(key=lambda line: line.start_point[1])
        h_lines.sort(key=lambda line: line.start_point[0])
        for v_line in v_lines:
            for h_line in h_lines:
                if Utils.distance_from_line_to_line(h_line, v_line) <= max(threshold_h, threshold_v):
                    intersection_point = Utils.line_intersection(h_line, v_line)
                    if not intersection_point[0]:
                        continue
                    if not h_line.connect_at_start_point and not v_line.connect_at_start_point \
                            and Utils.distance_from_point_to_point(h_line.start_point, intersection_point) < threshold_h\
                            and Utils.distance_from_point_to_point(v_line.start_point, intersection_point) < threshold_v:
                        h_line.start_point = intersection_point
                        v_line.start_point = intersection_point
                        h_line.connect_at_start_point = True
                        v_line.connect_at_start_point = True

                    if not h_line.connect_at_start_point and not v_line.connect_at_end_point\
                            and Utils.distance_from_point_to_point(h_line.start_point, intersection_point) < threshold_h\
                            and Utils.distance_from_point_to_point(v_line.end_point, intersection_point) < threshold_v:
                        h_line.start_point = intersection_point
                        v_line.end_point = intersection_point
                        h_line.connect_at_start_point = True
                        v_line.connect_at_end_point = True

                    if not h_line.connect_at_end_point and not v_line.connect_at_start_point\
                            and Utils.distance_from_point_to_point(h_line.end_point, intersection_point) < threshold_h \
                            and Utils.distance_from_point_to_point(v_line.start_point, intersection_point) < threshold_v:
                        h_line.end_point = intersection_point
                        v_line.start_point = intersection_point
                        h_line.connect_at_end_point = True
                        v_line.connect_at_start_point = True

                    if not h_line.connect_at_end_point and not v_line.connect_at_end_point\
                            and Utils.distance_from_point_to_point(h_line.end_point, intersection_point) < threshold_h \
                            and Utils.distance_from_point_to_point(v_line.end_point, intersection_point) < threshold_v:
                        h_line.end_point = intersection_point
                        v_line.end_point = intersection_point
                        h_line.connect_at_end_point = True
                        v_line.connect_at_end_point = True

        return h_lines, v_lines

    @staticmethod
    def line_belong_with_box(box, line, threshold=0.8):
        if line.orientation == 'h':
            return (line.end_point[0] - line.start_point[0]) / box[2] >= threshold
        else:
            return (line.end_point[1] - line.start_point[1]) / box[3] >= threshold

    @staticmethod
    def reset_connect_at_line_corner(lines):
        """
        :param lines:
        :return: set all the connect property of the line to False
        """
        for line in lines:
            line.connect_at_start_point = False
            line.connect_at_end_point = False
        return lines

    @staticmethod
    def expand_image(image, padding_size):
        """
        :param image:
        :param padding_size:
        :return: the image is added more padding
        """
        expanded_image = np.pad(image, [(padding_size, padding_size), (padding_size, padding_size)],
                                "constant", constant_values=255)
        return expanded_image

    @staticmethod
    def remove_padding_rect(rect, image_shape, padding_size):
        """
        :param rect: the rect's position
        :param image_shape: the shape of the input image
        :param padding_size: the padding of the image
        :return: exactly rect's position in the input image
        """
        h_image = image_shape[0]
        w_image = image_shape[1]
        x1 = max(rect[0] - padding_size, 0) # in case, the line reach the border
        y1 = max(rect[1] - padding_size, 0)
        x2 = min(w_image, x1 + rect[2])
        y2 = min(h_image, y1 + rect[3])
        return x1, y1, x2 - x1, y2 - y1

    @staticmethod
    def line_at_border_image(rect, image_shape, padding_size):
        """
        :param rect: the rect's position
        :param image_shape: the shape of the input image
        :param padding_size: the padding of the image
        :return: The rect whether or not is in border of the image.
        """
        h_image = image_shape[0]
        w_image = image_shape[1]
        x, y, w, h = rect
        if w > h and (y <= padding_size or y + h >= h_image + padding_size):
            return True
        if w < h and (x <= padding_size or x + w >= w_image + padding_size):
            return True
        return False

    @staticmethod
    def check_two_points_in_same_line(a_point, b_point, orientation, threshold=20):
        if orientation == "vertical" and abs(a_point[0] - b_point[0]) <= threshold:
            return True
        if orientation == "horizontal" and abs(a_point[1] - b_point[1]) <= threshold:
            return True
        return False

    @staticmethod
    def real_text_block(text_box, threshold=500):
        """
        :param text_box:
        :param threshold: the text block is considered as true text block if it's width or height is smaller than this parameter
        :return: True: it is true text block
                 False: Otherwise
        """
        return text_box[2] <= threshold or text_box[3] <= threshold

    @staticmethod
    def remove_dot_lines_noise(dot_rects, text_blocks):
        """
        :param dot_rects:
        :param text_blocks:
        :return: the line is made by some of dots without noise line.
                The line is considered as the noise line if it go through more than 2 text blocks
        """
        invalid_dots = []
        for dot_rect in dot_rects:
            count_down = 2
            for text_block in text_blocks:
                if Utils.rect_overlap_rect_with_percent(dot_rect, text_block, 0):
                    count_down -= 1
                    if count_down == 0:
                        invalid_dots.append(dot_rect)
                        break

        for invalid_dot in invalid_dots:
            if invalid_dot in dot_rects:
                dot_rects.remove(invalid_dot)

        return dot_rects


    @staticmethod
    def white_percentage(image):
        """
        :return: the white pixel ratio in the image.
        """
        white_pixels = np.sum(image == 255)
        return white_pixels / (image.shape[0] * image.shape[1]) * 100

    @staticmethod
    def width_line(line):
        """
        :param line:
        :return: width of the line
        """
        return line.end_point[0] - line.start_point[0]

    @staticmethod
    def height_line(line):
        """
        :param line:
        :return: height of the line
        """
        return line.end_point[1] - line.start_point[1]

    @staticmethod
    def content_block_in_groups(groups, content_block):
        """Check if a Content_Block has aready existed in a list of group
        """
        for group in groups:
            for cb in group.content_blocks:
                if cb.idx == content_block.idx:
                    return True
        return False

    @staticmethod
    def remove_underline_text(lines, block_texts, threshold_distance=15, threshold_deviation=20):
        """
        :param lines:
        :param block_texts:
        :param threshold_distance: the line is considered as a underline of the block text
                                    if distance between them is smaller than this parameter
        :param threshold_deviation: the line is considered as a underline of the block text
                                    if the line and the block text are aligned center.
                                    The line and the block is considered as aligned center of each others
                                    when deviation is smaller than this parameter
        :return: lines without underlines and extend text block above underline with the with of the text block
        """

        def align_center(block_text, line, threshold_deviation):
            """
            :param block_text: bounding rectangle of the block text
            :param line: line object
            :param threshold_deviation: a line is considered as center alignment with the block_text
                    if the x_center coordination of the line is approximately x_center coordination of the block text
            :return: whether or not line is center alignment with the text block
            """
            # x_center coordination of the text block
            center_text = block_text[0] + block_text[2] / 2
            # x_center coordination of the line
            center_line = line.start_point[0] + Utils.width_line(line) / 2

            return abs(center_text - center_line) < threshold_deviation

        underlines = []
        for idx, block_text in enumerate(block_texts):
            for line in lines:
                # only check short line (<300)
                # only check the line is near the block text and under the block text
                if line.orientation == 'h' and Utils.width_line(line) < 300 and not Utils.line_inside_box(block_text, line, 5) \
                                           and Utils.distance_from_line_to_box(block_text, line, "bottom") < threshold_distance:
                    lines_temp = lines.copy()
                    # list of those lines without the line
                    lines_temp.remove(line)

                    for line_checked in lines_temp:
                        # if the block text has another line in above and center alignment,
                        # we do not check underline anymore
                        if line_checked.orientation == 'h' and Utils.width_line(line_checked) < 300 \
                                            and align_center(block_text, line_checked, threshold_deviation)\
                                            and Utils.distance_from_line_to_box(block_text, line_checked, "top") < threshold_distance:
                            break
                        # if the block text is nearly a vertical line, we do not check underline anymore
                        if line_checked.orientation == 'v' and Utils.distance_from_line_to_line(line, line_checked) < threshold_distance:
                            break
                    else:
                        # check the line whether or not is underline
                        if align_center(block_text, line, threshold_deviation):
                            underlines.append(line)
                            x, y, w, h = block_texts[idx]
                            x = min(x, line.start_point[0])
                            w = max(w, Utils.width_line(line))
                            block_texts[idx] = (x, y, w, h)

        for underline in underlines:
            if underline in lines:
                lines.remove(underline)
        return lines, block_texts

    @staticmethod
    def remove_invalid_signed(h_lines):
        """
        :param h_lines: horizontal lines
        :return: remove small horizontal line if it do not connect with any vertical line
                 and has the same width and y_coordination with other small line
        """

        def same_horizontal_sign(a_line, b_line, threshold=5):
            return abs(a_line.start_point[1] - b_line.start_point[1]) < threshold and abs(Utils.width_line(a_line) - Utils.width_line(b_line)) < threshold

        invalid_lines = []

        for h_line in h_lines:
            if Utils.width_line(h_line) < 100 and h_line.connect_at_start_point == False and h_line.connect_at_end_point == False:
                    h_lines_temp = h_lines.copy()
                    h_lines_temp.remove(h_line)
                    for h_line_temp in h_lines_temp:
                        if same_horizontal_sign(h_line, h_line_temp):
                            invalid_lines.append(h_line)
                            invalid_lines.append(h_line_temp)

        for h_line in invalid_lines:
            if h_line in h_lines:
                h_lines.remove(h_line)

        return h_lines

    @staticmethod
    def merge_overlap_boxes(boxes, width=2, height=2):
        """
        :param boxes:
        :param width:
        :param height:
        :return: the list of boxes.
                Two boxes will be merged if the overlap squared of them is greater than width and height
        """
        extend_boxes = []

        for i in range(len(boxes) - 1):
            new_box = boxes[i]
            for j in range(len(boxes) - 1):
                b_rect = boxes[j]
                if Utils.rect_overlap_rect_with_width_height(new_box, b_rect, width, height):
                    # merge 2 overlaped boxes
                    temp_box = Utils.bounding_rect([new_box, b_rect])
                    # remove padding after each of merge
                    new_box = (temp_box[0], temp_box[1], temp_box[2] - 1, temp_box[3] - 1)

            extend_boxes.append(new_box)

        extend_boxes = list(set(extend_boxes))

        return extend_boxes

    @staticmethod
    def merge_two_types_text_blocks(old_text_blocks, new_text_blocks):
        """
        :param old_text_blocks: text blocks is detected by Infodio algorithm
        :param new_text_blocks: text blocks is detected by our algorithm
        :return: list of the best exactly text blocks
        """
        # combine 2 types of text blocks
        text_block_rects = []
        for old_text_block in old_text_blocks:
            # keep the small text block (Almost it is a number)
            if old_text_block[2] < 50 and old_text_block[3] < 50:
                text_block_rects.append(old_text_block)
            else:
                # If the bigger text block overlaps with new text block. They will be merge together.
                for new_text_block in new_text_blocks:
                    if Utils.rect_overlap_rect(old_text_block, new_text_block):
                        text_block_rects.append(new_text_block)
        # Add the sign(shape in image) position in image to the text blocks
        for new_text_block in new_text_blocks:
            if new_text_block[2] > 50 and new_text_block[3] > 50:
                text_block_rects.append(new_text_block)

        return list(set(text_block_rects))

    @staticmethod
    def remove_noise_lines_rect(line_rects, text_block_rects):
        """
        :param line_rects: all of the line's position
        :param text_block_rects: all of the text block's position
        :return: new line rectangle list
         A line is considered as a noise line
         when it's a small line and around the line does not have any line or text block
        """
        invalid_lines = []
        for line_rect in line_rects:
            if line_rect[2] * line_rect[3] < 200:
                line_rect_padding = Utils.expand_rect(line_rect, 5)
                temp_line_rects = list(line_rects.copy())
                # compare this line with all others lines
                temp_line_rects.remove(line_rect)
                # if line overlaps with others line, that mean this line is valid, so do not need check anymore
                for temp_line_rect in temp_line_rects:
                    if Utils.rect_overlap_rect(line_rect_padding, temp_line_rect):
                        break
                else:
                    # if line overlaps with text blocks, that mean this line is valid, so do not need check anymore
                    for text_block_rect in text_block_rects:
                        if Utils.rect_overlap_rect(line_rect_padding, text_block_rect):
                            break
                    else:
                        invalid_lines.append(line_rect)

        # remove the invalid lines
        for invalid_line in invalid_lines:
            if invalid_line in line_rects:
                line_rects.remove(invalid_line)

        return line_rects

    @staticmethod
    def convert_rect_to_rect(rect, width_ratio, height_ratio):
        x1,y1,w,h = rect
        x2 = x1 + w
        y2 = y1 + h
        
        x1 = int(x1 * width_ratio)
        y1 = int(y1 * height_ratio)
        x2 = int(x2 * width_ratio)
        y2 = int(y2 * height_ratio)

        return (x1, y1, x2 - x1, y2 - y1)


    @staticmethod
    def convert_rects_to_rects(rects, width_ratio, height_ratio):
        return [Utils.convert_rect_to_rect(rect, width_ratio, height_ratio) for rect in rects]

    @staticmethod
    def extract_line_rect(image, remove_line_at_border=True):
        """
        :param image: The image contains horizontal lines or vertical lines.
        :param remove_line_at_border: True: remove the line reach to the border of image. False: Otherwise
        :return: Extract all line in the image
        """
        extract_line_image = image.copy()
        image_shape = image.shape
        PADDING_SIZE = 5

        # add padding to the image to extract line reach to border image
        extract_line_image = Utils.expand_image(extract_line_image, PADDING_SIZE)

        contours = cv2.findContours(extract_line_image.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[1]
        rects = [cv2.boundingRect(c) for c in contours]

        # Remove noise: small line or the line reach to border image(It depends on the remove_line_at_border parameter)
        # convert box coordination from padding image to the original image
        rects = [Utils.remove_padding_rect(rect, image_shape, PADDING_SIZE) for rect in rects if
                 not (Utils.is_noise(rect))
                 and not (remove_line_at_border and Utils.line_at_border_image(rect, image_shape, PADDING_SIZE))]
        # remove the lines, if that line's width or line's height is too big
        return [rect for rect in rects if rect[2] < 40 or rect[3] < 40]

    @staticmethod
    def is_point_in_line(point, line):
        return (point[1] == line.start_point[1] and line.start_point[0] <= point[0] <= line.end_point[0]) or \
                (point[0] == line.start_point[0] and line.start_point[1] <= point[1] <= line.end_point[1])

    @staticmethod
    def is_start_point_on_intersection(line, orientation="v", threshold=0):
        """
        :param line:
        :param orientation:
        :param threshold: threshold of distance between start point and original start point
        :return: True if start point on the intersection point
        """
        idx = 1 if orientation=="v" else 0
        if line.original_start_point and line.start_point:
            orig_start_point = line.original_start_point[idx] # start point before shrink_line()
            start_point      = line.start_point[idx]          # intersection start point at shrink_line()
            return abs(orig_start_point-start_point)<threshold
        else:
            return False

    @staticmethod
    def is_end_point_on_intersection(line, orientation="v", threshold=0):
        """
        :param line:
        :param orientation:
        :param threshold: threshold of distance between end point and original end point
        :return: True if point on intersection
        """
        idx = 1 if orientation=="v" else 0
        if line.original_end_point and line.end_point:
            orig_end_point = line.original_end_point[idx] # end point before shrink_line()
            end_point      = line.end_point[idx]          # intersection end point at shrink_line()
            return abs(orig_end_point-end_point)<threshold
        else:
            return False

    @staticmethod
    def is_point_far_line(point, line, times=1):
        """
        Is the point {times} times as far away from the line

        :param point:
        :param line:
        :param times: a multiple of the line length
        :return: True if point is far from line
        """
        min_distance = min(Utils.distance_from_point_to_point(line.start_point, point),
                           Utils.distance_from_point_to_point(line.end_point,   point))
        # return line.length()*times>min_distance
        return min_distance<10

    @staticmethod
    def search_text_by_box(crnn_chars, box): #13968
        """
        Search text from crnn_chars by box

        :param crnn_chars:
        :param box:
        :return find:text  not find:""
        """
        text = [crnn_char["text"] for crnn_char in crnn_chars if (crnn_char["x"], crnn_char["y"], crnn_char["w"], crnn_char["h"])==box]
        return text[0] if text and text[0] else ""

    @staticmethod
    def merge_single_chars(text_list):
        merge_chars_list = []
        searched_ids     = []
        for i, src_text in enumerate(text_list):
            if len(src_text)==1 and i not in searched_ids: # chack single char
                merge_chars_list.append([i])
                for j, dst_text in enumerate(text_list[i+1:], start=i+1):
                    if len(dst_text)==1 and j not in searched_ids:
                        merge_chars_list[-1].append(j)
                        searched_ids.append(j)
                    else:
                        break
        # merge single chars
        adj = 0
        for merge_chars in merge_chars_list:
            if len(merge_chars)>=2:
                text_list.insert(merge_chars[0]-adj, "".join(text_list[merge_chars[0]-adj:merge_chars[-1]+1-adj]))
                for i in merge_chars:
                    if merge_chars[0]-adj+1<len(text_list):
                        text_list.pop(merge_chars[0]-adj+1)
                adj += len(merge_chars)-1
        return text_list

    @staticmethod
    def is_text_blocks_header_by_header_dict(blocks, crnn_chars, header_regex): #13968
        if len(blocks)<=1: #14611
            return False
        text_list = [Utils.search_text_by_box(crnn_chars, block) for block in blocks]
        text_list = Utils.merge_single_chars(text_list)
        text_list = [text.replace(' ', '') for text in text_list]
        candidate_header_count = 0
        span_list    = []
        searched_ids = []
        THRESH       = len(blocks) if len(blocks)<=3 else len(blocks)//2 #14782
        for regex in header_regex:
            for i, text in enumerate(text_list):
                res = re.fullmatch(regex, text)
                if res and i not in searched_ids:
                    candidate_header_count += 1
                    searched_ids.append(i)
                if candidate_header_count>=THRESH: # thresh
                    return True
        return False

    @staticmethod
    def align_horizontal(a_box, b_box, threshold=5):
        a_x, a_y, a_w, a_h = a_box
        b_x, b_y, b_w, b_h = b_box
        if abs(a_y - b_y) <= threshold:
            return "top"
        if abs((a_y + a_h / 2) - (b_y + b_h / 2)) <= threshold:
            return "center"
        if abs((a_y + a_h) - (b_y + b_h)) <= threshold:
            return "bottom"
        return False

    @staticmethod
    def align_vertical(a_box, b_box, threshold=5):
        a_x, a_y, a_w, a_h = a_box
        b_x, b_y, b_w, b_h = b_box
        if abs(a_x - b_x) <= threshold:
            return "left"
        if abs((a_x + a_w / 2) - (b_x + b_w / 2)) <= threshold:
            return "center"
        if abs((a_x + a_w) - (b_x + b_w)) <= threshold:
            return "right"
        return False

    @staticmethod
    def get_rows_from_content_boxes(content_boxes, ignore_single=False):
        """
        Get rows from content boxes

        :param contnet_boxes:
        :param ignore_signle: ignore single content row if True
        :return rows:
        """
        # TODO:allow multiple rows
        ALIGNMENT_THRESH = 10
        content_boxes = sorted(content_boxes, key=lambda box:(box[0], box[1])) # sort by x,y
        rows        = []
        added_boxes = []
        for i, src_box in enumerate(content_boxes):
            if src_box in added_boxes:
                continue
            tmp_row = [src_box]
            added_boxes.append(src_box)
            for dst_box in content_boxes[i+1:]:
                tail_box = tmp_row[-1]
                if dst_box in added_boxes or not Utils.rect_vertical_overlap_rect(Utils.expand_rect(tail_box, -2), dst_box):
                    continue
                alignment = Utils.align_horizontal(tail_box, dst_box, threshold=ALIGNMENT_THRESH) # get alignment
                if alignment:
                    tmp_row.append(dst_box)
                    added_boxes.append(dst_box)
                else:
                    break
            if ignore_single:
                if len(tmp_row)>1:
                    rows.append(tmp_row)
            else:
                rows.append(tmp_row)
        return rows

    @staticmethod
    def get_columns_from_content_boxes(content_boxes, ignore_single=False):
        """
        Get columns from content boxes

        :param contnet_boxes:
        :param ignore_signle:
        :return cols:
        """
        ALIGNMENT_THRESH = 10
        content_boxes = sorted(content_boxes, key=lambda box:(box[1], box[0])) # sort by y,x
        cols        = []
        added_boxes = []
        for i, src_box in enumerate(content_boxes):
            if src_box in added_boxes:
                continue
            tmp_col = [src_box]
            added_boxes.append(src_box)
            for dst_box in content_boxes[i+1:]:
                if dst_box in added_boxes or not Utils.rect_horizontal_overlap_rect(Utils.expand_rect(src_box, -2), dst_box):
                    continue
                alignment = Utils.align_vertical(src_box, dst_box, threshold=ALIGNMENT_THRESH) # get alignment
                if alignment:
                    tmp_col.append(dst_box)
                    added_boxes.append(dst_box)
                else:
                    break
            if ignore_single:
                if len(tmp_col)>1:
                    cols.append(tmp_col)
            else:
                cols.append(tmp_col)
        return cols

    @staticmethod
    def is_fill_area(box, image): #14802
        FILL_AREA_PERCENT = 70
        part_area = Utils.get_area_from_binary_image(box, image)
        max_white  = box[2]*box[3]*255 # max number of white on line_rect
        area_white = np.sum(part_area)
        if area_white/max_white*100>=FILL_AREA_PERCENT:
            return True
        return False
