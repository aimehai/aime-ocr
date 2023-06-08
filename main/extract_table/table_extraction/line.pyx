import cv2
import copy
import random

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class Line(object):
    """Represent a Line with start/end point, line width
    """

    start_point = None
    end_point = None
    width = None

    # The orientation of the line: v/h (horizontal/vertical)
    orientation = None

    # True if this line is inside a table
    table_line = False

    # True if this line is connected with another line at start point 
    connect_at_start_point = False
    original_start_point   = None
    # True if this line is connected with another line at end point
    connect_at_end_point = False
    original_end_point   = None

    # virtual_line = False

    def __init__(self, start_point, end_point, width, orientation):
        self.start_point = start_point
        self.end_point = end_point
        self.width = width
        self.orientation = orientation

    def copy(self):
        return Line(self.start_point, self.end_point, self.width, self.orientation)
    
    def length(self):
        if self.orientation == "h":
            return self.end_point[0] - self.start_point[0]
        else:
            return self.end_point[1] - self.start_point[1]

    def connect_at_start_and_end_point(self):
        return self.connect_at_start_point and self.connect_at_end_point

    def bounding_rect(self):
        # set the line width to 2 pixels
        width = 2

        x1, y1 = self.start_point
        x2, y2 = self.end_point

        if self.orientation == "h":
            return (x1, int(y1 - width / 2), abs(x2 - x1), width)
        else:
            return (int(x1 - width / 2), y1, width, abs(y2 - y1))
