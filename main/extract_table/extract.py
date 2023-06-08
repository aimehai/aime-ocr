from .utils_table import Utils
import numpy as np, inspect, json, glob, os, imutils
import cv2

EXPAND = 5


def find_rects(image):
    contours = cv2.findContours(image.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours = contours[1] if imutils.is_cv3() else contours[0]
    rects = [cv2.boundingRect(c) for c in contours]
    return rects


def extract_horizontal_dot_line(rects, thresh_horizontal=10):
    list_cnts = []
    for rect in rects:
        x, y, w, h = rect
        if w > thresh_horizontal and h < thresh_horizontal // 2:
            list_cnts.append(rect)

    return list_cnts


def extract_vertical_dot_line(rects, thresh_vertical=10):
    list_cnts = []
    for rect in rects:
        x, y, w, h = rect
        if h > thresh_vertical and w < thresh_vertical // 2:
            list_cnts.append(rect)

    return list_cnts


def intersection_box(a, b):
    x = max(a[0], b[0])
    y = max(a[1], b[1])
    w = min(a[0] + a[2], b[0] + b[2]) - x
    h = min(a[1] + a[3], b[1] + b[3]) - y
    if w < 0 or h < 0:
        return False
    else:
        return True


def intersection_boxes(main, ref, image=None):
    rs = []
    for box_m in main:
        valid = 0
        if box_m[3] > 50 or box_m[2] > 50:
            rs.append(box_m)
            valid = 2
        if valid == 2:
            pass
        else:
            for box_r in ref:
                if intersection_box(box_m, box_r):
                    valid += 1
                else:
                    if valid == 2:
                        rs.append(box_m)
                        break

    return rs


def expand_height_boxes(boxes, expand):
    rs = []
    for box in boxes:
        box = list(Utils.expand_height_rect(box, expand))
        rs.append(box)

    return rs


def expaned_width_boxes(boxes, expand):
    rs = []
    for box in boxes:
        box = list(Utils.expand_width_rect(box, expand))
        rs.append(box)

    return rs


def remove_padding_width(boxes, expand):
    rs = []
    for box in boxes:
        box_ = [box[0] + expand, box[1], box[2] - 2 * expand, box[3]]
        rs.append(box_)

    return rs


def remove_padding_height(boxes, expand):
    rs = []
    for box in boxes:
        box_ = [box[0], box[1] + expand, box[2], box[3] - 2 * expand]
        rs.append(box_)

    return rs


def dot_noise_blocks(image):
    """:returns: noise dot blocks"""
    not_image = cv2.bitwise_not(image)
    binary = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, -7)
    Utils.show_img('adap', binary)
    contours = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)[1]
    noise_image = np.zeros((image.shape), dtype=(np.uint8))
    for contour in contours:
        rect = cv2.boundingRect(contour)
        if rect[2] < 7 and rect[3] < 12 or rect[3] < 7 and rect[2] < 12:
            cv2.rectangle(noise_image, (rect[0], rect[1]), (rect[0] + rect[2], rect[1] + rect[3]), (255,
                                                                                                    255,
                                                                                                    255), 1)

    Utils.show_img('noise', noise_image)
    kernel_horizontal = np.ones((1, 20)) / 15
    filter_horizontal = cv2.filter2D(noise_image.copy(), -1, kernel_horizontal)
    Utils.show_img('filter', filter_horizontal)
    horizontal_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (50, 1))
    horizontal = cv2.erode(filter_horizontal, horizontal_structure)
    horizontal = cv2.dilate(horizontal, horizontal_structure)
    Utils.show_img('hori noise', horizontal)
    contours = cv2.findContours(horizontal, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)[1]
    horizontal_noise_boxes = [cv2.boundingRect(contour) for contour in contours]
    print('hori: ', len(horizontal_noise_boxes))
    kernel_vertical = np.ones((20, 1)) / 15
    filter_vertical = cv2.filter2D(noise_image.copy(), -1, kernel_vertical)
    vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 50))
    vertical = cv2.erode(filter_vertical, vertical_structure)
    vertical = cv2.dilate(vertical, vertical_structure)
    Utils.show_img('vert noise', vertical)
    contours = cv2.findContours(vertical, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)[1]
    vertical_noise_boxes = [cv2.boundingRect(contour) for contour in contours]
    print('vert: ', len(vertical_noise_boxes))
    noise_boxes = horizontal_noise_boxes + vertical_noise_boxes
    img = np.ones(image.shape) * 0
    Utils.draw_boxes(img, noise_boxes, 3)
    Utils.show_img('noise box', img)
    return noise_boxes


def dot_lines_image(no_line_image):
    """ Extract dot lines in image
        """
    kernel_horizontal = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 1))
    grad = cv2.morphologyEx(no_line_image, cv2.MORPH_GRADIENT, kernel_horizontal)
    _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    kernel_horizontal = cv2.getStructuringElement(cv2.MORPH_RECT, (20, 1))
    horizontal_dot_lines_image = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_horizontal)
    Utils.show_img('horiz dotline', binary)
    kernel_vertical = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 11))
    grad = cv2.morphologyEx(no_line_image, cv2.MORPH_GRADIENT, kernel_vertical)
    _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    kernel_vertical = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 20))
    vertical_dot_lines_image = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_vertical)
    Utils.show_img('vert dot line', vertical_dot_lines_image)
    return (
        horizontal_dot_lines_image, vertical_dot_lines_image)


def remove_vertical_text(src, image):
    vertical_size = 5
    blur_image = cv2.bilateralFilter(image, 9, 11, 3)
    not_image = cv2.bitwise_not(blur_image)
    binary_image = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 13, -7)
    Utils.show_img('binary', binary_image)
    vertical = binary_image.copy()
    src_copy = src.copy()
    vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vertical_size))
    Utils.show_img('vert', vertical)
    vertical = cv2.dilate(vertical, vertical_structure)
    Utils.show_img('vert 2', vertical)


def check_equal_box(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    if ax == bx:
        if ay == by:
            if aw == bw:
                if ah == bh:
                    return True
    return False


def lines_image(image, horizontal_size=80, vertical_size=40, src=None):
    """
        :param image:
        :param horizontal_size: the horizontal size to create structure element
        :param vertical_size: the vertical size to create structure element
        :return: horizontal line image, vertical line image, binary image from original image
        """
    Utils.show_img('origin', image)
    blur_image = cv2.bilateralFilter(image, 9, 11, 3)
    Utils.show_img('filter', blur_image)
    not_image = cv2.bitwise_not(blur_image)
    binary_image = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 13, -7)
    Utils.show_img('bin', binary_image)
    horizontal = binary_image.copy()
    vertical = binary_image.copy()
    horizontal_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (horizontal_size, 1))
    kernel = np.ones((1, 5), np.uint8)
    # horizontal = cv2.dilate(horizontal, kernel, iterations=1)
    horizontal = cv2.erode(horizontal, horizontal_structure)
    Utils.show_img(' horizontal erode', horizontal)
    kernel = np.ones((1, 50), np.uint8)
    horizontal = cv2.dilate(horizontal, kernel, iterations=1)
    # cv2.imshow("Image", horizontal)
    # cv2.waitKey(0)

    Utils.show_img(' horizontal dilate', horizontal)
    vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vertical_size))
    kernel = np.ones((5, 1), np.uint8)
    vertical = cv2.dilate(vertical, kernel, iterations=1)
    vertical = cv2.erode(vertical, vertical_structure)
    Utils.show_img('verti erode', vertical)
    vertical = cv2.dilate(vertical, vertical_structure)
    Utils.show_img('verti dilate', vertical)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (EXPAND, EXPAND))
    horizontal = cv2.morphologyEx(horizontal, cv2.MORPH_CLOSE, kernel)
    # cv2.imshow("Image", vertical)
    # cv2.waitKey(0)

    Utils.fill_rects(horizontal)
    Utils.fill_rects(vertical)
    Utils.show_img('horizontal image', horizontal)
    h_rects = find_rects(horizontal)
    v_rects = find_rects(vertical)
    padding = 3
    ex_hrects = expaned_width_boxes(h_rects, padding)
    ex_vrects = expand_height_boxes(v_rects, padding)
    rs_h = intersection_boxes(ex_hrects, v_rects, image.copy())
    rs_v = intersection_boxes(ex_vrects, h_rects)
    vert_lines = remove_padding_height(rs_v, padding)
    hori_lines = remove_padding_width(rs_h, padding)
    remove_hori = []
    for box in h_rects:
        found = False
        for box_h in hori_lines:
            if check_equal_box(box, box_h):
                found = True
                break

        if not found:
            remove_hori.append(box)

    remove_vert = []
    for box in v_rects:
        found = False
        for box_v in vert_lines:
            if check_equal_box(box, box_v):
                found = True
                break

        if not found:
            remove_vert.append(box)

    Utils.fill_boxes(horizontal, remove_hori, 0)
    Utils.fill_boxes(vertical, remove_vert, 0)
    horizontal = 255 - horizontal
    vertical = 255 - vertical
    src_hor = src.copy()
    Utils.draw_boxes(src_hor, remove_hori)
    Utils.show_img('src hor', src_hor)
    src_ver = src.copy()
    Utils.draw_boxes(src_ver, remove_vert)
    # Utils.show_img('src ver', src_ver)
    # Utils.show_img('hori', horizontal)
    # Utils.show_img('verti', vertical)
    # cv2.imshow("Image", vertical)
    # cv2.waitKey(0)
    return (horizontal, vertical, h_rects, v_rects)


def extract_dot_lines(image, lines_image, text_blocks, h_rects, v_rects):
    horizontal_size = 5
    vertical_size = 5
    no_lines = np.where(image == lines_image, 255, image)
    Utils.show_img('no line', no_lines)
    text_blocks = [Utils.expand_rect(text_block, 3) for text_block in text_blocks]
    no_text_and_line = Utils.fill_boxes(no_lines, text_blocks, (255, 255, 255))
    Utils.show_img('no text and line', no_text_and_line)
    no_text_and_line = cv2.cvtColor(no_text_and_line, cv2.COLOR_BGR2GRAY)
    blur_image = cv2.bilateralFilter(no_text_and_line, 9, 11, 3)
    blur_hori = cv2.blur(no_text_and_line, (15, 3))
    blur_vert = cv2.blur(no_text_and_line, (3, 15))
    not_image = cv2.bitwise_not(blur_image)
    blur_hori = cv2.bitwise_not(blur_hori)
    blur_vert = cv2.bitwise_not(blur_vert)
    binary_image = cv2.adaptiveThreshold(not_image, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 13, -7)
    binary_image_vert = cv2.adaptiveThreshold(blur_vert, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 15, -7)
    binary_image_hori = cv2.adaptiveThreshold(blur_hori, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 15, -7)
    horizontal = binary_image.copy()
    vertical = binary_image.copy()
    horizontal_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (horizontal_size, 1))
    vertical_structure = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vertical_size))
    binary_image_hori = cv2.dilate(binary_image_hori, horizontal_structure, iterations=2)
    Utils.show_img('blur hori dilate', binary_image)
    binary_image_hori = cv2.erode(binary_image_hori, horizontal_structure, iterations=1)
    binary_image_vert = cv2.dilate(binary_image_vert, vertical_structure, iterations=2)
    Utils.show_img('blur vert dilate', binary_image_vert)
    binary_image_vert = cv2.erode(binary_image_vert, vertical_structure, iterations=1)
    vert_rects = find_rects(binary_image_vert)
    hori_rects = find_rects(binary_image_hori)
    vert_dot_line = extract_vertical_dot_line(vert_rects)
    hori_dot_line = extract_horizontal_dot_line(hori_rects)
    padding = 5
    ex_hrects = expaned_width_boxes(hori_dot_line, padding)
    ex_vrects = expand_height_boxes(vert_dot_line, padding)
    rs_h = intersection_boxes(ex_hrects, v_rects)
    rs_v = intersection_boxes(ex_vrects, h_rects)
    hori_dot_line = remove_padding_width(rs_h, padding)
    vert_dot_line = remove_padding_height(rs_v, padding)
    src_hor = image.copy()
    Utils.draw_boxes(src_hor, rs_h)
    Utils.show_img('src hor dot', src_hor)
    src_ver = image.copy()
    Utils.draw_boxes(src_ver, rs_v)
    Utils.show_img('src ver dot', src_ver)
    blank_img = np.ones((image.shape[0], image.shape[1]))
    Utils.fill_boxes(blank_img, vert_dot_line)
    Utils.fill_boxes(blank_img, hori_dot_line)
    Utils.show_img('blank dot', blank_img)
    horizontal = 255 - horizontal
    vertical = 255 - vertical
    return blank_img.astype(np.uint8)


def extract_line_rect(image, remove_line_at_border=True):
    """
        :param image: The image contains horizontal lines or vertical lines.
        :param remove_line_at_border: True: remove the line reach to the border of image. False: Otherwise
        :return: Extract all line in the image
        """
    extract_line_image = image.copy()
    image_shape = image.shape
    PADDING_SIZE = 5
    extract_line_image = Utils.expand_image(extract_line_image, PADDING_SIZE)
    contours = cv2.findContours(extract_line_image.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[1]
    rects = [cv2.boundingRect(c) for c in contours]
    rects = [Utils.remove_padding_rect(rect, image_shape, PADDING_SIZE) for rect in rects if not Utils.is_noise(rect) if
             not (remove_line_at_border and Utils.line_at_border_image(rect, image_shape, PADDING_SIZE))]
    return [rect for rect in rects if rect[2] < 40 or rect[3] < 40]


def no_lines_image(image):
    """
        :param image:

        :return: the image without it's lines
        """
    horizontal, vertical, _ = lines_image(image, 40, 30)
    mark_image = ~horizontal + ~vertical
    Utils.show_img('mark', mark_image)
    kernel = np.ones((7, 7), np.uint8)
    mark_image = cv2.dilate(mark_image, kernel, iterations=1)
    Utils.show_img('mark1', mark_image)
    Utils.show_img('gray', image)
    no_lines_image = cv2.bitwise_or(image, mark_image)
    ret, binary = cv2.threshold(no_lines_image, 127, 255, cv2.THRESH_BINARY)
    Utils.show_img('binary', binary)
    return binary


def text_blocks(image):
    print('function: ', inspect.stack()[1][3])
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 11))
    grad = cv2.morphologyEx(image, cv2.MORPH_GRADIENT, kernel)
    _, binary = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1))
    connected = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
    _, contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    rects = [cv2.boundingRect(c) for c in contours]
    return [rect for rect in rects if rect[2] > 10 if rect[3] > 10]


def extract_line(src, image, text_block_rect):
    """
        :param image:
        :return: extract all of line from the image
        """
    horizontal_size = 30
    vertical_size = 25
    normal_width = 500
    ratio = image.shape[1] / (normal_width * 1.5)
    horizontal_size, vertical_size = horizontal_size * ratio, vertical_size * ratio
    horizontal, vertical, h_rects, v_rects = lines_image(image, int(horizontal_size), int(vertical_size), src.copy())
    # cv2.imshow("Image", horizontal)
    # cv2.waitKey(0)
    not_horizontal = (~horizontal).astype(np.int32)
    not_vertical = (~vertical).astype(np.int32)
    mark_image = np.clip(not_horizontal + not_vertical, 0, 255)
    mark_image = mark_image.astype(np.uint8)
    Utils.show_img('mark', mark_image)
    mark_image = cv2.cvtColor(mark_image, cv2.COLOR_GRAY2BGR)
    print('max value: ', np.max(mark_image))
    blank_img = np.where(mark_image == 255, src, 255)
    blank_img = blank_img.astype(np.uint8)

    # Utils.show_img('blank', blank_img)
    # if len(text_block_rect) > 0:
    #     dot_img = extract_dot_lines(src, blank_img, text_block_rect, h_rects, v_rects)
    #     mark_dot = ~dot_img
    #     mark_dot = cv2.cvtColor(mark_dot, cv2.COLOR_GRAY2BGR)
    #     blank_img = np.where(mark_dot == 255, src, blank_img)
    #     Utils.show_img('final', blank_img)
    # cv2.imshow("Image", blank_img)
    # cv2.waitKey(0)
    return blank_img


def process_table(src, json_data=None):
    gray = cv2.cvtColor(src, cv2.COLOR_BGR2GRAY)
    text_block_rects = []
    if json_data is not None:
        result = json_data['result']
        for box in result:
            x, y, w, h = (
                box['x'], box['y'], box['w'], box['h'])
            text_block_rects.append([x, y, w, h])

    rs = extract_line(src, gray, text_block_rects)
    # rs = extract_line_rect(src)
    return rs

# if __name__ == '__main__':
#     img_w = 580
#     json_path = 'data/origin/json/'
#     imgs_path = 'data/origin/imgs/0225'
#     files = glob.glob(os.path.join(imgs_path, '�A�菑��*'))
#     sub_folder = imgs_path.split(os.sep)[(-1)]
#     json_folder = os.path.join(json_path, sub_folder)
#     result_folder = 'data/result'
#     for file in files:
#         print(file)
#         img = cv2.imread(file)
#         fn = os.path.basename(file)
#         json_f = '%s.json' % os.path.splitext(fn)[0]
#         json_file = os.path.join(json_folder, json_f)
#         with open(json_file, 'r') as (file):
#             data = json.load(file)
#         rs = process_table(img, None)
#         save_folder = os.path.join(result_folder, sub_folder)
#         if not os.path.exists(save_folder):
#             os.mkdir(save_folder)
#         cv2.imwrite(os.path.join(save_folder, fn), rs)
# okay decompiling extract.pyc
