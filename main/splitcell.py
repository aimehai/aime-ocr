from shapely.geometry import Polygon
import cv2

data = None
width = None
height = None
d1 = []
d2 = []


def calCenX(x):
    return (x['x'] + x['w']) / 2


def calCenY(x):
    return (x['y'] + x['h']) / 2


def find_col(x):
    global data, width, d1, d2
    cen = (x['x'] + x['w']) / 2
    d = []
    for m in data:
        if abs(cen - calCenX(m)) < width / 30:
            d.append(m)
            d2.append(m['id'])
    d1.append(d)


def get_iou(bb1, bb2):
    box_1 = [[float(bb1['x']), float(bb1['y'])], [float(bb1['x']) + float(bb1['w']), float(bb1['y'])],
             [float(bb1['x']) + float(bb1['w']), float(bb1['y']) + float(bb1['h'])],
             [float(bb1['x']), float(bb1['y']) + float(bb1['h'])]]
    box_2 = [[bb2[0], bb2[1]], [bb2[0] + bb2[2], bb2[1]], [bb2[0] + bb2[2], bb2[1] + bb2[3]], [bb2[0], bb2[1] + bb2[3]]]
    poly_1 = Polygon(box_1)
    poly_2 = Polygon(box_2)
    iou = poly_1.intersection(poly_2).area / poly_1.union(poly_2).area
    if iou > 0.1:
        return True
    return False


def merge_box(x1, x2):
    x = x1
    x['y'] = x1['y'] if x1['y'] < x2['y'] else x2['y']
    x['h'] = x2['y'] + x2['h'] - x1['y'] if x1['y'] + x1['h'] < x2['y'] + x2['h'] else x1['y'] + x1['h'] - x2['y']
    x['x'] = x1['x'] if x1['x'] < x2['x'] else x2['x']
    x['w'] = x2['x'] + x2['w'] - x1['x'] if x1['x'] + x1['w'] <= x2['x'] + x2['w'] else x1['x'] + x1['w'] - x2['x']
    x['text'] = x1['text'] + x2['text']
    return x


def merge_row(rows, num_row):
    global d1, d2, height
    while len(rows) > num_row:
        minx = height
        id1 = 0
        id2 = 0
        for i in range(0, len(rows) - 1):
            for j in range(i + 1, len(rows)):
                a = abs(calCenY(rows[i]) - calCenY(rows[j]))
                if a < minx:
                    minx = a
                    id1 = i
                    id2 = j
        rows[id1] = merge_box(rows[id1], rows[id2])
        rows.remove(rows[id2])


def merge_col(num_col):
    global d1, d2, width
    while len(d1) > num_col:
        r = []
        for i in range(num_col, len(d1)):
            for d1j in d1[i]:
                minx = width
                id = 0
                cen = (d1j['x'] + d1j['w']) / 2
                for k in range(num_col):
                    for dkl in d1[k]:
                        if abs(cen - calCenX(dkl)) < minx:
                            minx = abs(cen - calCenX(dkl))
                            id = dkl['id']
                for k in range(num_col):
                    for dkl in d1[k]:
                        if dkl['id'] == id:
                            d1[k].append(d1j)
                            break
            r.append(i)
        for i, d in enumerate(d1):
            if i in r:
                d1.remove(d)


def merge(records):
    text = ''
    for r in records:
        text += ' ' + r['text']
    dx = records[0]
    dx['text'] = text
    dx['w'] = records[-1]['x'] + records[-1]['w'] - records[0]['x']
    dx['h'] = records[-1]['y'] + records[-1]['h'] - records[0]['y']
    return dx


def split_cell(xywh, col, row):
    x, y, w, h = xywh
    cw = round(w / col)
    rw = round(h / row)
    imgs = []
    for c in range(col):
        for r in range(row):
            cell = [x + c * cw, y + r * rw, cw, rw]
            imgs.append(cell)
    return imgs


def split_data(resp, num_col, num_row):
    global data, width, height, d1, d2

    data = resp['boxes']
    xywh = resp['xywh']
    d1 = []
    d2 = []
    if num_row == 1 and num_col == 1 and len(data) > 0:
        text = ""
        for x in data:
            text += x['text']
        arr = merge_box(data[0], data[-1])
        arr['text'] = text
        d1.append([arr])
    elif num_col == 1:
        res = [[]]
        for d in data:
            res[0].append(d)
        return res
    else:
        cells = split_cell(xywh, num_col, num_row)
        for cell in cells:
            box_in_cell = []
            for box in data:
                if get_iou(box, cell):
                    box_in_cell.append(box)
            if len(box_in_cell) > 1:
                box_in_cell = sorted(box_in_cell, key=lambda x: x['x'])
                box_in_cell = [merge(box_in_cell)]
            d1.append(box_in_cell)
    return d1

# if __name__ == '__main__':
#     data = {
#         'boxes': [
#             {'direction': 'horiz', 'h': 28, 'id': 0, 'key': '製品', 'prob': 0.9713616967201233, 'text': 'Bio', 'w': 74,
#              'x': 173, 'y': 317},
#             {'direction': 'horiz', 'h': 26, 'id': 1, 'key': '製品', 'prob': 0.7001700401306152, 'text': 'TC', 'w': 58,
#              'x': 253, 'y': 317},
#             {'direction': 'horiz', 'h': 24, 'id': 2, 'key': '製品', 'prob': 0.5775433778762817, 'text': 'Bio TC',
#              'w': 138, 'x': 173, 'y': 345},
#             {'direction': 'horiz', 'h': 28, 'id': 3, 'key': '製品', 'prob': 0.11395987868309021, 'text': 'BF MF',
#              'w': 171, 'x': 173, 'y': 369},
#             {'direction': 'horiz', 'h': 28, 'id': 4, 'key': '製品', 'prob': 0.21557319164276123, 'text': 'BEMf', 'w': 171,
#              'x': 173, 'y': 399}],
#         'size_w': 1728,
#         'size_h': 1140
#     }
#     d = split_data(data, 1, 12)
