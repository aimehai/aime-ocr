import cv2
import numpy as np
import imutils
from operator import itemgetter

try:
    from PIL import Image
except ImportError:
    import Image


# import pytesseract


def sort_contours(cnts, method="left-to-right"):
    # initialize the reverse flag and sort index
    reverse = False
    i = 0
    # handle if we need to sort in reverse
    if method == "right-to-left" or method == "bottom-to-top":
        reverse = True
    # handle if we are sorting against the y-coordinate rather than
    # the x-coordinate of the bounding box
    if method == "top-to-bottom" or method == "bottom-to-top":
        i = 1
    # construct the list of bounding boxes and sort them from top to
    # bottom
    boundingBoxes = [cv2.boundingRect(c) for c in cnts]
    (cnts, boundingBoxes) = zip(*sorted(zip(cnts, boundingBoxes),
                                        key=lambda b: b[1][i], reverse=reverse))
    # return the list of sorted contours and bounding boxes
    return (cnts, boundingBoxes)


def merCol(boxes, img):
    d1 = []
    d2 = []

    def checkExits(x):
        for y in d2:
            if x[0] == y[0] and x[1] == y[1] and x[2] == y[2] and x[3] == y[3]:
                return True
        return False

    def find_col(x):
        d = []
        for b in boxes:
            if abs(x[0] - b[0]) <= img.shape[1] / 100:
                d.append(b)
                d2.append(b)
        d1.append(d)

    for b in boxes:
        if b not in d2:
            find_col(b)

    return d1


def check_key_in_box(box, json_data):
    res = []
    for x in json_data:
        minx = abs(float(x['x']) - (float(box[0]) + float(box[2])))
        miny = abs(float(x['y']) - (float(box[1]) + float(box[3])))
        if float(box[0]) < float(x['x']) < float(box[0]) + float(box[2]) and float(box[1]) < float(x['y']) < float(box[1]) + float(box[3]):
            res.append(x)
        elif float(box[0]) < float(x['x']) + float(x['w']) < float(box[0]) + float(box[2]) and float(box[1]) < float(x['y']) + float(x['h']) < float(
                box[1]) + float(box[3]):
            res.append(x)
    return res


def get_data(img, json_data):
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    img[img < 200] = 0
    thresh, img_bin = cv2.threshold(img, 127, 255, cv2.THRESH_TOZERO | cv2.THRESH_OTSU)
    img_bin = 255 - img_bin

    # countcol(width) of kernel as 100th of total width
    kernel_len = np.array(img).shape[1] // 100
    # Defining a vertical kernel to detect all vertical lines of image
    ver_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, kernel_len))
    # Defining a horizontal kernel to detect all horizontal lines of image
    hor_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_len, 1))
    # A kernel of 2x2
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))

    # Use vertical kernel to detect and save the vertical lines in a jpg
    k1 = np.ones((5, 1), np.uint8)
    image_1 = cv2.dilate(img_bin, k1, iterations=1)
    image_1 = cv2.erode(image_1, ver_kernel, iterations=3)
    vertical_lines = cv2.dilate(image_1, ver_kernel, iterations=3)

    # Use horizontal kernel to detect and save the horizontal lines in a jpg
    k2 = np.ones((1, 5), np.uint8)
    image_2 = cv2.dilate(img_bin, k2, iterations=1)
    image_2 = cv2.erode(image_2, hor_kernel, iterations=3)
    horizontal_lines = cv2.dilate(image_2, hor_kernel, iterations=3)
    horizontal_lines[horizontal_lines > 0] = 255

    img_vh = cv2.addWeighted(vertical_lines, 0.5, horizontal_lines, 0.5, 0.0)
    img_vh = cv2.erode(~img_vh, kernel, iterations=2)
    thresh, img_vh = cv2.threshold(img_vh, 127, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    bitxor = cv2.bitwise_xor(img, img_vh)
    bitnot = cv2.bitwise_not(bitxor)

    contours = cv2.findContours(img_vh, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours = imutils.grab_contours(contours)

    # Sort all the contours by top to bottom.
    contours, boundingBoxes = sort_contours(contours, method="top-to-bottom")

    # Creating a list of heights for all detected boxes
    heights = [boundingBoxes[i][3] for i in range(len(boundingBoxes))]

    # Get mean of heights
    mean = np.mean(heights)

    # Create list box to store all boxes in
    boxes = []
    # Get position (x,y), width and height for every contour and show the contour on image
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        if w < img.shape[1] / 1.5 and img.shape[0] / 5 > h > 5:
            boxes.append([x, y, w, h])

    m = sum([b[3] for b in boxes]) / len(boxes)
    boxes = [b for b in boxes if b[3] > m / 1.5]
    boxes = sorted(boxes, key=itemgetter(1, 0))

    boxes = merCol(boxes, img)
    result = {}

    for i, column in enumerate(boxes):
        result[i] = []
        for row in column:
            b = check_key_in_box(row, json_data)
            result[i].append(b)

    m = 0
    for x in result:
        if len(result[x]) > m:
            m = len(result[x])
    table = []
    for i in range(m):
        row = []
        for x in result:
            try:
                row.append(result[x][i])
            except Exception as e:
                pass
        table.append(row)

    result = {}
    key = []
    for i in range(len(table[0])):
        text = ''.join(y['text'] for y in table[0][i])
        key.append(text)
        result[text] = []

    m = len(key)
    for i in range(1, len(table)):
        if len(table[i]) >= m - 1:
            m = len(table[i])
            for j in range(len(table[i])):
                result[key[j]].extend(table[i][j])
        else:
            text = ''.join(y['text'] for y in table[i][0])
            result[text] = []
            for j in range(1, len(table[i])):
                result[text].extend(table[i][j])

    return result
