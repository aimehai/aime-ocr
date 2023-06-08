import cv2
import copy
import random

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class TableBox(object):
    """Represent a bounding box of table
    """
    bounding_rect = None

    content_blocks = []

    """True: a table found by findContours
    False: a table groupped by content blocks
    """
    real_table = True

    def __init__(self, rect, real_table):
        self.content_blocks = []
        self.bounding_rect = rect
        self.real_table = real_table

    def append_content_block(self, content_block):
        """Add the content block to the group
        """
        self.content_blocks.append(content_block)
