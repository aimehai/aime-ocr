import os
import sys
import json
import glob
import cv2
from extract import process_table
import numpy as np
import imutils
EXPAND = 5

# f = open('/home/son/Desktop/1/test/res.json', 'r')
# data = json.load(f)

# data = data['inv2-1']
img = cv2.imread('/home/son/Desktop/1/extract_table/inv1-1.jpg')
rs = process_table(img)

cv2.imwrite('out1.png', rs)