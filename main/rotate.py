import cv2
import numpy as np


def rotate(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.bitwise_not(gray)
    thresh = cv2.threshold(gray, 50, 255,
                           cv2.THRESH_BINARY)[1]
    h, w = thresh.shape
    mask = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(thresh, mask, (w - 1, h - 1), 0)
    cv2.floodFill(thresh, mask, (0, h - 1), 0)
    cv2.floodFill(thresh, mask, (w - 1, 0), 0)
    cv2.floodFill(thresh, mask, (0, 0), 0)
    coords = np.column_stack(np.where(thresh > 200))
    angle = cv2.minAreaRect(coords)[-1]

    # rect = cv2.minAreaRect(coords)
    # box = cv2.boxPoints(rect)
    # box = np.int0(box)
    # new_image = cv2.drawContours(cv2.transpose(image),[box],0,(0,0,255),2)

    if angle < -45:
        angle = -(90 + angle)
    else:
        angle = -angle

    (h, w) = image.shape[:2]
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, angle, 1.0)
    rotated = cv2.warpAffine(image, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    return rotated

# img = cv2.imread('1.png')
# rotate(img)

# h = img.shape[0]
# w = img.shape[1]
# angle = 30
# print(angle)
# center = (w // 2, h // 2)
# M = cv2.getRotationMatrix2D(center, angle, 1.0)
# cos = np.abs(M[0, 0])
# sin = np.abs(M[0, 1])
# nW = int((h * sin) + (w * cos))
# nH = int((h * cos) + (w * sin))
# M[0, 2] += (nW / 2) - center[0]
# M[1, 2] += (nH / 2) - center[1]
# rotated = cv2.warpAffine(img, M, (nW, nH), flags=cv2.INTER_CUBIC, \
#           borderMode=cv2.BORDER_CONSTANT)

# # cv2.imshow('sss', rotated)
# cv2.imwrite('image_rotated.jpg', rotated)
# # cv2.waitKey(0)
