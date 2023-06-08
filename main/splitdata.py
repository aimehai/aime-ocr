from operator import itemgetter

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
        minx = 10
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


def split_data(resp, num_col, num_row):
    global data, width, height, d1, d2

    data = resp['boxes']
    width = resp['size_w']
    height = resp['size_h']
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
        merge_row(data, num_row)
    else:
        for x in data:
            if x['id'] not in d2:
                find_col(x)
        if len(d1) > num_col:
            merge_col(num_col)

        for i in range(len(d1)):
            d1[i] = sorted(d1[i], key=itemgetter('x'))
            if len(d1[i]) > num_row:
                merge_row(d1[i], num_row)
            d1[i] = sorted(d1[i], key=itemgetter('y'))
    return d1


if __name__ == '__main__':
    data = {
        'boxes': [{'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 17, 'id': 0, 'prob': 0.9288686513900757, 'text': '氏名', 'w': 31, 'x': 45, 'y': 11}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 1, 'prob': 0.2483525276184082, 'text': 'カワサキエイタロウ', 'w': 96, 'x': 2, 'y': 40}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 2, 'prob': 0.6767934560775757, 'text': '川﨑 榮太', 'w': 48, 'x': 0, 'y': 54}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 3, 'prob': 0.24639847874641418, 'text': ' 榮太郎', 'w': 52, 'x': 50, 'y': 54}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 4, 'prob': 0.02840459905564785, 'text': 'カソサキリュセチロウ', 'w': 104, 'x': 2, 'y': 78}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 5, 'prob': 0.8442211747169495, 'text': '川崎 劉一郎', 'w': 99, 'x': 3, 'y': 93}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 6, 'prob': 0.07768561691045761, 'text': 'トドロョタ', 'w': 60, 'x': 4, 'y': 114}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 7, 'prob': 0.6835609078407288, 'text': '轟遼汰', 'w': 70, 'x': 0, 'y': 128}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 8, 'prob': 0.3967113196849823, 'text': 'サナダコタ', 'w': 28, 'x': 4, 'y': 150}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 9, 'prob': 0.9506537318229675, 'text': 'コタロウ', 'w': 36, 'x': 52, 'y': 152}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 10, 'prob': 0.5309723615646362, 'text': '日 琥太郎', 'w': 58, 'x': 44, 'y': 164}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 11, 'prob': 0.6933583617210388, 'text': '真田 琥', 'w': 34, 'x': 4, 'y': 166}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 12, 'prob': 0.11471867561340332, 'text': 'サイオンジルリ', 'w': 84, 'x': 4, 'y': 186}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 13, 'prob': 0.74619060754776, 'text': '寺瑠璃', 'w': 42, 'x': 60, 'y': 200}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 14, 'prob': 0.6015616655349731, 'text': '西園寺 瑠', 'w': 48, 'x': 7, 'y': 203}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 15, 'prob': 0.44663316011428833, 'text': 'サイトウ カケル', 'w': 78, 'x': 4, 'y': 224}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 16, 'prob': 0.7059588432312012, 'text': '斎藤翔', 'w': 66, 'x': 4, 'y': 238}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 17, 'prob': 0.17548325657844543, 'text': 'サイトウリンコ', 'w': 74, 'x': 7, 'y': 263}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 15, 'id': 18, 'prob': 0.7817113399505615, 'text': '斉藤 凛子', 'w': 79, 'x': 7, 'y': 277}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 19, 'prob': 0.20395633578300476, 'text': 'サイトウガウ', 'w': 68, 'x': 4, 'y': 298}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 20, 'prob': 0.5171789526939392, 'text': '齋藤樂', 'w': 66, 'x': 4, 'y': 312}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 21, 'prob': 0.07188816368579865, 'text': 'ワシオリョ', 'w': 28, 'x': 4, 'y': 336}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 22, 'prob': 0.90472811460495, 'text': 'リョウタロウ', 'w': 56, 'x': 52, 'y': 336}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 23, 'prob': 0.7346410155296326, 'text': '鷲尾 僚', 'w': 34, 'x': 4, 'y': 348}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 24, 'prob': 0.566743791103363, 'text': '尾 僚太郎', 'w': 62, 'x': 42, 'y': 348}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 25, 'prob': 0.20360688865184784, 'text': 'トピオ カナ', 'w': 28, 'x': 4, 'y': 372}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 26, 'prob': 0.870405912399292, 'text': 'カナコ', 'w': 30, 'x': 50, 'y': 372}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 27, 'prob': 0.5048531889915466, 'text': '鳶尾 加', 'w': 36, 'x': 4, 'y': 386}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 28, 'prob': 0.3593338429927826, 'text': '電加奈子', 'w': 58, 'x': 44, 'y': 386}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 29, 'prob': 0.8482248187065125, 'text': 'ヒビキ', 'w': 28, 'x': 4, 'y': 410}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 30, 'prob': 0.9214332699775696, 'text': 'ユウカイ', 'w': 34, 'x': 70, 'y': 410}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 31, 'prob': 0.9037149548530579, 'text': '枇々木 悠凱', 'w': 98, 'x': 4, 'y': 422}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 32, 'prob': 0.6127179265022278, 'text': 'エンドウレン', 'w': 34, 'x': 7, 'y': 449}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 33, 'prob': 0.4514782130718231, 'text': 'ドウレンタロウ', 'w': 54, 'x': 45, 'y': 449}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 34, 'prob': 0.5045928359031677, 'text': '遠藤 蓮太郎', 'w': 96, 'x': 7, 'y': 461}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 35, 'prob': 0.1067647635936737, 'text': 'パ)', 'w': 18, 'x': 4, 'y': 484}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 36, 'prob': 0.9123583436012268, 'text': 'ダイキ', 'w': 28, 'x': 53, 'y': 485}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 37, 'prob': 0.6576181054115295, 'text': '薔薇 大', 'w': 34, 'x': 4, 'y': 496}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 15, 'id': 38, 'prob': 0.43441042304039, 'text': '大樹', 'w': 32, 'x': 55, 'y': 499}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 39, 'prob': 0.39503827691078186, 'text': 'スワカ', 'w': 20, 'x': 4, 'y': 520}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 40, 'prob': 0.8905295133590698, 'text': 'カナ', 'w': 20, 'x': 50, 'y': 520}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 41, 'prob': 0.9172075986862183, 'text': '諏訪 佳那', 'w': 84, 'x': 4, 'y': 534}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 42, 'prob': 0.6601104140281677, 'text': 'アヤノコウジ レイカ', 'w': 90, 'x': 7, 'y': 559}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 15, 'id': 43, 'prob': 0.49710381031036377, 'text': '綾小路 麗華', 'w': 98, 'x': 5, 'y': 573}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 44, 'prob': 0.12045039236545563, 'text': 'ヤナギサワアツキ', 'w': 76, 'x': 4, 'y': 594}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 45, 'prob': 0.5834048986434937, 'text': '栁澤 篤紀', 'w': 84, 'x': 4, 'y': 608}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 46, 'prob': 0.3753364384174347, 'text': 'ヒョク', 'w': 34, 'x': 48, 'y': 630}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 47, 'prob': 0.7045190334320068, 'text': 'コガヒ', 'w': 22, 'x': 4, 'y': 632}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 48, 'prob': 0.8860594630241394, 'text': '古閑 彪', 'w': 34, 'x': 7, 'y': 645}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 49, 'prob': 0.3125154972076416, 'text': '彪我', 'w': 37, 'x': 51, 'y': 645}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 50, 'prob': 0.44403427839279175, 'text': 'タカハシチヒロ', 'w': 78, 'x': 4, 'y': 743}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 51, 'prob': 0.4416680634021759, 'text': '高橋千', 'w': 32, 'x': 7, 'y': 757}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 52, 'prob': 0.766374945640564, 'text': '十尊', 'w': 33, 'x': 55, 'y': 759}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 53, 'prob': 0.35792964696884155, 'text': 'タカハシトモキ', 'w': 78, 'x': 6, 'y': 779}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 54, 'prob': 0.8793498277664185, 'text': '高橋 和毅', 'w': 82, 'x': 6, 'y': 793}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 55, 'prob': 0.43591374158859253, 'text': 'サトウカ', 'w': 26, 'x': 7, 'y': 817}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 56, 'prob': 0.8830195069313049, 'text': 'カエデ', 'w': 27, 'x': 55, 'y': 817}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 57, 'prob': 0.7844737768173218, 'text': '佐藤 楓', 'w': 66, 'x': 7, 'y': 831}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 58, 'prob': 0.2128984034061432, 'text': 'トミオカレオ', 'w': 66, 'x': 6, 'y': 853}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 59, 'prob': 0.7771944999694824, 'text': '富岡 玲央', 'w': 82, 'x': 6, 'y': 867}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 60, 'prob': 0.2941581904888153, 'text': 'トミオカコウタロウ', 'w': 94, 'x': 7, 'y': 891}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 61, 'prob': 0.4898968040943146, 'text': '冨岡 紘太朗', 'w': 96, 'x': 7, 'y': 905}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 62, 'prob': 0.9533300995826721, 'text': 'シュヒテン・エリ', 'w': 104, 'x': 6, 'y': 943}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 63, 'prob': 0.8617271184921265, 'text': 'シャリュ トューリー', 'w': 106, 'x': 6, 'y': 981}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 64, 'prob': 0.25726163387298584, 'text': 'サラリュリュ', 'w': 70, 'x': 4, 'y': 1015}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 65, 'prob': 0.4644748866558075, 'text': 'フジレ', 'w': 22, 'x': 6, 'y': 1037}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 66, 'prob': 0.9575398564338684, 'text': 'レモン', 'w': 30, 'x': 54, 'y': 1037}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 67, 'prob': 0.5537352561950684, 'text': '津慈 檸橋', 'w': 42, 'x': 9, 'y': 1053}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 68, 'prob': 0.30764317512512207, 'text': '檸檬', 'w': 34, 'x': 55, 'y': 1053}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 69, 'prob': 0.5701172351837158, 'text': 'カイ', 'w': 18, 'x': 6, 'y': 1075}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 70, 'prob': 0.9520991444587708, 'text': 'ハヤタ', 'w': 30, 'x': 52, 'y': 1075}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 71, 'prob': 0.5374299883842468, 'text': '甲斐 隼太', 'w': 42, 'x': 6, 'y': 1089}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 72, 'prob': 0.060606345534324646, 'text': '隼太', 'w': 38, 'x': 50, 'y': 1089}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 73, 'prob': 0.3127729594707489, 'text': 'オオツレン', 'w': 28, 'x': 6, 'y': 1113}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 74, 'prob': 0.9497749209403992, 'text': 'レンタロウ', 'w': 44, 'x': 54, 'y': 1113}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 75, 'prob': 0.849764883518219, 'text': '大連 連', 'w': 34, 'x': 6, 'y': 1125}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 76, 'prob': 0.1392291784286499, 'text': '連太郎', 'w': 50, 'x': 54, 'y': 1125}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 77, 'prob': 0.2678890526294708, 'text': 'カサイブドウ', 'w': 78, 'x': 6, 'y': 1149}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 78, 'prob': 0.5051932334899902, 'text': '葛西 葡', 'w': 38, 'x': 6, 'y': 1163}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 79, 'prob': 0.0752442479133606, 'text': 'ヨ 匍萄', 'w': 36, 'x': 52, 'y': 1163}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 80, 'prob': 0.05194097384810448, 'text': 'ヨシダ コマ', 'w': 68, 'x': 6, 'y': 1187}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 81, 'prob': 0.771602213382721, 'text': '吉田 由', 'w': 36, 'x': 6, 'y': 1199}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 82, 'prob': 0.6940645575523376, 'text': '日 由真', 'w': 40, 'x': 48, 'y': 1199}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 83, 'prob': 0.10480272024869919, 'text': 'コシダシュ', 'w': 30, 'x': 6, 'y': 1223}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 10, 'id': 84, 'prob': 0.5522921085357666, 'text': 'シュンタロウ', 'w': 54, 'x': 54, 'y': 1225}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 85, 'prob': 0.8166412115097046, 'text': '吉田 瞬', 'w': 34, 'x': 8, 'y': 1237}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 86, 'prob': 0.40754434466362, 'text': '瞬太郎', 'w': 52, 'x': 54, 'y': 1237}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 87, 'prob': 0.35652026534080505, 'text': 'ワタナベミサキ', 'w': 78, 'x': 6, 'y': 1259}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 88, 'prob': 0.22744634747505188, 'text': '渡邊岬', 'w': 68, 'x': 6, 'y': 1273}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 12, 'id': 89, 'prob': 0.40431511402130127, 'text': 'ワタナベシュウト', 'w': 86, 'x': 6, 'y': 1297}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 16, 'id': 90, 'prob': 0.44141918420791626, 'text': '渡辺 修Ⓢ', 'w': 40, 'x': 6, 'y': 1311}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 18, 'id': 91, 'prob': 0.5825561285018921, 'text': '辺 修斗', 'w': 44, 'x': 46, 'y': 1311}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 14, 'id': 92, 'prob': 0.2568056285381317, 'text': 'ワタナベサナ', 'w': 68, 'x': 6, 'y': 1333}, {'category': 'MACHINE_PRINTED_TEXT', 'direction': 'horiz', 'h': 20, 'id': 93, 'prob': 0.6409052610397339, 'text': '渡邉 佐奈', 'w': 84, 'x': 7, 'y': 1347}],
        'size_w': 126,
        'size_h': 1371
    }
    d = split_data(data, 1, 64)
    print(d)
