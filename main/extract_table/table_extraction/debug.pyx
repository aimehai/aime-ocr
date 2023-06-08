import cv2
import random
import os

class Debug(object):

    debug_save_path = "debug"

    debug_flag = 0

    # def set_debug_flag(flag):
    #     pass

    @staticmethod
    def show_image(image, name='output', height=1000):
        '''
        Show image for debugging
        '''
        scale = height / image.shape[0]
        image = cv2.resize(image, (0, 0), fx=scale, fy=scale)
        cv2.imshow(name, image)
        cv2.waitKey(0)

    @staticmethod
    def write_image(image, name):
        cv2.imwrite(name, image)
