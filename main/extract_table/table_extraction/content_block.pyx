import cv2
import copy
import random

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class ContentBlock(object):
    """Represent a text block (normally a posible table cell content)
    """

    idx = -1

    # Bounding box (a rectange)
    bounding_rect = None
    table_content_block = False

    def __init__(self, rect, idx):
        self.bounding_rect = rect
        self.table_content_block = False
        self.idx = idx

    def area(self):
        return self.bounding_rect[2]*self.bounding_rect[3]

    def is_upper(self, block, thresh=0): #13652
        """ Check self is upper target block
        """
        self_rect   = self.bounding_rect
        target_rect = block.bounding_rect
        if target_rect[1]>=self_rect[1]+self_rect[3]:
            return True
        return False

    def is_below(self, block, thresh=0): #13652
        """ Check self is below target block
        """
        self_rect   = self.bounding_rect
        target_rect = block.bounding_rect
        if target_rect[1]+target_rect[3]<=self_rect[1]:
            return True
        return False

    def is_left(self, block, thresh=0): #13652
        """ Check self is left target block
        """
        self_rect   = self.bounding_rect
        target_rect = block.bounding_rect
        if target_rect[0]>=self_rect[0]+self_rect[2]:
            return True
        return False

    def is_right(self, block, thresh=0): #13652
        """ Check self is right target block
        """
        self_rect   = self.bounding_rect
        target_rect = block.bounding_rect
        if target_rect[0]+target_rect[2]<=self_rect[0]:
            return True
        return False

    def align_horizontal_with(self, content_block, threshold=5):
        alignments = []
        a_x, a_y, a_w, a_h = self.bounding_rect
        b_x, b_y, b_w, b_h = content_block.bounding_rect

        if abs(a_y - b_y) <= threshold:
            alignments.append("top")
        if abs((a_y + a_h / 2) - (b_y + b_h / 2)) <= threshold:
            alignments.append("center")
        if abs((a_y + a_h) - (b_y + b_h)) <= threshold:
            alignments.append("bottom")

        return alignments

    def align_vertical_with(self, content_block, threshold=5):
        alignments = []
        a_x, a_y, a_w, a_h = self.bounding_rect
        b_x, b_y, b_w, b_h = content_block.bounding_rect

        if abs(a_x - b_x) <= threshold:
            alignments.append("left")
        if abs((a_x + a_w / 2) - (b_x + b_w / 2)) <= threshold:
            alignments.append("center")
        if abs((a_x + a_w) - (b_x + b_w)) <= threshold:
            alignments.append("right")
        return alignments

    def single_word(self):
        """Check if this content block is single word: normal with width <= height
        """
        return self.bounding_rect[2] <= self.bounding_rect[3] + 10 #13451(5->10)
