import cv2
import copy
import random

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class Table(object):
    """Represent a table structure with borders, horizontal/vertical lines (the real-lines)
    and horizontal/vertical divider lines (the virtual lines)
    """

    # vertical_lines = []
    # horizontal_lines = []

    # left_border = None
    # top_border = None
    # right_border = None
    # bottom_border = None

    def __init__(self, real_table):
        self.real_table = real_table

        # The real vertical lines
        self.vertical_lines = []
        # The real horizontal lines
        self.horizontal_lines = []

        # The virtual vertical lines
        self.divider_vertical_lines = []
        # The virtual horizontal lines
        self.divider_horizontal_lines = []

        # All table border lines: left/top/right/bottom
        self.left_border = None
        self.top_border = None
        self.right_border = None
        self.bottom_border = None

        # All the text blocks in the images
        self.content_blocks = []

        # Columns in the table
        self.column_groups = []
        # Rows in the table
        self.row_groups = []

    def copy(self):
        new_table = Table(self.real_table)

        # The real vertical lines
        new_table.vertical_lines = self.vertical_lines
        # The real horizontal lines
        new_table.horizontal_lines = self.horizontal_lines

        # The virtual vertical lines
        new_table.divider_vertical_lines = self.divider_vertical_lines
        # The virtual horizontal lines
        new_table.divider_horizontal_lines = self.divider_horizontal_lines

        # All table border lines: left/top/right/bottom
        new_table.left_border = self.left_border
        new_table.top_border = self.top_border
        new_table.right_border = self.right_border
        new_table.bottom_border = self.bottom_border

        # All the text blocks in the images
        new_table.content_blocks = self.content_blocks

        # Columns in the table
        new_table.column_groups = self.column_groups
        # Rows in the table
        new_table.row_groups = self.row_groups
        return new_table

    def append_vertical_lines(self, lines):
        if type(lines) is list:
            self.vertical_lines.extend(lines)
        else:
            self.vertical_lines.append(lines)

    def append_horizontal_lines(self, lines):
        if type(lines) is list:
            self.horizontal_lines.extend(lines)
        else:
            self.horizontal_lines.append(lines)

    def append_divider_vertical_lines(self, lines):
        if type(lines) is list:
            self.divider_vertical_lines.extend(lines)
        else:
            self.divider_vertical_lines.append(lines)

    def append_divider_horizontal_lines(self, lines):
        if type(lines) is list:
            self.divider_horizontal_lines.extend(lines)
        else:
            self.divider_horizontal_lines.append(lines)

    def append_content_block(self, content_block):
        """Add content block to table
        """
        self.content_blocks.append(content_block)

    def extend_content_blocks(self, content_blocks):
        self.content_blocks.extend(content_blocks)

    def all_horizontal_lines(self):
        """Get the all real horizontal lines of this table
        
        :return: the list of horizontal lines
        """
        h_lines = self.horizontal_lines.copy()
        h_lines.append(self.top_border)
        h_lines.append(self.bottom_border)
        h_lines = sorted(h_lines, key=lambda line: line.start_point[1])
        return h_lines

    def all_vertical_lines(self):
        """Get the all real vertical lines of this table
        
        :return: the list of vertical lines
        """
        v_lines = self.vertical_lines.copy()
        v_lines.append(self.left_border)
        v_lines.append(self.right_border)
        v_lines = sorted(v_lines, key=lambda line: line.start_point[0])
        return v_lines

    def all_column_groups(self):
        # Sort all column by X postion
        return sorted(self.column_groups, key=lambda column_group: column_group.bounding_rect()[0])

    def all_row_groups(self):
        # Sort all row by Y postion
        return sorted(self.row_groups, key=lambda column_group: column_group.bounding_rect()[1])

    def all_border_lines(self):
        return self.top_border, self.bottom_border, self.left_border, self.right_border

    def bounding_rect(self):
        """Get the table bounding rect

        Returns:
            rect: the bounding rect
        """
        points = []
        if self.left_border is not None:
            points.append(self.left_border.start_point)
            points.append(self.left_border.end_point)

        if self.top_border is not None:
            points.append(self.top_border.start_point)
            points.append(self.top_border.end_point)

        if self.right_border is not None:
            points.append(self.right_border.start_point)
            points.append(self.right_border.end_point)

        if self.bottom_border is not None:
            points.append(self.bottom_border.start_point)
            points.append(self.bottom_border.end_point)

        return cv2.boundingRect(np.array(points, np.float32))
