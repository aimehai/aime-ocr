from scipy.spatial import distance as dist
from imutils import perspective
from imutils import contours
import numpy as np
import imutils
import matplotlib.pyplot as plt
import cv2


# def find_largest_table(image):
#     # image = cv2.imread(image_path)
#     # print(image.shape)
#     gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
#     gray = cv2.GaussianBlur(gray, (7, 7), 0)
#
#     edged = cv2.Canny(gray, 50, 100)
#     edged = cv2.dilate(edged, None, iterations=1)
#     edged = cv2.erode(edged, None, iterations=1)
#
#     # find contours in the edge map
#     cnts = cv2.findContours(edged, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
#     print('----- contours -------: ', len(cnts))
#     cv2.drawContours(edged, cnts[0], -1, (0, 255, 0), 3)
#     # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(6)find_largest_table_contours.png', edged)
#
#     cnts = imutils.grab_contours(cnts)
#     (cnts, _) = contours.sort_contours(cnts)
#     pixelsPerMetric = None
#     max_w = 0
#     max_h = 0
#     max_table = None
#
#     for c in cnts:
#         if cv2.contourArea(c) < 100:
#             continue
#
#         box = cv2.minAreaRect(c)
#         box = cv2.cv.BoxPoints(box) if imutils.is_cv2() else cv2.boxPoints(box)
#         box = np.array(box, dtype="int")
#         box = perspective.order_points(box)
#
#         if (box[2][1] - box[0][1]) >= image.shape[1] / 3 and (box[1][0] - box[0][0]) > image.shape[0] / 3:
#             if (box[2][1] - box[0][1]) >= max_h and (box[1][0] - box[0][0]) >= max_w:
#                 max_w = (box[1][0] - box[0][0])
#                 max_h = (box[2][1] - box[0][1])
#                 max_table = box
#     return max_table if max_table is not None else None
#     # rgb_color = (255, 255, 255)
#     # orig = np.zeros(image.shape, np.uint8)
#     # for (x, y) in max_table:
#     #     cv2.circle(orig, (int(x), int(y)), 5, (0, 0, 255), -1)
#     # # color = tuple(reversed(rgb_color))
#     # orig[:] = rgb_color
#     #
#     # roi = image[int(max_table[0][1]):int(max_table[2][1]), int(max_table[0][0]):int(max_table[1][0])]
#     # orig[int(max_table[0][1]):int(max_table[2][1]), int(max_table[0][0]):int(max_table[1][0])] = roi
#     # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(7)find_largest_table_result.png', orig)
#     # return orig

def find_largest_table(image):
    # image = cv2.imread(image_path)
    # print(image.shape)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(0)find_largest_table_original.png', image)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(1)find_largest_table_grayscale.png', gray)
    gray = cv2.GaussianBlur(gray, (7, 7), 0)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(2)find_largest_table_gaussian_blur.png', gray)

    # med_val = np.median(image)
    # lower = int(max(0, 0.7 * med_val))
    # upper = int(min(255, 1.3 * med_val))
    # edged = cv2.Canny(gray, lower, upper)

    edged = cv2.Canny(gray, 50, 100)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(3)find_largest_table_canny_getedge.png', edged)
    edged = cv2.dilate(edged, None, iterations=1)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(4)find_largest_table_dilation.png', edged)
    edged = cv2.erode(edged, None, iterations=1)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(5)find_largest_table_erosion.png', edged)

    # find contours in the edge map

    cnts = cv2.findContours(edged, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    # cv2.imshow('canny edges after contouring', edged)
    # print('----- contours -------: ', len(cnts[0]))
    # print(cnts[0])
    # cv2.drawContours(image, cnts[0], -1, (0, 255, 0), 3)
    # cv2.imwrite('/home/phucnp/aimenext/aime-ocr/test/img/(6)find_largest_table_contours.png', edged)

    # cv2.imshow('contours', image)
    # cv2.waitKey(0)
    # cv2.destroyAllWindows()

    cnts = imutils.grab_contours(cnts)
    (cnts, _) = contours.sort_contours(cnts)
    pixelsPerMetric = None
    max_w = 0
    max_h = 0
    max_table = None
    IMGW, IMGH = image.shape[1], image.shape[0]
    for idx, c in enumerate(cnts):
        if cv2.contourArea(c) < 1000:
            continue

        box = cv2.minAreaRect(c)
        box = cv2.cv.BoxPoints(box) if imutils.is_cv2() else cv2.boxPoints(box)
        box = np.array(box, dtype="int")
        box = perspective.order_points(box)
        # print('---contour {}     box: \n   --->   {}'.format(i,box))
        # if (box[2][1] - box[0][1]) >= 5*IMGW / 6 and (box[1][0] - box[0][0]) >= IMGH / 3:
        #     continue
        if (box[2][1] - box[0][1]) >= image.shape[1] / 3 and (box[1][0] - box[0][0]) > image.shape[0] / 3:
            if (box[2][1] - box[0][1]) >= max_h and (box[1][0] - box[0][0]) >= max_w:
                max_w = (box[1][0] - box[0][0])
                max_h = (box[2][1] - box[0][1])
                max_table = box

    # rgb_color = (255, 255, 255)
    # orig = np.zeros(image.shape, np.uint8)
    return max_table if max_table is not None else None

# find_largest_table()