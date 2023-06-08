import cv2

import numpy as np

from table_extraction.utils_table_extraction import Utils
from table_extraction.debug import Debug

class ImageProcessing(object):

    EXPAND = 5

    @staticmethod
    def binalize(image, adaptive=True):
        blur_image = cv2.bilateralFilter(image, 9, 11, 3)
        not_image = cv2.bitwise_not(blur_image)
        if adaptive:
            binary_image = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 13, -7)
        else:
            _, binary_image = cv2.threshold(not_image, 30, 255, cv2.THRESH_BINARY)
        return binary_image

    @staticmethod
    def lines_image(image, horizontal_size=38, vertical_size=20):
        """
        :param image:
        :param horizontal_size: the horizontal size to create structure element
        :param vertical_size: the vertical size to create structure element
        :return: horizontal line image, vertical line image, binary image from original image
        """
        # Remove background noise
        blur_image = cv2.bilateralFilter(image, 9, 11, 3)
        not_image = cv2.bitwise_not(blur_image)

        binary_image = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 13, -7)

        horizontal = binary_image.copy()
        vertical = binary_image.copy()

        # convert dot line to line(#12465)
        # dotline_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 1))
        # horizontal = cv2.dilate(horizontal, dotline_structure, iterations=1)
        # horizontal = cv2.erode(horizontal, dotline_structure, iterations=1)
        # dotline_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 2))
        # vertical   = cv2.dilate(vertical,   dotline_structure, iterations=1)
        # vertical   = cv2.erode(vertical,   dotline_structure, iterations=1)

        # Create structure element for extracting horizontal lines through morphology operations
        horizontal_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (horizontal_size, 1))
        # Apply morphology operations
        horizontal = cv2.erode(horizontal, horizontal_structure)
        horizontal = cv2.dilate(horizontal, horizontal_structure)

        # Create structure element for extracting vertical lines through morphology operations
        vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vertical_size))
        # Apply morphology operations
        vertical = cv2.erode(vertical, vertical_structure)
        vertical = cv2.dilate(vertical, vertical_structure)

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (ImageProcessing.EXPAND, ImageProcessing.EXPAND))
        horizontal = cv2.morphologyEx(horizontal, cv2.MORPH_CLOSE, kernel)
        # vertical = cv2.morphologyEx(vertical, cv2.MORPH_CLOSE, kernel)

        Utils.fill_rects(horizontal)
        Utils.fill_rects(vertical)

        # invert the output image
        horizontal = 255 - horizontal
        vertical = 255 - vertical

        return horizontal, vertical, binary_image

    @staticmethod
    def document_detection(image):
        def four_corners_sort(pts):
            """Sort corners in order: top-left, bot-left, bot-right, top-right."""
            diff = np.diff(pts, axis=1)
            summ = pts.sum(axis=1)
            return np.array([pts[np.argmin(summ)],
                             pts[np.argmax(diff)],
                             pts[np.argmax(summ)],
                             pts[np.argmin(diff)]])

        def contour_offset(cnt, offset):
            """Offset contour because of 5px border."""
            cnt += offset
            cnt[cnt < 0] = 0
            return cnt

        def edges_detection(img, minVal, maxVal):
            """Preprocessing (gray, thresh, filter, border) + Canny edge detection."""
            img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            img = cv2.bilateralFilter(img, 9, 75, 75)
            img = cv2.adaptiveThreshold(img, 255,
                                        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                        cv2.THRESH_BINARY, 115, 4)

            # Median blur replace center pixel by median of pixels under kelner
            # => removes thin details
            img = cv2.medianBlur(img, 11)

            # Add black border - detection of border touching pages
            img = cv2.copyMakeBorder(img, 5, 5, 5, 5,
                                     cv2.BORDER_CONSTANT,
                                     value=[0, 0, 0])
            return cv2.Canny(img, minVal, maxVal)

        def find_page_contours(edges, img):
            """Finding corner points of page contour."""
            im2, contours, hierarchy = cv2.findContours(edges,
                                                        cv2.RETR_TREE,
                                                        cv2.CHAIN_APPROX_SIMPLE)

            # Finding biggest rectangle otherwise return original corners
            height = edges.shape[0]
            width = edges.shape[1]
            MIN_COUNTOUR_AREA = height * width * 0.5
            MAX_COUNTOUR_AREA = (width - 10) * (height - 10)

            max_area = MIN_COUNTOUR_AREA
            page_contour = np.array([[0, 0],
                                     [0, height - 5],
                                     [width - 5, height - 5],
                                     [width - 5, 0]])

            for cnt in contours:
                perimeter = cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, 0.03 * perimeter, True)

                # Page has 4 corners and it is convex
                if (len(approx) == 4 and
                        cv2.isContourConvex(approx) and
                        max_area < cv2.contourArea(approx) < MAX_COUNTOUR_AREA):
                    max_area = cv2.contourArea(approx)
                    page_contour = approx[:, 0]

            # Sort corners and offset them
            page_contour = four_corners_sort(page_contour)
            return contour_offset(page_contour, (-5, -5))

        image_edges = edges_detection(image, 200, 250)

        # Close gaps between edges (double page clouse => rectangle kernel)
        closed_edges = cv2.morphologyEx(image_edges,
                                        cv2.MORPH_CLOSE,
                                        np.ones((5, 11)))
        # Countours
        page_contour = find_page_contours(closed_edges, (image))
        # Recalculate to original scale
        # page_contour = page_contour.dot(ratio(image))
        page_contour = np.array(page_contour, dtype=np.int)
        return cv2.boundingRect(page_contour)

    @staticmethod
    def dot_lines_image(no_line_image):
        """ Extract dot lines in image
        """
        # extract horizontal dot line
        kernel_horizontal = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 1))
        grad = cv2.morphologyEx(no_line_image, cv2.MORPH_GRADIENT, kernel_horizontal)
        _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        kernel_horizontal = cv2.getStructuringElement(cv2.MORPH_RECT, (20, 1))
        horizontal_dot_lines_image = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_horizontal)

        # extract horizontal dot line image
        kernel_vertical = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 11))
        grad = cv2.morphologyEx(no_line_image, cv2.MORPH_GRADIENT, kernel_vertical)
        _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        kernel_vertical = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 20))
        vertical_dot_lines_image = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_vertical)

        return horizontal_dot_lines_image, vertical_dot_lines_image

    @staticmethod
    def dot_noise_blocks(image):
        """:returns: noise dot blocks"""
        not_image = cv2.bitwise_not(image)
        binary = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, -7)
        contours = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)[1]
        noise_image = np.zeros(image.shape, dtype=np.uint8)

        for contour in contours:
            rect = cv2.boundingRect(contour)
            if (rect[2] < 7 and rect[3] < 12) or (rect[3] < 7 and rect[2] < 12):
                cv2.rectangle(noise_image, (rect[0], rect[1]), (rect[0] + rect[2], rect[1] + rect[3]), (255, 255, 255), 1)

        # extract horizontal noise dot boxes
        kernel_horizontal = np.ones((1, 20)) / 15
        filter_horizontal = cv2.filter2D(noise_image.copy(), -1, kernel_horizontal)

        horizontal_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (50, 1))
        horizontal = cv2.erode(filter_horizontal, horizontal_structure)
        horizontal = cv2.dilate(horizontal, horizontal_structure)

        contours = cv2.findContours(horizontal, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)[1]

        horizontal_noise_boxes = [cv2.boundingRect(contour) for contour in contours]
        horizontal_noise_boxes = [rect for rect in horizontal_noise_boxes if 20 < rect[3] < rect[2]]

        # extract vertical noise dot boxes
        kernel_vertical = np.ones((20, 1)) / 15
        filter_vertical = cv2.filter2D(noise_image.copy(), -1, kernel_vertical)

        vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 50))
        vertical = cv2.erode(filter_vertical, vertical_structure)
        vertical = cv2.dilate(vertical, vertical_structure)

        contours = cv2.findContours(vertical, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)[1]

        vertical_noise_boxes = [cv2.boundingRect(contour) for contour in contours]
        vertical_noise_boxes = [rect for rect in vertical_noise_boxes if 20 < rect[2] < rect[3]]

        noise_boxes = horizontal_noise_boxes + vertical_noise_boxes

        return noise_boxes

    @staticmethod
    def text_blocks(image):
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 11))
        grad = cv2.morphologyEx(image, cv2.MORPH_GRADIENT, kernel)

        _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1))
        connected = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        _, contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        rects = [cv2.boundingRect(c) for c in contours]
        return [rect for rect in rects if rect[2] > 10 and rect[3] > 10]

    @staticmethod
    def no_lines_image(image):
        """
        :param image:
        :return: the image without it's lines
        """
        # extract the horizontal and vertical lines image from original image
        # Use this threshold to be avoid detect text is a line
        horizontal, vertical, _ = ImageProcessing.lines_image(image, 60, 50)
        mark_image = ~horizontal + ~vertical
        kernel = np.ones((7, 7), np.uint8)
        mark_image = cv2.dilate(mark_image, kernel, iterations=1)
        no_lines_image = cv2.bitwise_or(image, mark_image)
        ret, binary = cv2.threshold(no_lines_image, 127, 255, cv2.THRESH_BINARY)
        return binary

    @staticmethod
    def detect_shape(image, horizontal_img, vertical_img, text_blocks):
        """
        :param image: the original image
        :param horizontal_img: the image contains only horizontal lines
        :param vertical_img: the image contains only vertical lines
        :param text_blocks: the text blocks are detected by Infordio
        :return: bounding rectangle of the shape or logo in the image
        """
        # create mask image contains the vertical, horizontal lines and text blocks
        mark_img = ~horizontal_img + ~vertical_img
        mark_img = Utils.fill_boxes(mark_img, text_blocks, (255, 255, 255))
        kernel = np.ones((7, 7), np.uint8)
        mark_image = cv2.dilate(mark_img, kernel, iterations=1)
        # create image without lines, and text blocks
        shape_img = cv2.bitwise_or(image, mark_image)
        ret, binary = cv2.threshold(shape_img, 200, 255, cv2.THRESH_BINARY)
        # extract bounding rectangle of the shape or logo with the same algorithm with the text blocks detection
        shape_blocks = ImageProcessing.text_blocks(binary)

        # keep the bounding rectangle are nearly a square with width and height condition
        return [shape_block for shape_block in shape_blocks
                if shape_block[2] > 50 and shape_block[3] > 50 and 2 >= shape_block[2] / shape_block[3] >= 0.5]

    @staticmethod
    def refine_text_blocks(image, text_blocks):
        """
        :param image: the binary image
        :param text_blocks: the list bounding rectangle of the text in the image
        :return: new text blocks's position.
                 new text block's position will be fit better to text
        """
        valid_text_blocks = []
        for text_block in text_blocks:
            x, y, w, h = text_block
            image_temp = image[y: y + h, x: x + w].copy()
            # remove the text block is too white or too black. Because the text block is not a real text.
            if 95 > Utils.white_percentage(image_temp) > 5:
                valid_text_blocks.append(text_block)

        refine_text_blocks = []
        padding_size = 5
        # refine the text block: The one text block can be divided in to one, two,... others text block and
        # make the bounding rectangle of the text more correctly.
        for text_block in valid_text_blocks:
            x, y, w, h = text_block
            img_text_block = image[y: y + h, x: x + w].copy()
            # add more paddding into the text block image
            img_text_block = Utils.expand_image(img_text_block, padding_size)
            # extract text block from the old text block.
            new_text_blocks = ImageProcessing.text_blocks(img_text_block)
            for idx, new_text_block in enumerate(new_text_blocks):
                # convert the bounding rectangle text block, which is extracted above,
                # to the bounding rectangle in the original image
                temp_x, temp_y, temp_w, temp_h = Utils.remove_padding_rect(new_text_block, (h, w), padding_size)
                temp_x = x + temp_x
                temp_y = y + temp_y
                refine_text_blocks.append((temp_x, temp_y, temp_w, temp_h))

        return refine_text_blocks

    @staticmethod
    def horizontal_histogram(image, rect=None):
        target = image
        if rect:
            x1, y1 = rect[:2]
            x2, y2 = x1+rect[2], y1+rect[3]
            target = image[y1:y2,x1:x2]
        return np.sum(target, axis=1)
        
    @staticmethod
    def vertical_histogram(image, rect=None):
        target = image
        if rect:
            x1, y1 = rect[:2]
            x2, y2 = x1+rect[2], y1+rect[3]
            target = image[y1:y2,x1:x2]
        return np.sum(target, axis=0)
