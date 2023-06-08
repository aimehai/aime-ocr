import cv2
import copy
import random

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class ContentGroupBlock(object):
    """Represent a group of content blocks (normally a table row or table column)
    """
    content_blocks = []

    # Type of group: Column or Row
    group_type = None

    # Alignment of content column/row: left/center/right
    alignment = None

    def __init__(self, group_type):
        self.content_blocks = []
        self.group_type = group_type

    def extend_content_blocks(self, content_blocks):
        self.content_blocks.extend(content_blocks)
        # for content_block in content_blocks:
        #     self.append_content_block(content_block)

    def append_content_block(self, content_block):
        """Add the content block to the group
        """
        self.content_blocks.append(content_block)

    def bounding_rect(self):
        """Get the row/columb bounding rect

        Returns:
            rect: the bounding rect
        """
        points = []
        for content_block in self.content_blocks:
            x, y, w, h = content_block.bounding_rect
            points.append((x, y))
            points.append((x + w, y + h))

        return cv2.boundingRect(np.array(points, np.float32))

    def single_word_percentage(self):
        """Count single word percentage in this group
        """
        count = 0
        for content_block in self.content_blocks:
            if content_block.single_word():
                count += 1

        return (count / len(self.content_blocks)) * 100
