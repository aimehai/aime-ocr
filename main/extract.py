import cv2
from main.object_size import find_largest_table
from main.getdata import get_data
from main.extract_table import extract
from main import db
from main.models import *
import math
import re
import numpy as np
import json

imgh = None
imgw = None
orig_img = None
inverted_img = None
largest_table = None

occupied = {}
thickness = []
MAX = 1e9
pattern_jp = r'^[ぁ-んァ-ン一-龥]+$'


# def merge_box(x1, x2):
#     x = x1
#     x['y'] = min(x1['y'], x2['y'])
#     x['h'] = x2['y'] + x2['h'] - x1['y'] if x1['y'] + x1['h'] < x2['y'] + x2['h'] else x1['y'] + x1['h'] - x2['y']
#     x['x'] = min(x1['x'], x2['x'])
#     x['w'] = x2['x'] + x2['w'] - x1['x'] if x1['x'] + x1['w'] <= x2['x'] + x2['w'] else x1['x'] + x1['w'] - x2['x']
#     x['text'] = x1['text'] + x2['text']
#     return x

def inRow(box1, box2):
    global imgw, imgh
    if box1['id'] == box2['id']:
        return True
    if abs((box1['y'] + box1['h'] / 2) - (box2['y'] + box2['h'] / 2)) < imgh / 100 and (
            box1['x'] >= imgw / 2 or abs(box2['x'] - box1['x']) < imgw / 4):
        return True
    return False


def inCol(box1, box2):
    global imgw, imgh
    if box1['id'] == box2['id']:
        return True
    if abs((box1['x'] + box1['w'] / 2) - (box2['x'] + box2['w'] / 2)) < imgw / 100:
        return True
    return False


def inLeft(box1, box2):  # x1 <= x2 => box1 bên trái box2
    global imgw, imgh
    if box1['x'] >= box2['x']:
        return False
    return True


def find_relate(boxes, b, left=True, row=True, include=False):
    related = []
    global imgw, imgh, occupied
    for box in boxes:
        if not include:
            if box['id'] != b['id']:
                if left and inLeft(b, box):
                    if row and inRow(b, box):
                        related.append(box)
                    if not row and inCol(b, box):
                        related.append(box)
                if not left and not inLeft(b, box):
                    if row and inRow(b, box):
                        related.append(box)
                    if not row and inCol(b, box):
                        related.append(box)
        else:
            if left and inLeft(b, box):
                if row and inRow(b, box):
                    related.append(box)
                if not row and inCol(b, box):
                    related.append(box)
            if not left and not inLeft(b, box):
                if row and inRow(b, box):
                    related.append(box)
                if not row and inCol(b, box):
                    related.append(box)
    return related


def check_duplicate(box, li):
    for l in li:
        if box['id'] == l['id']:
            return True
    return False


# def merge(data):
#     r = data[0]
#     for i in range(1, len(data)):
#         r = merge_box(r, data[i])
#     return [r]


def left_not_overlap(box, b_key):
    if box['x'] + box['w'] <= b_key['x']:
        return True
    return False


def right_not_overlap(box, b_key):
    if b_key['x'] + b_key['w'] <= box['x']:
        return True
    return False


def below_not_overlap(box, b_key):
    if b_key['y'] + b_key['h'] <= box['y']:
        return True
    return False


def above_not_overlap(box, b_key):
    if box['y'] + box['h'] <= b_key['y']:
        return True
    return False


def in_row(box, b_key):
    global imgh
    if abs((box['y'] + box['h'] / 2) - (b_key['y'] + b_key['h'] / 2)) < imgh / 100:
        return True
    return False


def in_col(box, b_key, remainder=0.15):
    # if abs((box['x'] + box['w'] / 2) - (b_key['x'] + b_key['w'] / 2)) < imgw / 20:
    #     return True
    # return False
    if box['x'] < b_key['x']:
        return True if box['x'] + box['w'] - b_key['x'] > remainder * b_key['w'] else False
    else:
        return True if b_key['x'] + b_key['w'] - box['x'] > remainder * b_key['w'] else False


def in_table(box):
    global largest_table
    if box['x'] >= largest_table['x1'] and box['x']+box['w'] <= largest_table['x2']:
        if box['y'] >= largest_table['y1'] and box['y']+box['h'] <= largest_table['y2']:
            return True
    return False


def merge_box(b1, b2=None, key=False, merge_char=' || '):
    global occupied
    b = b1.copy()
    if b2 is not None:
        x1, y1, x2, y2 = min(b1['x'], b2['x']), min(b1['y'], b2['y']), max(b1['x']+b1['w'], b2['x']+b2['w']), max(b1['y']+b1['h'], b2['y']+b2['h'])
        b['x'] = x1
        b['y'] = y1
        b['w'] = x2 - x1
        b['h'] = y2 - y1
        b['occupy_list'] = b2['occupy_list']
        b['occupy_list'].append(b1['id'])
        b['text'] = b2['text'] + merge_char + b1['text'] if not key else b1['text']
        b['prob'] = b1['prob'] * b2['prob']
    return b


def search_best_with_position(position, boxes, b_key):
    global MAX
    # print('---key----: id: {}   with text: {}'.format(b_key['id'], b_key['text']))
    # print('------ NEAREST {} is -------: '.format(position), len(right_row_boxes))
    # print('--- Boxes in position: {} '.format(position))
    # for b in boxes:
    #     print('    id {} -  {}'.format(b['id'], b['text']))
    nearest_box, min_tan, min_disx, min_disy = None, MAX, MAX, MAX
    for b in boxes:
        if position == 'left':
            dis_x = b_key['x'] - (b['x'] + b['w'])
            dis_y = abs((b['y'] + b['h'] / 2) - (b_key['y'] + b_key['h'] / 2))
        elif position == 'right':
            dis_x = b['x'] - (b_key['x'] + b_key['w'])
            dis_y = abs((b['y'] + b['h'] / 2) - (b_key['y'] + b_key['h'] / 2))
        elif position == 'below':
            dis_x = abs((b['x'] + b['w'] / 2) - (b_key['x'] + b_key['w'] / 2))
            dis_y = b['y'] - (b_key['y'] + b_key['h'])
        else:
            dis_x = abs((b['x'] + b['w'] / 2) - (b_key['x'] + b_key['w'] / 2))
            dis_y = b_key['y'] - (b['y'] + b['h'])

        tan_alpha = dis_y / (dis_x + 0.0001) if position in ['left', 'right'] else dis_y
        if tan_alpha < 0.05:  # < 2 độ
            if dis_x < min_disx and dis_y < min_disy:
                nearest_box, min_tan, min_disx, min_disy = b, tan_alpha, dis_x, dis_y
        else:  # > 2 độ
            if tan_alpha < min_tan:
                nearest_box, min_tan, min_disx, min_disy = b, tan_alpha, dis_x, dis_y
            if tan_alpha == min_tan:
                if position in ['below', 'above'] and dis_y < min_disy or position in ['left',
                                                                                       'right'] and dis_x < min_disx:
                    nearest_box, min_tan, min_disx, min_disy = b, tan_alpha, dis_x, dis_y

    # if nearest_box is not None:
    #     print('-------> The nearest {} is:   {}    , with id:  {} '.format(position, nearest_box['text'],
    #                                                                        nearest_box['id']))
    # else:
    #     print('-------> The nearest {} is:   NONE'.format(position))
    return nearest_box


def find_first_left(boxes, b_key):
    # Tìm tập boxes ở bên trái trước, sau đó tìm box có row "gần" nhất:
    left_row_boxes = []
    for b in boxes:
        if b['id'] != b_key['id'] and left_not_overlap(b, b_key) and in_row(b, b_key) and len(b['text']) and not \
        occupied[b['id']]:
            left_row_boxes.append(b)
    return search_best_with_position(position='left', boxes=left_row_boxes, b_key=b_key)


def find_first_right(boxes, b_key):
    # Tìm tập boxes ở bên phải và cùng cột trước, sau đó tìm box có row "gần" nhất:
    right_row_boxes = []
    for b in boxes:
        if b['id'] != b_key['id'] and right_not_overlap(b, b_key) and in_row(b, b_key) and len(b['text']) and not \
        occupied[b['id']]:
            right_row_boxes.append(b)
    return search_best_with_position(position='right', boxes=right_row_boxes, b_key=b_key)


def find_first_below(boxes, b_key, remainder=0.15):
    below_col_boxes = []
    for b in boxes:
        if b['id'] != b_key['id'] and below_not_overlap(b, b_key) and in_col(b, b_key, remainder) and len(b['text']) and not occupied[b['id']]:
            below_col_boxes.append(b)
    return search_best_with_position(position='below', boxes=below_col_boxes, b_key=b_key)


def find_first_above(boxes, b_key, remainder=0.15):
    above_col_boxes = []
    for b in boxes:
        if b['id'] != b_key['id'] and above_not_overlap(b, b_key) and in_col(b, b_key, remainder) and len(b['text']) and not \
        occupied[b['id']]:
            above_col_boxes.append(b)
    return search_best_with_position(position='above', boxes=above_col_boxes, b_key=b_key)


# boxes:
def find_value(field, key, b_key, boxes, include=False):
    global imgw, imgh, largest_table
    # Ngày hạn thanh toán:
    res = None

    def get_value_detail_field(field_, bboxes, k_box):
        LINE_SPACING_HEADER = 2
        LINE_SPACING_CONTENT = 1.75
        if field_ == '数量' or field == '明細件名':
            below_bx = find_first_below(bboxes, k_box, remainder=0)
        else:
            below_bx = find_first_below(bboxes, k_box, remainder=0.15)
        pattern_date_1 = r'[\d]+/[\d]+'
        pattern_date_2 = r'年?[\d]+月[\d]+日'
        pattern_date_3 = r'^[\d]{4}[\d\/\s]+$'
        pattern_price = r'^¥?\s?\d?[\d\s\,\.\-]+円?[A-Za-z\sぁ-んァ-ン一-龥]?[^A-Za-z\sぁ-んァ-ン一-龥]*$'       # Thêm [A-Za-z\sぁ-んァ-ン一-龥]? đề phòng trường hợp sai
        pattern_amount = r'^[\d,.]+$'
        if below_bx is not None:
            if field_ == '明細件名':
                LINE_SPACING_HEADER = 1.5
                LINE_SPACING_CONTENT = 1
                NUM_TAKEN = 20
                if not in_table(below_bx):
                    return None, 0
            elif field_ == '明細日付':
                LINE_SPACING_HEADER = 2
                LINE_SPACING_CONTENT = 1.75
                if re.search(pattern_date_1, below_bx['text']) is None and re.search(pattern_date_2, below_bx['text']) is None and re.search(pattern_date_3, below_bx['text']) is None:
                    return None, 0
            elif field_ in ['単価', '明細金額', '消費税等']:
                LINE_SPACING_HEADER = 2.75
                LINE_SPACING_CONTENT = 1.75
                if re.search(pattern_price, below_bx['text']) is None:
                    return None, 0
            elif field_ == '数量':
                LINE_SPACING_HEADER = 2.75
                LINE_SPACING_CONTENT = 1.75
                if re.search(pattern_amount, below_bx['text']) is None:
                    return None, 0

            # print('--- distance: ', below_bx['y'] - (k_box['y'] + k_box['h']) - LINE_SPACING_HEADER * k_box['h'])
            if below_bx['y'] - (k_box['y'] + k_box['h']) < LINE_SPACING_HEADER * k_box['h']:                # occupy?
                kbox_copy = k_box.copy()
                kbox_copy['occupy_list'] = [kbox_copy['id']]
                result = merge_box(below_bx.copy(), kbox_copy, True)
                cnt_row = 1
                pre = below_bx.copy()
                while True:
                    if field_ == '数量' or field == '明細件名':
                        cur = find_first_below(bboxes, pre, remainder=0)
                    else:
                        cur = find_first_below(bboxes, pre, remainder=0.15)

                    if cur is None or cur['y'] - (pre['y'] + pre['h']) > LINE_SPACING_CONTENT * pre['h']:
                        break
                    if field_ == '明細日付' and re.search(pattern_date_1, cur['text']) is None and re.search(pattern_date_2, cur['text']) is None and re.search(pattern_date_3, cur['text']) is None:
                        break
                    if field_ in ['単価', '明細金額', '消費税等'] and re.search(pattern_price, cur['text']) is None:
                        break
                    if field_ == '数量' and re.search(pattern_amount, cur['text']) is None:
                        break
                    if field_ == '明細件名':
                        if cnt_row > NUM_TAKEN or not in_table(cur):
                            break
                    result = merge_box(cur, result)
                    pre = cur.copy()
                    cnt_row += 1
                return result, cnt_row
        return None, 0

    if field == '請求番号':
        pattern_noinvoice = '^[A-Za-z\d\-]+$'
        special_char = r'~!@#$%^&*()<>?/\{}:; '+'"'+"'"
        if include:
            text = b_key['text'].replace(key, '')
            for c in special_char:
                text = text.replace(c, '')
            if re.search(pattern_noinvoice, text) is not None:
                return b_key
        right_box = find_first_right(boxes, b_key)
        if right_box is not None and re.search(pattern_noinvoice, right_box['text']) is not None:
            return right_box

    elif field == '支払日付':
        if include:
            if b_key['text'].startswith(key) and re.search(r'\d\d?\s?月\s?\d\d?\s?日', b_key['text']) is not None:
                return b_key
        right_box = find_first_right(boxes, b_key)
        below_box = find_first_below(boxes, b_key)
        pattern_date = r'[\d翌]\d?\s?月\s?\d\d?\s?日'  # 翌: tháng sau
        pattern_date_2_ = r'\d*年\s?\d\d?\s?月'
        pattern_date_3_ = r'\d{4}\/\d+\/\d+'
        if right_box is not None:
            if re.search(pattern_date, right_box['text']) is not None or re.search(pattern_date_2_, right_box['text']) is not None or re.search(pattern_date_3_, right_box['text']) is not None:
                return right_box
        if below_box is not None:
            if re.search(pattern_date, below_box['text']) is not None or re.search(pattern_date_2_, below_box['text']) is not None or re.search(pattern_date_3_, below_box['text']) is not None:
                return below_box
    # Công ty A
    elif field == '取引先（A）':
        if include:
            if b_key['text'].endswith(key):
                return b_key
        left_box = find_first_left(boxes, b_key)
        if left_box is not None:
            if not include or b_key['x'] - (left_box['x'] + left_box['w']) < imgw / 20:
                return left_box
    # Công ty B
    elif field == '取引先（B）':  # key: 株式会社
        if include:
            b_key['text'] = b_key['text'].strip(' ')
            if b_key['text'].startswith(key) or b_key['text'].endswith(
                    key):  # xét endswith '株式会' vì có thể bị mất chữ do con dấu
                return b_key
        else:
            right_box = find_first_right(boxes, b_key)
            if right_box is not None:
                return right_box
    elif field == '請求日付':
        pattern_date_1_ = r'\d{4}\s?年'
        pattern_date_2_ = r'\d{4}\/\d+\/\d+'
        if include:
            b_key['text'] = b_key['text'].strip(' ,.')
            if re.search(pattern_date_1_, b_key['text']) is not None or re.search(pattern_date_2_, b_key['text']) is not None:
                return b_key
        right_box = find_first_right(boxes, b_key)
        if right_box is not None:
            if re.search(pattern_date_1_, right_box['text']) is not None or re.search(pattern_date_2_, right_box['text']) is not None:
                return right_box

    elif field == '合計金額':
        right_box = find_first_right(boxes, b_key)
        below_box = find_first_below(boxes, b_key)
        pattern_price_ = r'^¥?\s?\d?[\d\s\,\.\-]+円?[^A-Za-z\sぁ-んァ-ン一-龥]*$'
        # if right_box is not None:
        #     print('-------- Tổng tiền --------', 'id ', b_key['id'], 'right id', right_box['id'])
        # print('-----key-----: ', key)
        if right_box is not None and re.search(pattern_price_, right_box['text']) is not None and right_box['x'] - (
                b_key['x'] + b_key['w']) < imgw / 3:
            right_box['position'] = 'right'
            return right_box
        if below_box is not None and re.search(pattern_price_, below_box['text']) is not None and below_box['y'] - (
                b_key['y'] + b_key['h']) < imgh / 6:
            below_of_below = find_first_below(boxes, below_box)
            if below_of_below is not None and re.search(pattern_price_, below_of_below['text']) is None:
                dis = below_of_below['y'] - (below_box['y'] + below_box['h'])
                if dis < 3 * below_box['h']:
                    below_box['position'] = 'below'
                    return below_box

    elif field == '消費税額' or field == '消費税額（10%）' or field == '消費税額（8%）' or field == '小計':
        if include:
            text = b_key['text'].replace(key, '')
            pattern_include_price = r'([\d\s,.]+)円?[^%]?$'          # Bỏ đi %
            res = re.search(pattern_include_price, text)
            if res is not None:
                if len(res.groups()[0]) >= 3:
                    b_key['text'] = res.groups()[0]
                    b_key['position'] = 'right'
                    return b_key

        right_box = find_first_right(boxes, b_key)
        below_box = find_first_below(boxes, b_key)
        pattern_price_ = r'^[\(\s¥]?\d?[\d\s\,\.\-]+円?[^A-Za-z\s\(ぁ-んァ-ン一-龥]*$'  # Cuối text bỏ (
        # if right_box is not None:
        #     print('-------- Tổng tiền --------', 'id ', b_key['id'], 'right id', right_box['id'])
        # print('-----key-----: ', key, field)
        if right_box is not None and re.search(pattern_price_, right_box['text']) is not None:
            right_box['position'] = 'right'
            # print('------ Result is: id {}       with text  {}     position RIGHT'.format(right_box['id'],
            #                                                                               right_box['text']))
            pattern_percent = r'(8|10)[,.0]*%'
            if field != '小計' and re.search(pattern_percent, right_box['text']) is not None and len(right_box['text']) <= 8:
                rright_box = find_first_right(boxes, right_box)
                if rright_box is not None and re.search(pattern_price_, rright_box['text']) is not None:
                    rright_box['position'] = 'right'
                    return rright_box
            return right_box
        if below_box is not None and re.search(pattern_price_, below_box['text']) is not None:
            below_of_below = find_first_below(boxes, below_box)
            # if below_of_below is not None:
            #     print('---> my text:  {}'.format(below_of_below['text']))
            #     print('---> Search: ', re.search(pattern_price_, below_of_below['text']))
            if below_of_below is not None and re.search(pattern_price_, below_of_below['text']) is None:
                dis = below_of_below['y'] - (below_box['y'] + below_box['h'])
                if dis < 3 * below_box['h']:
                    # print('------ Result is: id {}       with text  {}     position BELOW'.format(below_box['id'],
                    #                                                                               below_box['text']))
                    below_box['position'] = 'below'
                    return below_box
    # Nội dung hoá đơn cụ thể:                      ----> Trong bảng tốt nhất nên sử dụng table : Nội dung, ngày tháng, đơn giá, thành tiền, thuế
    elif field == '明細件名' or field == '明細日付' or field == '単価' or field == '明細金額' or field == '消費税等' or field == '数量':
        if not b_key['text'].startswith(key) and not b_key['text'].endswith(key):
            return None, 0
        if field == '明細件名':                                                  # Hạn chế box key tìm được
            if largest_table is None or len(b_key['text']) > 3*len(key) or not in_table(b_key):
                return None, 0

        return get_value_detail_field(field, boxes, b_key)
    return None


def get_value(field, boxes, keys, left=True, row=True, include=False):
    global imgw, imgh, occupied
    if field == '請求書基本情報':
        return find_header(boxes)
    # print(occupied)
    result = None
    tmp_B = {}
    tmp_total = {}
    tmp_tax = {}
    tmp_detail = []
    for key in keys:
        for idx, box in enumerate(boxes):
            if key == box['text']:
                print('\n----- Equalkey ----- ', key, '-----', field)
                b = find_value(field, key, box, boxes, include=False)
                # Đối với các trường Detail thì cần thêm so sánh 1 lượng row
                if field == '明細件名' or field == '明細日付' or field == '単価' or field == '明細金額' or field == '消費税等' or field == '数量':
                    if b[0] is not None and len(b[0]['text']):
                        tmp_detail.append((b[0], b[1]))

                else:
                    if b is not None and len(b['text']):
                        if field == '取引先（B）':
                            tmp_B[b['id']] = (b['text'], key)
                            continue

                        result = [[b]]
                        occupied[b['id']] = True
                        occupied[box['id']] = True
                        return result
            else:
                if key in box['text']:  # Key là substring của text ===> Có thể có nhiều text thỏa mãn, nên viết thêm 1 hàm để chọn box phù hợp
                    print('\n----- Subkey ----- ', key, '-----', field)
                    b = find_value(field, key, box, boxes, include=True)

                    if field == '明細件名' or field == '明細日付' or field == '単価' or field == '明細金額' or field == '消費税等' or field == '数量':
                        if b[0] is not None and len(b[0]['text']):
                            tmp_detail.append((b[0], b[1]))
                    else:
                        if b is not None and len(b['text']):
                            if field == '取引先（B）':
                                tmp_B[b['id']] = (b['text'], key)
                                continue
                            if field == '合計金額':
                                tmp_total[b['id']] = (b['text'], key)
                                continue
                            if field == '消費税額' or field == '消費税額（10%）' or field == '消費税額（8%）':
                                tmp_tax[b['id']] = (b['position'], key)
                                continue

                            replacement = [key, ':', ' ']
                            for s in replacement:
                                b['text'] = b['text'].replace(s, '')
                            result = [[b]]
                            occupied[b['id']] = True
                            occupied[box['id']] = True
                            return result
    if field == '明細件名' or field == '明細日付' or field == '単価' or field == '明細金額' or field == '消費税等' or field == '数量':
        res, max_cnt = None, -1
        # print(countss())
        for r in tmp_detail:
            b, cnt_row = r[0], r[1]
            if max_cnt < cnt_row:
                res = b
                max_cnt = cnt_row
        if res is None:
            return None
        for idx_occupy in res['occupy_list']:           # Tìm box merge được nhiều nhất, đồng thời đánh dấu occupy, nếu ko muốn lấy nhiều nhất thì có thể lấy merge_box đầu tiên
            occupied[idx_occupy] = True
        res.pop('occupy_list')
        # print(countss())
        return [[res]]
    elif field == '取引先（B）' and len(tmp_B) > 0:  # Công ty B
        tmp = None
        for k, v in tmp_B.items():
            if v[0].endswith(v[1]):
                idx = find_index(k, boxes)
                result = [[boxes[idx]]]
                occupied[boxes[idx]['id']] = True
                return result
            elif tmp is None and v[0].startswith(v[1]):
                tmp = find_index(int(k), boxes)
        if tmp is not None:
            result = [[boxes[tmp]]]
            # occupied[boxes[tmp]['id']] = True
        else:
            idx = find_index(int(list(tmp_B.keys())[0]), boxes)
            result = [[boxes[idx]]]
            # occupied[boxes[idx]['id']] = True

    elif field == '合計金額' and len(tmp_total) > 0:  # Tổng tiền
        result = get_result_from_arr(field, tmp_total, boxes)
    elif len(tmp_tax) > 0:
        if field == '消費税額' or field == '消費税額（10%）' or field == '消費税額（8%）':  # Thuế tiêu dùng
            result = get_result_from_arr(field, tmp_tax, boxes)

    if result is not None:
        occupied[result[0][0]['id']] = True
    return result


def find_mean_height(boxes):
    height = []
    for b in boxes:
        if len(b['text']):
            height.append(b['h'])
    mean = sum(height) / len(height)
    return mean

def find_header(boxes):     # Header kết hợp từ size và font_bold, trong đó font_bold important hơn size IMPORTANT lần
    global imgw, imgh, orig_img, inverted_img
    LOWERBOUND_SIZE = 1
    UPPERBOUND_SIZE = 3
    IMPORTANT = 1.5
    special_char = '●~!@#$%^&*()_-+=<>/,.":;[]{}'
    pattern_header = r'^[ぁ-んァ-ン一-龥\sー]+$'

    mean = find_mean_height(boxes)
    candidates = []
    for b in boxes:
        if 3 <= len(b['text']) <= 15 and re.search(pattern_header, b['text']) is not None and LOWERBOUND_SIZE < b['h']/mean < UPPERBOUND_SIZE and b['y'] < 3*imgh/4:
            thick = calculate_thickness(b['x'], b['y'], b['w'], b['h'])
            candidates.append((b['h'] / mean, thick, b['id'], b['text']))
    # candidates = sorted(candidates, key=lambda k:(k[0], k[1], k[2]), reverse=True)
    IMPORTANT = 1.5
    res, max_score = None, -1
    max_thick = max([-1]+[b[1] for b in candidates])
    for b in candidates:
        # print('  score:  "{:.6f}"  -   thick: "{:.6f}"   -   id: {}   -   text: {}'.format(b[0], b[1], b[2], b[3]))
        size_text = b[0]
        weight_bold = b[1]
        # if b[1] < 1e-6:
        #     weight_bold = max_thick
        score = size_text + IMPORTANT * weight_bold
        if max_score < score:
            max_score = score
            res = b
    if res is not None:
        # print(' HEADER:  id: {}   -   text: {}'.format(res[2], res[3]))
        idx = find_index(res[2], boxes)
        return [[boxes[idx]]]
    return None


def get_result_from_arr(field, dicts, boxes):
    result, tmp = None, None
    # if field == '合計金額':
    #     for k, v in dicts.items():
    #         print(k, v[0], '     key ', v[1])
    if field == '合計金額':         # Ưu tiên 1 số key
        for key in ['合計', '合計金額']:
            for k, v in dicts.items():
                if v[0] == 'right' and v[1] == key:
                    idx = find_index(k, boxes)
                    result = [[boxes[idx]]]
                    return result

    for k, v in dicts.items():
        if v[0] == 'right':
            idx = find_index(k, boxes)
            result = [[boxes[idx]]]
            return result
        elif tmp is None and v[0] == 'below':
            tmp = find_index(int(k), boxes)
    if tmp is not None:
        result = [[boxes[tmp]]]
    else:
        idx = find_index(int(list(dicts.keys())[0]), boxes)
        result = [[boxes[idx]]]
    return result


def find_index(id, boxes):
    for idx, box in enumerate(boxes):
        if id == box['id']:
            return idx
    return -1


def add_space(keys=None):
    res = keys[:]
    for key in keys:
        if len(key) == 2:
            res.append(key[0] + ' ' + key[1])
    return res


def countss():
    global occupied
    cnt = []
    for x, v in occupied.items():
        if v:
            cnt.append(x)
    return cnt


def calculate_thickness(x, y, w, h):
    global orig_img, inverted_img
    inverted_ = inverted_img[y:y + h + 1, x:x + w + 1]
    img_ = orig_img[y:y + h + 1, x:x + w + 1]
    # use_invert = True  # Sử dụng invert khi background: white (255), font: black (0)
    # Sử dụng img (không convert) khi background: black (0), font: white (255)
    img_array = np.array(img_)
    cnt_white_col = 0
    cnt_black_col = 0
    for col in img_array.T:
        white_col = all([p == 255 for p in col])
        black_col = all([p == 0 for p in col])
        cnt_white_col += 1 if white_col else 0
        cnt_black_col += 1 if black_col else 0
    # print('---- id: {}    ----- BLACK COL: '.format(id), cnt_black_col)
    # print('                     WHITE COL: ', cnt_white_col)
    # print('                     ALL COL: ', w)
    use_invert = True if cnt_white_col >= cnt_black_col else False
    inverted_ = inverted_ if use_invert else img_

    thinned = cv2.ximgproc.thinning(inverted_)
    num_thin, num_invert = 0, 0
    for r in inverted_:
        for pixel in r:
            num_invert += 1 if pixel == 255 else 0
    for r in thinned:
        for pixel in r:
            num_thin += 1 if pixel == 255 else 0
    # Compute thickness:
    thickness_ = (num_invert - num_thin) / num_thin if num_thin else 0
    # Normalize:
    # thickness /= 255
    return thickness_



def post_process(result, boxes):
    global occupied, imgw, imgh
    if result['請求日付'] is None:       # Nếu chưa có giá trị thì chọn 1 box mang ngày tháng:
        pattern_date = '^[\d]+年[\d]+月[\d]+日$'
        for b in boxes:
            if not occupied[b['id']] and b['y'] < imgh/4 and re.search(pattern_date, b['text']):
                result['請求日付'] = [[b]]
                occupied[b['id']] = True
                break
    if result['請求番号'] is None:
        pattern_noinvoice = r'^[A-Za-z0-9\-\,\.]$'
        for b in boxes:
            if not occupied[b['id']] and b['y'] < imgh/8 and re.search(pattern_noinvoice, b['text']) and len(b['text']) >= 6:
                result['請求番号'] = [[b]]
                occupied[b['id']] = True
                break
    return result


def extract_info(data):
    global imgw, imgh, occupied, orig_img, inverted_img
    boxes = data['result']
    imgh = data['size_h']
    imgw = data['size_w']
    result = {}
    address = []
    date_time = []
    boxes = sorted(boxes, key=lambda t: (t['y'], t['x']))
    # occupied = {x:False for x in ['請求番号', '請求書基本情報', '請求日付', '売上日付', '支払日付', '取引先（A）', '取引先（B）', '合計金額', '件名', '小計', '源泉税額', '消費税額', '消費税額（10%）', '消費税額（8%）', '請求明細情報', '明細日付', '明細件名', '明細金額']}
    occupied = {x: False for x in range(1000)}

    # Số hóa đơn:
    result['請求番号'] = get_value('請求番号', boxes, ["請求番号", "請求書番号", "請求No.", "No.", "No", "伝票番号"])
    # Nội dung cơ bản hóa đơn
    result['請求書基本情報'] = get_value('請求書基本情報', boxes, ['請求書基本情報'])

    # Ngày tháng gửi hóa đơn
    result['請求日付'] = get_value('請求日付', boxes, ['日付', '発行日', '請求日', '出力日', '請求書作成日', '登録年月日', '請求年月', '発行年月'])

    # Ngày tính lên doanh số
    result['売上日付'] = get_value('売上日付', boxes, ['締日', '締切', '売上日', '売上日付'])

    # Ngày hạn trả tiền
    result['支払日付'] = get_value('支払日付', boxes,
                               ['お支払約束日', '支払期限', '払込期日', 'お支払期限', 'お支払期限日', 'お支払期日', '支払開日', 'お支払約東日', 'お支払い日'] + ['支払日', '支払期限', '支払期日',
                                                                                                  '振込日',
                                                                                                  '振込日付',
                                                                                                  '振込期日', '振替日', '振替日付',
                                                                                                  '振替予定日',
                                                                                                  '支払日付'])

    # Công ty A
    result['取引先（A）'] = get_value('取引先（A）', boxes, ['御中', '様', '総務部'])

    # Công ty B
    result['取引先（B）'] = get_value('取引先（B）', boxes, ['株式会社'] + ['株式会'])

    # Tổng tiền
    result['合計金額'] = get_value('合計金額', boxes,
                               ['集金', '合計金額', '金額', '合計', '合計額', '合計金額', '合計請求額', '合計請求金額', '請求額', 'ご請求額', '前回請求額', '御請求額', '請求金額',
                                'ご請求金額', '御請求金額', '御請求金額', '御請求合計額', '今回請求額', '今回ご請求額', '今回御請求額', '今回請求金額', '今回ご請求金額',
                                '今回御請求金額', '今回請求合計額', '今回ご請求合計額', '今回御請求合計額', '当月請求額', '当月ご請求額', '当月御請求額', '当月請求金額',
                                '当月ご請求金額', '当月御請求金額', '当月請求合計額', '当月ご請求合計額', '当月御請求合計額', '当月計上額'])

    # # Tên tiêu đề
    # result['件名'] = get_value('件名', boxes, add_space(
    #     ['摘要', '明細', '内容', '詳細', '項目', '内訳', '品番', '品名', '品目', '品物', '件名', '項目', '商品', '商品名', '製品', '製品名の情報']))

    # Tạm tính
    result['小計'] = get_value('小計', boxes, add_space(['小計'] + ['料金合計', '代金', '課税対象額', '税抜金額', '当月お買上金額']))

    # Thuế khấu trừ
    result['源泉税額'] = get_value('源泉税額', boxes, ['源泉', '源泉税', '源泉所得税', '源泉所得税額', '源泉徴収', '源泉徴収額', '源泉徴収税額', '控除', '控除額'])

    # Thuế tiêu dùng (10%)
    result['消費税額（10%）'] = get_value('消費税額（10%）', boxes, ['消費税額(10%)', '消費税額(10'] + ['消費税10%', '消費税(10%)'])

    # Thuế tiêu dùng (8%)
    result['消費税額（8%）'] = get_value('消費税額（8%）', boxes, ['消費税額(8%)', '消費税額(8'] + ['消費税8%', '消費税(8%)'])

    # Thuế tiêu dùng
    result['消費税額'] = get_value('消費税額', boxes, ['消費税', '税額', '消費税額', 'TAX', 'Tax', '消費税額等'])

    # Thông tin chi tiết hóa đơn
    # result['請求明細情報'] = get_value('請求明細情報', boxes, ['請求書の明細箇所の情報'])

    # Ngày tháng hóa đơn CỤ THỂ
    result['明細日付'] = get_value('明細日付', boxes, add_space(['期間'] + ['日付', '年月日', '伝票日付', '売上日付', '月日', '取引年月日', '取引月日']))

    # Giá tiền CỤ THỂ
    result['明細金額'] = get_value('明細金額', boxes, add_space(['等合計', '合計', '合計(円)', '計(円)'] + ['金 額(円)', '金額(円)', '金額', '額(円)'] + ['価格', '価額']))

    # Đơn giá cụ thể:
    result['単価'] = get_value('単価', boxes, add_space(['単価', '単 価(円)', '単価(円)', '売価']))

    # Thuế CỤ THỂ:
    result['消費税等'] = get_value('消費税等', boxes, ['消費税等'])

    # Số luọng cụ thể:
    result['数量'] = get_value('数量', boxes, ['納品数量', '数量', '数量単', '販売数量'])

    # Tên nội dung CỤ THỂ
    result['明細件名'] = get_value('明細件名', boxes,
                               add_space(
                                   ['料金項目', '摘要', '明細', '内容', '詳細', '項目', '内訳', '品番', '品名', '品目', '品物', '件名', '項目',
                                    '商品', '商品名',
                                    '製品', '製品名']))

    result = post_process(result, boxes)

    res = {}
    for key in result:
        if result[key] is not None and len(result[key]) > 0:
            # a = [b['text'] for b in result[key][0]]
            # print(key, a)
            res[key] = result[key]
    return res


def getTableData(img, data):
    table = find_largest_table(img)
    cv2.imwrite('E:/aimenext/aime-ocr/test/table/table.png', table)
    gray = cv2.cvtColor(table, cv2.COLOR_BGR2GRAY)
    cv2.imwrite('E:/aimenext/aime-ocr/test/table/gray.png', table)
    rs = extract.extract_line(table, gray, data)
    result = get_data(rs, data)
    print('------ result -------\n', result)
    return result


def main(img_path, data):
    global orig_img, inverted_img, largest_table
    # Preprocess to find header:
    img = cv2.imread(img_path)
    # 1: Convert to grayscale
    grayscale = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # 2: Convert to blackwhite
    (thresh, orig_img) = cv2.threshold(grayscale, 128, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    # 3: Invert black white img:
    inverted_img = cv2.bitwise_not(orig_img)
    print(orig_img.shape)
    print(inverted_img.shape)

    # Get largest table:
    found_table = find_largest_table(img)
    if found_table is not None:
        x1, y1 = found_table[0][0], found_table[0][1]
        x2, y2 = found_table[1][0], found_table[1][1]
        x3, y3 = found_table[2][0], found_table[2][1]
        x4, y4 = found_table[3][0], found_table[3][1]
        largest_table = {
            'x1': min(x1, x2, x3, x4),
            'y1': min(y1, y2, y3, y4),
            'x2': max(x1, x2, x3, x4),
            'y2': max(y1, y2, y3, y4)
        }
    else:
        largest_table = None

    r = extract_info(data)
    # with open('E:/aimenext/aime-ocr/test/table/data.txt', 'w+') as f:
    #     json.dump(data, f)
    # print('-------- extract_info -------- \n', r)
    # img = cv2.imread(img_path)
    # try:
    #     print('-------- before getTableData -------- \n')
    #     r.update(getTableData(img, data['result']))
    #     print('-------- after getTableData -------- \n', r)
    # except Exception as e:
    #     print(e)
    # for x in r:
    #     r[x] = r[x]
    return r




