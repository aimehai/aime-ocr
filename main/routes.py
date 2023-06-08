import os
import secrets
from functools import wraps

from PIL import Image
from flask_socketio import emit
from flask import render_template, url_for, flash, redirect, request, jsonify, send_file, make_response
from main import app, db, bcrypt, socketio
from main.forms import *
from main.models import *
from flask_login import login_user, current_user, logout_user, login_required
from threading import Thread
import datetime
import requests
import json
import random
from pdf2image import convert_from_path, convert_from_bytes
import cv2
import numpy as np
from werkzeug.utils import secure_filename
from main.extract_infor import extract
from operator import itemgetter
import main.extract as ext
from sqlalchemy import and_, or_, desc, asc
import main.splitcell as spl
import time
import ast
import jwt
from dotenv import load_dotenv

load_dotenv()
app.config['ALLOWED_EXTENSIONS'] = set(['txt', 'pdf', 'png', 'jpg', 'jpeg', 'zip', 'csv', 'tiff'])
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, 'static', 'uploaded')
if not os.path.exists(UPLOAD_DIR):
    os.mkdir(UPLOAD_DIR)
IMG_DIR = os.path.join(BASE_DIR, 'static', 'imgs')
API_URL = os.getenv('API_URL', 'http://ocrapi.demo2.aimenext.com:9966')
JWT_SECRET = 'AHJS239JOSUIDJPQM320'

LIST_COLUMN = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
               'V', 'W', 'X', 'Y', 'Z', 'AA',
               'AB', 'AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AL', 'AM', 'AN', 'AO', 'AP', 'AQ', 'AR',
               'AS', 'AT', 'AU', 'AV', 'AW', 'AX', 'AY', 'AZ', 'BA', 'BB', 'BC', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI',
               'BJ', 'BK', 'BL', 'BM', 'BN', 'BO', 'BP', 'BQ', 'BR', 'BS', 'BT', 'BU', 'BV', 'BW', 'BX', 'BY', 'BZ',
               'CA', 'CB', 'CC', 'CD', 'CE', 'CF', 'CG', 'CH', 'CI', 'CJ',
               'CK', 'CL', 'CM', 'CN', 'CO', 'CP', 'CQ', 'CR', 'CS', 'CT', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ',
               'DA', 'DB', 'DC', 'DD', 'DE', 'DF', 'DG', 'DH', 'DI', 'DJ', 'DK', 'DL', 'DM', 'DN', 'DO', 'DP', 'DQ',
               'DR', 'DS', 'DT', 'DU', 'DV', 'DW', 'DX', 'DY', 'DZ', 'EA', 'EB', 'EC', 'ED', 'EE', 'EF', 'EG', 'EH',
               'EI', 'EK', 'EL', 'EM', 'EN', 'EO', 'EP', 'EQ', 'ER', 'ES', 'ET', 'EV', 'EX', 'EY', 'EZ', 'FA', 'FB',
               'FC', 'FD', 'FE', 'FF', 'FG', 'FH', 'FI', 'FK', 'FL', 'FM', 'FN', 'FO', 'FP', 'FQ', 'FR', 'FS', 'FT',
               'FV', 'FX', 'FY', 'FZ', 'GA', 'GB', 'GC', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GK', 'GL', 'GM', 'GN',
               'GO', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GV', 'GX', 'GY', 'GZ', 'HA', 'HB', 'HC', 'HD', 'HE', 'HF', 'HG',
               'HH', 'HI', 'HK', 'HL', 'HM', 'HN', 'HO', 'HP', 'HQ', 'HR', 'HS', 'HT', 'HV', 'HX', 'HY', 'HZ', 'IA',
               'IB', 'IC', 'ID', 'IE', 'IF', 'IG', 'IH', 'II', 'IK', 'IL', 'IM', 'IN', 'IO', 'IP', 'IQ', 'IR', 'IS',
               'IT', 'IV', 'IX', 'IY', 'IZ', 'KA', 'KB', 'KC', 'KD', 'KE', 'KF', 'KG', 'KH', 'KI', 'KK', 'KL', 'KM',
               'KN', 'KO', 'KP', 'KQ', 'KR', 'KS', 'KT', 'KV', 'KX', 'KY', 'KZ', 'LA', 'LB', 'LC', 'LD', 'LE', 'LF',
               'LG', 'LH', 'LI', 'LK', 'LL', 'LM', 'LN', 'LO', 'LP', 'LQ', 'LR', 'LS', 'LT', 'LV', 'LX', 'LY', 'LZ',
               'MA', 'MB', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MI', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR',
               'MS', 'MT', 'MV', 'MX', 'MY', 'MZ', 'NA', 'NB', 'NC', 'ND', 'NE', 'NF', 'NG', 'NH', 'NI', 'NK', 'NL',
               'NM', 'NN', 'NO', 'NP', 'NQ', 'NR', 'NS', 'NT', 'NV', 'NX', 'NY', 'NZ', 'OA', 'OB', 'OC', 'OD', 'OE',
               'OF', 'OG', 'OH', 'OI', 'OK', 'OL', 'OM', 'ON', 'OO', 'OP', 'OQ', 'OR', 'OS', 'OT', 'OV', 'OX', 'OY',
               'OZ', 'PA', 'PB', 'PC', 'PD', 'PE', 'PF', 'PG', 'PH', 'PI', 'PK', 'PL', 'PM', 'PN', 'PO', 'PP', 'PQ',
               'PR', 'PS', 'PT', 'PV', 'PX', 'PY', 'PZ', 'QA', 'QB', 'QC', 'QD', 'QE', 'QF', 'QG', 'QH', 'QI', 'QK',
               'QL', 'QM', 'QN', 'QO', 'QP', 'QQ', 'QR', 'QS', 'QT', 'QV', 'QX', 'QY', 'QZ', 'RA', 'RB', 'RC', 'RD',
               'RE', 'RF', 'RG', 'RH', 'RI', 'RK', 'RL', 'RM', 'RN', 'RO', 'RP', 'RQ', 'RR', 'RS', 'RT', 'RV', 'RX',
               'RY', 'RZ', 'SA', 'SB', 'SC', 'SD', 'SE', 'SF', 'SG', 'SH', 'SI', 'SK', 'SL', 'SM', 'SN', 'SO', 'SP',
               'SQ', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ', 'TA', 'TB', 'TC', 'TD', 'TE', 'TF', 'TG', 'TH', 'TI',
               'TK', 'TL', 'TM', 'TN', 'TO', 'TP', 'TQ', 'TR', 'TS', 'TT', 'TV', 'TX', 'TY', 'TZ', 'VA', 'VB', 'VC',
               'VD', 'VE', 'VF', 'VG', 'VH', 'VI', 'VK', 'VL', 'VM', 'VN', 'VO', 'VP', 'VQ', 'VR', 'VS', 'VT', 'VV',
               'VX', 'VY', 'VZ', 'XA', 'XB', 'XC', 'XD', 'XE', 'XF', 'XG', 'XH', 'XI', 'XK', 'XL', 'XM', 'XN', 'XO',
               'XP', 'XQ', 'XR', 'XS', 'XT', 'XV', 'XX', 'XY', 'XZ', 'YA', 'YB', 'YC', 'YD', 'YE', 'YF', 'YG', 'YH',
               'YI', 'YK', 'YL', 'YM', 'YN', 'YO', 'YP', 'YQ', 'YR', 'YS', 'YT', 'YV', 'YX', 'YY', 'YZ', 'ZA', 'ZB',
               'ZC', 'ZD', 'ZE', 'ZF', 'ZG', 'ZH', 'ZI', 'ZK', 'ZL', 'ZM', 'ZN', 'ZO', 'ZP', 'ZQ', 'ZR', 'ZS', 'ZT',
               'ZV', 'ZX', 'ZY', 'ZZ']

REPORT = '帳票'
LICENSE_PLATE = 'ナンバープレート'
DRIVER_LICENSE = '運転免許証'
VEHICLE_VERIFICATION = '車検証認識'

PROCESSING = 0
EXECUTED = 1
ERROR = 2
WAITING = 3
LIMITED = 4
CONFIRMED = 5

drug_dict = ["ヒブ", "E型肝炎", "RSウイルス感染症", "アクトヒブ", "アセトン血性嘔吐症（周期性嘔吐症）", "アデノウイルス感染症（プール熱）", "アトピー性皮膚炎", "アナフィラキシーショック", "インフルエンザ", "エキノコックス症（包虫症）", "おたふく風邪（流行性耳下腺炎）", "カンピロバクター腸炎", "クループ（喉頭炎）", "クローン病", "サルコイドーシス", "しゃっくり（吃逆）", "チック", "りんご病（伝染性紅斑）", "てんかん", "とびひ（伝染性膿痂疹）", "ヒトメタニューモウイルス感染症", "ヒルシュスプルング病", "リンパ管炎", "プレベナー", "ヘルパンギーナ", "メッケル憩室", "ヘルペス性歯肉口内炎", "ポリオ（急性灰白髄炎・小児まひ）", "マイコプラズマ感染症", "胃・十二指腸潰瘍", "胃軸捻転", "胃食道逆流症", "胃腸炎", "陰嚢水腫、Nuck水腫", "横紋筋肉腫", "花粉症", "過敏性腸症候群（IBS）", "壊死性腸炎", "咳喘息", "感染性胃腸炎", "感冒", "肝芽腫", "間質性肺炎", "気管・気管支軟化症", "気管支炎", "気管支喘息", "起立性調節障害（ＯＤ）", "急性胃腸炎（ウイルス性胃腸炎・嘔吐下痢症）", "急性陰嚢症", "急性肝炎", "急性虫垂炎（もうちょう炎）", "血管腫、血管奇形・リンパ管奇形（リンパ管腫）", "血管性認知症", "原発不明がん", "鎖肛（直腸肛門奇形）", "細菌性髄膜炎", "耳前瘻孔", "自閉症", "手足口病", "小児急性脳症（インフルエンザ脳症）", "消化管ポリープ、ポリポーシス", "消化管異物", "消化管重複症", "食中毒", "食道アカラシア", "食道裂孔ヘルニア", "食物アレルギー", "新型コロナウイルス感染症", "神経芽腫", "腎芽腫", "腎性糖尿", "水ぼうそう（水痘）", "水腎症・水尿管症", "睡眠時無呼吸症候群", "髄膜炎", "正中頸嚢胞", "舌小帯短縮症", "先天性横隔膜ヘルニア", "先天性気管狭窄症", "先天性股関節脱臼", "先天性食道狭窄症", "先天性食道閉鎖症", "先天性心疾患", "先天性胆道拡張症", "先天性腸閉鎖症・腸狭窄症", "先天性肺気道奇形", "川崎病", "鼠径ヘルニア", "側頸瘻", "帯状疱疹", "胎便性腹膜炎", "胎便閉塞性疾患", "胆石症", "胆道閉鎖症", "腸回転異常症", "腸重積", "腸重積症", "腸閉塞", "潰瘍性大腸炎", "停留精巣", "伝染性紅斑（りんご病）", "糖尿病性腎症", "動脈管開存症", "特発性肺線維症", "突発性発疹（小児バラ疹）", "二分脊椎", "日本脳炎", "尿道下裂", "尿路感染症", "熱性けいれん", "熱中症", "嚢胞性肺疾患", "破傷風", "肺結核", "肺腺がん（腺がん）", "肺分画症", "白血病", "肥厚性幽門狭窄症", "百日咳", "風邪", "風疹（風しん）", "副耳", "腹壁破裂", "便秘", "包茎", "麻疹（はしか）", "慢性肝炎", "慢性閉塞性肺疾患（COPD）", "未熟児網膜症", "網膜静脈閉塞症", "門脈圧亢進症", "夜尿症", "薬物性肝障害（薬剤性肝障害）", "溶連菌咽頭炎", "梨状窩瘻", "流行性角結膜炎", "裂肛", "漏斗胸", "嘔吐下痢症（急性胃腸炎・ウイルス性胃腸炎）", "扁桃肥大", "肛門周囲膿瘍、痔瘻", "胚細胞性腫瘍", "膀胱尿管逆流症", "膵のう胞", "膵炎", "臍帯ヘルニア", "臍腸管遺残・尿膜管遺残", "ワクチン", "A型肝炎", "BCG", "B型肝炎", "HPV", "MR", "インフルエンザ", "おたふくかぜ", "ジフテリア", "ヒトパピローマウイルス感染症", "ヒブ感染症（ヘモフィルス・", "ポリオ", "ロタウイルス胃腸炎", "ロタウイルス感染症", "結核", "細菌性髄膜炎", "四種混合 (DPT-IPV) ジフテリア、百日咳、 破傷風、ポリオのワク チン", "小児の肺炎球菌感染症", "新型コロナウイルス感染症（COVID-19）", "水痘（みずぼうそう）", "髄膜炎菌感染症", "二種混合（DT）", "日本脳炎", "破傷風（はしょうふう）", "肺炎球菌", "百日せき（ひゃくにちせき）", "風しん", "麻しん（はしか）", "麻疹風疹（MR）"]

# API_SETTING = {
#     REPORT: {
#         'url': 'http://35.165.122.130:8080',
#         'path': '/',
#     },
#     LICENSE_PLATE: {
#         'url': 'http://54.249.71.234:5050',
#         'path': '/api/process'
#     },
#     DRIVER_LICENSE: {
#         'url': 'http://35.165.122.130:8080',
#         'path': '/credit_card'
#     }
# }


def create_uuid():
    random.seed(datetime.datetime.now())
    uuid = ''
    for i in range(10):
        uuid += str(random.randint(0, 9))
    return uuid


def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1] in app.config['ALLOWED_EXTENSIONS']


def start_new_thread(function):
    def decorator(*args, **kwargs):
        t = Thread(target=function, args=args, kwargs=kwargs)
        t.daemon = True
        t.start()
        return t

    return decorator


def download(url):
    try:
        get_response = requests.get(url, stream=True, verify=False, timeout=5)
        if get_response.status_code == 200:
            file_name = url.split("/")[-1]
            path = os.path.join(UPLOAD_DIR, file_name)
            with open(path, 'wb') as f:
                for chunk in get_response.iter_content(chunk_size=1024):
                    if chunk:
                        f.write(chunk)
        else:
            file_name = None
    except:
        file_name = None
    return file_name


def update_sql(data):
    formats = Format.query.filter().all()
    for d in data:
        if 'result' in d and d['result'] is not None:
            res = Result.query.filter_by(id=d['id']).first()
            for f in formats:
                if int(d['type']) == f.id:
                    output_image = f.output + d['result']['img'][0]
                    res.output_path = download(output_image)
                    res.result = json.dumps(d['result']['text'][0])
                    res.status = EXECUTED
                    db.session.commit()
        else:
            res = Result.query.filter_by(id=d['id']).first()
            res.status = ERROR
            db.session.commit()


def save_picture(form_picture):
    random_hex = secrets.token_hex(8)
    _, f_ext = os.path.splitext(form_picture.filename)
    picture_fn = random_hex + f_ext
    picture_path = os.path.join(app.root_path, 'static/profile_pics', picture_fn)

    output_size = (125, 125)
    i = Image.open(form_picture)
    i.thumbnail(output_size)
    i.save(picture_path)

    return picture_fn


def zipdir(path, zip):
    for root, dirs, files in os.walk(path):
        for file in files:
            zip.write(os.path.join(root, file))


@start_new_thread
def start_extract(data):
    formats = Format.query.filter().all()
    for d in data:
        try:
            for f in formats:
                if int(d['type']) == f.id:
                    files = {'file': open(os.path.join(UPLOAD_DIR, d['name']), 'rb')}
                    url = f.url + f.api
                    r = requests.post(url, files=files)
                    d['result'] = r.json()
                    break
        except Exception as e:
            print(e)
            d['result'] = None
    update_sql(data)


@app.route("/")
@login_required
def home():
    return render_template('home.html')


@app.route("/about")
@login_required
def about():
    return render_template('about.html', title='About')


@app.route("/profile")
@login_required
def profile():
    company = Company.query.filter_by(uuid=current_user.company_id).first()
    data = {
        'name': company.name,
        'uuid': company.uuid,
        'created_at': company.created_at
    }
    return render_template('profile.html', title='プロフィール', data=data)


@app.route("/register", methods=['GET', 'POST'])
@login_required
def register():
    form = RegistrationForm()
    if form.validate_on_submit():
        hashed_password = bcrypt.generate_password_hash(form.password.data).decode('utf-8')
        user = User(name=form.name.data, username=form.username.data, email=form.email.data, password=hashed_password,
                    company_id=form.company_id.data, created_ip=request.remote_addr)
        db.session.add(user)
        db.session.commit()
        flash('Your account has been created! You are now able to log in', 'success')
        return redirect(url_for('login'))
    return render_template('register.html', title='Register', form=form)


@app.route("/create_company", methods=['GET', 'POST'])
@login_required
def create_company():
    form = CreateCompany()
    if form.validate_on_submit():
        uuid = create_uuid()
        company = Company(name=form.name.data, uuid=uuid, created_ip=request.remote_addr)
        db.session.add(company)
        db.session.commit()
        return render_template('create_company.html', title='Create company', company=company)
    return render_template('create_company.html', title='Create company', form=form)


@app.route("/create_form", methods=['GET', 'POST'])
@login_required
def create_form():
    form = CreateFormat()
    if form.validate_on_submit():
        company_id = form.company_id.data if form.company_id.data != '' else None
        des = form.company_id.data if form.description.data != '' else None
        new_format = Format(name=form.name.data, url=form.url.data, api=form.api.data, company_id=company_id,
                            description=des, created_ip=request.remote_addr)
        db.session.add(new_format)
        db.session.commit()
        return redirect(url_for('home'))
    return render_template('create_form.html', title='Create company', form=form)


@app.route("/login", methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('home'))
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and bcrypt.check_password_hash(user.password, form.password.data):
            login_user(user, remember=form.remember.data)
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('home'))
        else:
            flash('Login Unsuccessful. Please check email and password', 'danger')
    return render_template('login.html', title='Login', form=form)


@app.route("/history", methods=['GET', 'POST'])
@login_required
def history():
    post = Post.query.filter(Post.user_id.in_([current_user.id])).all()
    results = Result.query.filter(Result.post_id.in_([p.id for p in post])).all()
    res = []
    for data in results:
        r = {
            'id': data.id,
            'name': data.name,
            'raw_path': data.raw_path,
            'output_path': data.output_path,
            'type': data.type,
            'result': json.loads(data.result) if data.result is not None else None,
            'status': data.status,
            'correct_result': data.correct_result,
            'view_status': data.view_status,
            'created_at': data.created_at,
        }
        res.append(r)
    # query = Format.query.filter().all()
    query1 = SubFormat.query.filter_by(company_id=current_user.company_id, format_id=None).all()

    formats = []
    # for data in query:
    #     r = {
    #         'id': data.id,
    #         'name': data.name
    #     }
    #     formats.append(r)
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)
    return render_template('history.html', data={'data': res, 'format': formats})


@app.route("/detail", methods=['GET', 'POST'])
@login_required
def detail():
    post = Post.query.filter(Post.user_id.in_([current_user.id])).all()
    results = Result.query.filter(Result.post_id.in_([p.id for p in post])).all()
    res = []
    for data in results:
        r = {
            'id': data.id,
            'name': data.name,
            'raw_path': data.raw_path,
            'output_path': data.output_path,
            'type': data.type,
            'result': json.loads(data.result) if data.result is not None else None,
            'status': data.status,
            'correct_result': data.correct_result,
            'view_status': data.view_status,
            'created_at': data.created_at,
        }
        res.append(r)
    return render_template('detail.html', data=res)


@app.route("/result")
@login_required
def result():
    id = None
    if 'id' in request.args:
        id = request.args['id']
    post = Post.query.filter(Post.user_id.in_([current_user.id])).all()
    # results = Result.query.filter(Result.post_id.in_([p.id for p in post]), Result.id.in_([id])).all()
    post = ','.join([str(p.id) for p in post])
    results = db.engine.execute('SELECT A.* FROM ('
                                '(SELECT * FROM result WHERE id <= {} AND post_id in ({}) ORDER BY id DESC LIMIT 5)'
                                'UNION (SELECT * FROM result WHERE id > {} AND post_id in ({}) ORDER BY id ASC LIMIT 5 ))'
                                'as A ORDER BY A.id'.format(id, post, id, post))

    res = []
    for data in results:
        r = {
            'id': data.id,
            'name': data.name,
            'raw_path': data.raw_path,
            'output_path': data.output_path,
            'type': data.type,
            'result': json.loads(data.result) if data.result is not None else None,
            'status': data.status,
            'correct_result': data.correct_result,
            'view_status': data.view_status,
            'created_at': data.created_at,
        }
        if id is not None and id == str(data.id):
            form = Format.query.filter_by(name=data.type).first()
            if form is None:
                form = SubFormat.query.filter_by(company_id=current_user.company_id, name=data.type).first()
            if form is not None:
                r['format'] = form.description
        res.append(r)
    return render_template('result.html', data=res)


@app.route("/review")
@login_required
def review():
    package_id = None
    if 'id' in request.args:
        package_id = request.args['id']
    # post = Post.query.filter(Post.user_id.in_([current_user.id])).all()
    # # results = Result.query.filter(Result.post_id.in_([p.id for p in post]), Result.id.in_([id])).all()
    # post = ','.join([str(p.id) for p in post])
    # results = db.engine.execute('SELECT A.* FROM ('
    #                             '(SELECT * FROM result WHERE id <= {} AND post_id in ({}) ORDER BY id DESC LIMIT 5)'
    #                             'UNION (SELECT * FROM result WHERE id > {} AND post_id in ({}) ORDER BY id ASC LIMIT 5 ))'
    #                             'as A ORDER BY A.id'.format(id, post, id, post))
    files = Result.query.filter_by(package_id=package_id)
    package = Package.query.filter_by(id=package_id).first()
    list_files = []
    cnt_confirmed = 0
    for file in files.all():
        r = {
            'id': file.id,
            'name': file.name,
            'raw_path': file.raw_path,
            'output_path': file.output_path,
            'type': file.type,
            'result': json.loads(file.result) if file.result is not None else None,
            'status': file.status,
            'correct_result': file.correct_result,
            'view_status': file.view_status,
            'created_at': file.created_at,
            'deleted_at': file.deleted_at,
        }
        if r['status'] == 5:
            cnt_confirmed += 1
        if id is not None and id == str(file.id):
            form = Format.query.filter_by(name=file.type).first()
            if form is None:
                form = SubFormat.query.filter_by(company_id=current_user.company_id, name=file.type).first()
            if form is not None:
                r['format'] = form.description
        list_files.append(r)
    rate_confirmed = '{}/{}'.format(cnt_confirmed, int(files.count()))
    print(list_files[0])
    return render_template('review.html', data={'data': list_files, 'rate_confirmed': rate_confirmed,
                                                'pack_name': package.package_name})


# Confirm:
@app.route('/review/confirm', methods=['POST'])
@login_required
def confirm_file():
    # file_id = request.form['fileId']
    json_data = request.json
    # file_id = request.form['fileId']
    file_id = json_data['fileId']
    file = Result.query.filter_by(id=file_id).first()
    file.result = json.dumps(json_data['result'])
    file.status = CONFIRMED
    db.session.commit()
    return make_response(
        jsonify(
            {"message": "success"}
        )
    )


@app.route("/test")
@login_required
def test():
    id = None
    if 'id' in request.args:
        id = request.args['id']
    post = Post.query.filter(Post.user_id.in_([current_user.id])).all()
    post = ','.join([str(p.id) for p in post])
    results = db.engine.execute('SELECT A.* FROM ('
                                '(SELECT * FROM result WHERE id <= {} AND post_id in ({}) ORDER BY id DESC LIMIT 5)'
                                'UNION (SELECT * FROM result WHERE id > {} AND post_id in ({}) ORDER BY id ASC LIMIT 5 ))'
                                'as A ORDER BY A.id'.format(id, post, id, post))

    res = []
    for data in results:
        r = {
            'id': data.id,
            'name': data.name,
            'raw_path': data.raw_path,
            'output_path': data.output_path,
            'type': data.type,
            'result': data.result,
            'status': data.status,
            'correct_result': data.correct_result,
            'view_status': data.view_status,
            'created_at': data.created_at,
        }
        if id is not None and id == str(data.id):
            form = Format.query.filter_by(name=data.type).first()
            if form is None:
                form = SubFormat.query.filter_by(company_id=current_user.company_id, name=data.type).first()
            if form is not None:
                r['format'] = form.description
        res.append(r)
    return render_template('test.html', data=res)


@app.route("/templates")
@login_required
def templates():
    template = SubFormat.query.filter_by(company_id=current_user.company_id, format_id=None).all()
    res = []
    for data in template:
        r = {
            'id': data.id,
            'name': data.name,
            'description': data.description,
            'company_id': data.company_id,
            'created_at': data.created_at,
        }
        res.append(r)
    return render_template('templates.html', data=res)


@app.route("/create_template", methods=['GET', 'POST'])
@login_required
def create_template():
    if request.method == 'POST':
        if 'name' in request.form:
            name = request.form['name']
            template = SubFormat.query.filter(
                and_(SubFormat.company_id.in_([current_user.company_id, None]), SubFormat.name == name)).all()
            if (len(template)) > 0:
                return jsonify({'mess': 'Template is existed'}), 400
            else:
                obj = SubFormat(name=name, company_id=current_user.company_id, created_ip=request.remote_addr,
                                created_user=current_user.id)
                db.session.add(obj)
                db.session.commit()
                return jsonify({'id': obj.id})


@app.route("/update_template/<id>")
@login_required
def update_template(id):
    template = SubFormat.query.filter_by(company_id=current_user.company_id, id=id).first()
    res = {
        'id': template.id,
        'name': template.name,
        'description': template.description,
        'img_path': template.img_path,
        'company_id': template.company_id,
        'created_at': template.created_at,
    }
    return render_template('update_template.html', data=res)


@app.route("/delete_result", methods=['GET', 'POST'])
@login_required
def delete_result():
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            for d in obj:
                db.session.delete(d)
            db.session.commit()
            return jsonify({'mess': 'success'})
    return redirect(url_for('home'))


@app.route("/delete_folder", methods=['GET', 'POST'])
@login_required
def delete_folder():
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            result = Result.query.filter(Result.package_id.in_(data)).all()
            for file in result:
                db.session.delete(file)
            db.session.commit()
            obj = Package.query.filter(Package.id.in_(data)).all()
            for d in obj:
                db.session.delete(d)
            db.session.commit()
            return jsonify({'mess': 'success'})
    return redirect(url_for('home'))


@app.route("/delete_template", methods=['POST'])
@login_required
def delete_template():
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            id = id.split(',')
            for index in id:
                obj = SubFormat.query.filter_by(id=index).first()
                db.session.delete(obj)
            db.session.commit()
        return jsonify({'mess': 'success'})
    return redirect(url_for('templates'))


@app.route("/duplicate_template", methods=['POST'])
@login_required
def duplicate_template():
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            id = id.split(',')
            # for index in id:
            obj = SubFormat.query.filter_by(id=id).first()
            name = obj.name + ' (COPY)'
            obj = SubFormat(name=name, description=obj.description, img_path=obj.img_path, format_id=obj.format_id,
                            company_id=obj.company_id, created_ip=obj.created_ip, created_user=obj.created_user)
            db.session.add(obj)
            db.session.commit()
            return jsonify({'id': obj.id})
        return jsonify({'mess': 'success'})
    return redirect(url_for('templates'))


@app.route("/rename_template", methods=['POST'])
@login_required
def rename_template():
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            if 'name' in request.form:
                name = request.form['name']
                obj = SubFormat.query.filter_by(id=id).first()
                obj.name = name
                db.session.commit()
        return jsonify({'mess': 'success'})
    return redirect(url_for('templates'))


@app.route("/export", methods=['POST'])
@login_required
def export():
    import xlwt
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            book = xlwt.Workbook(encoding="utf-8")
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
            for d in obj:
                if d.result is not None:
                    name = d.name
                    if len(d.name) > 30:
                        name = name[:30]
                    sheet = book.add_sheet(name)
                    sheet.write(0, 0, "ID")
                    sheet.write(0, 1, "Text")
                    sheet.write(0, 2, "Probability")
                    i = 1
                    res = json.loads(d.result)
                    for x in res['raw']['result']:
                        sheet.write(i, 0, x['id'])
                        sheet.write(i, 1, x['text'])
                        sheet.write(i, 2, x['prob'])
                        i += 1
            book.save(os.path.join(UPLOAD_DIR, path))
            return jsonify({'path': '/static/uploaded/' + path})


@app.route("/save_export", methods=['POST'])
@login_required
def save_export():
    import xlwt
    if request.method == 'POST':
        if 'id' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            book = xlwt.Workbook(encoding="utf-8")
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
            if obj.result is not None:
                name = obj.name
                if len(obj.name) > 30:
                    name = name[:30]
                sheet = book.add_sheet(name)
                sheet.write(0, 0, "ID")
                sheet.write(0, 1, "Text")
                c = 1
                res = json.loads(obj.result)
                for i, x in enumerate(res['raw']['result']):
                    sheet.write(c, 0, i)
                    sheet.write(c, 1, x['text'])
                    c += 1
            book.save(os.path.join(UPLOAD_DIR, path))
            return jsonify({'path': '/static/uploaded/' + path})


@app.route("/save", methods=['POST'])
@login_required
def save_data():
    # import xlwt
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data']
            obj = Result.query.filter_by(id=request.form['id']).first()
            # book = xlwt.Workbook(encoding="utf-8")
            # path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
            obj.result = data
            db.session.commit()

            return jsonify({'success': True})


@app.route("/exportv2", methods=['POST'])
@login_required
def exportv2():
    if request.method == 'POST':
        if 'data' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            templates = SubFormat.query.filter(company_id=current_user.company_id).all()
            temp = [t.name for t in templates]
            if obj.type in temp:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                tmp = None
                for t in templates:
                    if obj.type == t.name:
                        tmp = json.loads(t.description)
                        break
                f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                extracted = json.loads(obj.result)['extracted']

                keys = sorted(tmp['results'], key=itemgetter('position'))
                rows = [[d['key'] for d in keys]]
                m = 0
                for x in extracted:
                    merge = []
                    for i in extracted[x]:
                        merge = merge + i
                    extracted[x] = merge
                    if len(extracted[x]) > m:
                        m = len(extracted[x])
                for i in range(m):
                    r = []
                    for x in keys:
                        try:
                            r.append(extracted[x['key']][i])
                        except:
                            r.append('')
                    rows.append(r)
                for row in rows:
                    f.write(','.join(row))
                    f.write('\n')
                return jsonify({'path': '/static/uploaded/' + path})


@app.route("/exportv3", methods=['POST'])
@login_required
def exportv3():
    if request.method == 'POST':
        if 'id' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            templates = SubFormat.query.filter_by(company_id=current_user.company_id).all()
            temp = [t.name for t in templates]
            # data = request.form['data']
            # obj.result = data
            if obj.type in temp:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                tmp = None
                for t in templates:
                    if obj.type == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                if obj.result is not None:
                    extracted = json.loads(obj.result)['extracted']
                    print(extracted)
                    # =======
                    #                     suggestion = json.loads(obj.result)['suggestion']
                    #                     skeys = {}
                    #                     for s in suggestion:
                    #                         skeys[s['key']] = s['text']
                    # >>>>>>> aeaa8f5edb415033abf3b16d69eabe2629de5769

                    if extracted is not None:
                        if tmp is not None:
                            srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                            keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                            # rows = [[d['key'] for d in keys]]
                            if len(keys) > 0:
                                arrayl = srt[keys[-1]['position']]
                            else:
                                arrayl = 0

                            list_keys = [''] * (arrayl + 1)
                            for d in keys:
                                list_keys[srt[d['position']]] = d['key']

                            if len(keys) < len(extracted):
                                for d in extracted:
                                    if d not in list_keys:
                                        list_keys.append(d)
                            print(list_keys)

                            if len(suggestion) > 0:
                                list_keys = list_keys + [s['key'] for s in suggestion]
                            rows = [list_keys]
                            m = 0
                            for x in extracted:
                                merge = []
                                for i in extracted[x]:
                                    merge = merge + i
                                extracted[x] = merge
                                if len(extracted[x]) > m:
                                    m = len(extracted[x])
                            for i in range(m):
                                r = []
                                for x in list_keys:
                                    try:
                                        if x in [s['key'] for s in suggestion]:
                                            r.append(skeys[x].replace(',', '').replace('\t', ''))
                                        else:
                                            r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                    except:
                                        r.append('')
                                rows.append(r)
                        else:
                            keys = []
                            rows = []
                            m = 0
                            for k in extracted:
                                keys.append(k)
                                l = len(extracted[k][0])
                                if l > m:
                                    m = l
                            if len(suggestion) > 0:
                                keys = keys + [s['key'] for s in suggestion]
                            rows.append(keys)
                            for i in range(m):
                                r = []
                                for z in keys:
                                    try:
                                        if z in [s['key'] for s in suggestion]:
                                            r.append(skeys[z].replace(',', '').replace('\t', ''))
                                        else:
                                            r.append(extracted[z][0][i]['text'].replace(',', '').replace('\t', ''))
                                    except Exception as e:
                                        print(e)
                                        r.append('')
                                if i == 1 and len(suggestion) > 0:
                                    r = r + [s['text'].replace(',', '').replace('\t', '') for s in suggestion]
                                rows.append(r)
                        f.write("\uFEFF")
                        for row in rows:
                            f.write(','.join(row))
                            f.write('\n')
                        f.close()
                        return jsonify({'path': '/static/uploaded/' + path})
            else:
                if obj.result is not None:
                    extracted = json.loads(obj.result)['extracted']
                    print(extracted)
                    path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                    f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                    if extracted is not None:
                        f.write("\uFEFF")
                        f.write('項目,認識結果\n')
                        for data in extracted:
                            text = [x['text'].replace(',', '') for x in extracted[data][0]]
                            f.write('{},{}\n'.format(data, ','.join(text)))
                        f.close()
                        return jsonify({'path': '/static/uploaded/' + path})
                    else:
                        extracted = json.loads(obj.result)['raw']
                        if extracted is not None:
                            extracted = extracted['result']
                            f.write("\uFEFF")
                            f.write('項目,認識結果\n')
                            for data in extracted:
                                # text = [x['text'].replace(',', '') for x in extracted[data][0]]
                                f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                            f.close()
                        return jsonify({'path': '/static/uploaded/' + path})
    return jsonify({'success': False}), 400


@app.route("/export_multiple", methods=['POST'])
@login_required
def export_multiple():
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            templates = SubFormat.query.filter_by(company_id=current_user.company_id).all()
            temp = {}
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f")
            if not os.path.exists(os.path.join(UPLOAD_DIR, path)):
                os.mkdir(os.path.join(UPLOAD_DIR, path))

            for d in obj:
                if d.type not in temp:
                    temp[d.type] = []
                temp[d.type].append(d)

            for ty in temp:
                tmp = None
                for t in templates:
                    if ty == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                if tmp is not None:
                    srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                    keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                    # rows = [[d['key'] for d in keys]]
                    if len(keys) > 0:
                        arrayl = srt[keys[-1]['position']]
                    else:
                        arrayl = 0

                    list_keys = [''] * (arrayl + 1)
                    for d in keys:
                        list_keys[srt[d['position']]] = d['key']
                    rows = [list_keys]

                    for obj in temp[ty]:
                        extracted = json.loads(obj.result)['extracted']
                        m = 0
                        # for key in extracted:
                        #     for i in range(len(extracted[key])):
                        #         extracted[key][i] = sorted(extracted[key][i], key=itemgetter('y'))
                        for x in extracted:
                            merge = []
                            for i in extracted[x]:
                                merge = merge + i
                            extracted[x] = merge
                            if len(extracted[x]) > m:
                                m = len(extracted[x])
                        for i in range(m):
                            r = []
                            for x in list_keys:
                                try:
                                    r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                except:
                                    r.append('')
                            rows.append(r)
                    f = open(os.path.join(UPLOAD_DIR, path, '{}.csv'.format(ty)), 'w', encoding="utf-8")

                    f.write("\uFEFF")
                    for row in rows:
                        f.write(','.join(row))
                        f.write('\n')
                    f.close()
                else:
                    for obj in temp[ty]:
                        fname = os.path.join(UPLOAD_DIR, path, '{}_{}.csv'.format(obj.name, obj.id))
                        f = open(fname, 'w', encoding="utf-8")
                        rows = []
                        if obj.result is not None:
                            extracted = json.loads(obj.result)['extracted']
                            if extracted is not None:
                                keys = []
                                m = 0
                                for k in extracted:
                                    keys.append(k)
                                    l = len(extracted[k][0])
                                    if l > m:
                                        m = l
                                rows.append(keys)
                                for i in range(m):
                                    r = []
                                    for z in keys:
                                        try:
                                            r.append(extracted[z][0][i]['text'].replace(',', ''))
                                        except Exception as e:
                                            print(e)
                                            r.append('')
                                    rows.append(r)
                                f.write("\uFEFF")
                                for row in rows:
                                    f.write(','.join(row))
                                    f.write('\n')
                                f.close()
                            else:
                                extracted = json.loads(obj.result)['raw']
                                f.write("\uFEFF")
                                f.write('項目,認識結果\n')
                                if extracted is not None:
                                    extracted = extracted['result']
                                    for data in extracted:
                                        # text = [x['text'].replace(',', '') for x in extracted[data][0]]
                                        f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                                    f.close()

            import shutil

            shutil.make_archive(os.path.join(UPLOAD_DIR, path), 'zip', os.path.join(UPLOAD_DIR, path))

            # zipf = zipfile.ZipFile('{}.zip'.format(path), 'w')
            # zipdir(os.path.join(UPLOAD_DIR, path), zipf)
            # zipf.close()

            return jsonify({'path': '/static/uploaded/' + '{}.zip'.format(path)})


@app.route("/export_multiple_package", methods=['POST'])
@login_required
def export_package():
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.package_id.in_(data)).all()
            templates = SubFormat.query.filter_by(company_id=current_user.company_id).all()
            temp = {}
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f")
            if not os.path.exists(os.path.join(UPLOAD_DIR, path)):
                os.mkdir(os.path.join(UPLOAD_DIR, path))

            for d in obj:
                if d.type not in temp:
                    temp[d.type] = []
                temp[d.type].append(d)

            for ty in temp:
                tmp = None
                for t in templates:
                    if ty == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                if tmp is not None:
                    srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                    keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                    # rows = [[d['key'] for d in keys]]
                    if len(keys) > 0:
                        arrayl = srt[keys[-1]['position']]
                    else:
                        arrayl = 0

                    list_keys = [''] * (arrayl + 1)
                    for d in keys:
                        list_keys[srt[d['position']]] = d['key']
                    rows = [list_keys]

                    for obj in temp[ty]:
                        extracted = json.loads(obj.result)['extracted']
                        m = 0
                        # for key in extracted:
                        #     for i in range(len(extracted[key])):
                        #         extracted[key][i] = sorted(extracted[key][i], key=itemgetter('y'))
                        for x in extracted:
                            merge = []
                            for i in extracted[x]:
                                merge = merge + i
                            extracted[x] = merge
                            if len(extracted[x]) > m:
                                m = len(extracted[x])
                        for i in range(m):
                            r = []
                            for x in list_keys:
                                try:
                                    r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                except:
                                    r.append('')
                            rows.append(r)
                    f = open(os.path.join(UPLOAD_DIR, path, '{}.csv'.format(ty)), 'w', encoding="utf-8")

                    f.write("\uFEFF")
                    for row in rows:
                        f.write(','.join(row))
                        f.write('\n')
                    f.close()
                else:
                    for obj in temp[ty]:
                        fname = os.path.join(UPLOAD_DIR, path, '{}_{}.csv'.format(obj.name, obj.id))
                        f = open(fname, 'w', encoding="utf-8")
                        rows = []
                        if obj.result is not None:
                            extracted = json.loads(obj.result)['extracted']
                            if extracted is not None:
                                keys = []
                                m = 0
                                for k in extracted:
                                    keys.append(k)
                                    l = len(extracted[k][0])
                                    if l > m:
                                        m = l
                                rows.append(keys)
                                for i in range(m):
                                    r = []
                                    for z in keys:
                                        try:
                                            r.append(extracted[z][0][i]['text'].replace(',', ''))
                                        except Exception as e:
                                            print(e)
                                            r.append('')
                                    rows.append(r)
                                f.write("\uFEFF")
                                for row in rows:
                                    f.write(','.join(row))
                                    f.write('\n')
                                f.close()
                            else:
                                extracted = json.loads(obj.result)['raw']
                                f.write("\uFEFF")
                                f.write('項目,認識結果\n')
                                if extracted is not None:
                                    extracted = extracted['result']
                                    for data in extracted:
                                        # text = [x['text'].replace(',', '') for x in extracted[data][0]]
                                        f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                                    f.close()

            import shutil

            shutil.make_archive(os.path.join(UPLOAD_DIR, path), 'zip', os.path.join(UPLOAD_DIR, path))

            # zipf = zipfile.ZipFile('{}.zip'.format(path), 'w')
            # zipdir(os.path.join(UPLOAD_DIR, path), zipf)
            # zipf.close()

            return jsonify({'path': '/static/uploaded/' + '{}.zip'.format(path)})


# @app.route("/export_extracted", methods=['POST'])
# @login_required
# def export_extracted():
#     import xlwt
#     if request.method == 'POST':
#         if 'data' in request.form:
#             data = request.form['data']
#             obj = Result.query.filter_by(id=request.form['id']).first()
#             book = xlwt.Workbook(encoding="utf-8")
#             path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
#             obj.result = data
#             if obj.result is not None:
#                 name = obj.name
#                 if len(obj.name) > 30:
#                     name = name[:30]
#                 sheet = book.add_sheet(name)
#                 sheet.write(0, 0, "ID")
#                 sheet.write(0, 1, "Text")
#                 c = 1
#                 res = json.loads(obj.result)
#                 for key in res['extracted']:
#                     sheet.write(c, 0, key)
#                     sheet.write(c, 1, res['extracted'][key])
#                     c += 1
#             db.session.commit()
#             book.save(os.path.join(UPLOAD_DIR, path))
#             return jsonify({'path': '/static/uploaded/' + path})


@app.route("/save_template", methods=['POST'])
@login_required
def save_template():
    if request.method == 'POST':
        if 'data' in request.form:
            data = json.loads(request.form['data'])
            obj = SubFormat.query.filter_by(company_id=current_user.company_id, id=request.form['id']).first()
            if 'file' in request.files:
                file = request.files['file']
                if file.filename.lower().endswith('.pdf'):
                    pages = convert_from_bytes(file.read())
                    img = np.array(pages[0])
                    img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
                else:
                    img = cv2.imdecode(np.fromstring(file.read(), np.uint8), cv2.IMREAD_COLOR)

                # if file.filename != 'blob':
                #     path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.' + file.filename.rsplit('.', 1)[1].lower()
                # else:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.jpg'
                # img = rotate(img)
                cv2.imwrite(os.path.join(UPLOAD_DIR, path), img)
                # img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                img_h = img.shape[0]
                img_w = img.shape[1]
            else:
                path = obj.img_path
                temp = json.loads(obj.description)
                img_h = temp['img_h']
                img_w = temp['img_w']
            d = {
                'results': data,
                'img_h': img_h,
                'img_w': img_w
            }
            obj.description = json.dumps(d)
            obj.img_path = path
            db.session.commit()
            return jsonify({'mess': 'success'})
        return jsonify({'mess': 'error'}), 400


@app.route("/update_pass", methods=['POST'])
@login_required
def update_pass():
    if request.method == 'POST':
        if 'pass' in request.form:
            data = request.form['pass']
            user = User.query.filter_by(id=current_user.id).first()
            user.password = bcrypt.generate_password_hash(data).decode('utf-8')
            db.session.commit()
    return redirect(url_for('profile'))


@app.route("/update_infor", methods=['POST'])
@login_required
def update_infor():
    if request.method == 'POST':
        if 'name' in request.form:
            data = request.form['name']
            user = User.query.filter_by(id=current_user.id).first()
            user.name = data
            db.session.commit()
    return redirect(url_for('profile'))


@app.route("/update_avatar", methods=['POST'])
@login_required
def update_avatar():
    if request.method == 'POST':
        if 'avatar' in request.files:
            file = request.files['avatar']
            filename = secure_filename(file.filename)
            file.save(os.path.join(IMG_DIR, filename))
            user = User.query.filter_by(id=current_user.id).first()
            user.image_file = filename
            db.session.commit()
    return redirect(url_for('profile'))


@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for('home'))


@app.route("/account", methods=['GET', 'POST'])
@login_required
def account():
    form = UpdateAccountForm()
    if form.validate_on_submit():
        if form.picture.data:
            picture_file = save_picture(form.picture.data)
            current_user.image_file = picture_file
        current_user.username = form.username.data
        current_user.email = form.email.data
        db.session.commit()
        flash('Your account has been updated!', 'success')
        return redirect(url_for('account'))
    elif request.method == 'GET':
        form.username.data = current_user.username
        form.email.data = current_user.email
    image_file = url_for('static', filename='profile_pics/' + current_user.image_file)
    return render_template('account.html', title='Account', image_file=image_file, form=form)


@app.route("/update_view_status", methods=['POST'])
@login_required
def update_view_status():
    if request.method == 'POST':
        if 'id' in request.form:
            index = request.form['id']
            obj = Result.query.filter_by(id=index).first()
            obj.view_status = True
            db.session.commit()
        return jsonify({'mess': 'success'})


@app.route("/upload", methods=['GET', 'POST'])
@app.route("/report", endpoint='report', methods=['GET', 'POST'])
@app.route("/license_plate", endpoint='license_plate', methods=['GET', 'POST'])
@app.route("/driver_license", endpoint='driver_license', methods=['GET', 'POST'])
@app.route("/vehicle_verification", endpoint='vehicle_verification', methods=['GET', 'POST'])
@login_required
def upload():
    user = User.query.filter_by(id=current_user.id).first()

    query = Format.query.filter().all()
    query1 = SubFormat.query.filter_by(company_id=current_user.company_id).all()

    if request.method == 'POST':
        if int(user.limited) <= 0:
            return jsonify({'mess': 'limited'}), 400
        post = Post(user_id=current_user.id, created_ip=request.remote_addr)
        db.session.add(post)
        # Save package:
        package_name = request.form['packageName']
        package = Package(user_id=current_user.id, package_type='temporary', package_name=package_name,
                          created_ip=request.remote_addr)

        img_data = request.files.getlist('img_data[]')
        for i, file in enumerate(img_data):
            img_type = request.form['type_img_' + str(i)]
            img_name = request.form['name_' + str(i)]
            type_name = 'unselected'
            if img_type != '':
                for d in query:
                    if int(img_type) == int(d.id):
                        type_name = d.name

                        break
                for d in query1:
                    if int(img_type) == int(d.id):
                        type_name = d.name
                        break
            # Add package object to db
            # type_name = type_name if request.endpoint == 'upload' else None
            if not i:
                package.package_type = type_name
                db.session.add(package)
                db.session.commit()

            try:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.' + file.filename.rsplit('.', 1)[
                    1].lower()
                file.save(os.path.join(UPLOAD_DIR, path))
                if path.lower().endswith('.pdf'):
                    pages = convert_from_path(os.path.join(UPLOAD_DIR, path))
                    for idx, page in enumerate(pages):
                        img_path = path.rsplit('.', 1)[0] + '_' + str(idx) + '.jpg'
                        img = np.array(page)
                        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
                        # img = rotate(img)
                        cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                        name = img_name + '_' + str(idx)
                        if user.limited > 0:
                            user.limited -= 1
                            # Save image:
                            result = Result(name=name, raw_path=img_path, type=type_name, status=WAITING,
                                            post_id=post.id, created_ip=request.remote_addr, package_id=package.id)
                            db.session.add(result)
                            db.session.commit()
                elif path.lower().endswith('.tiff') or path.lower().endswith('.tif'):
                    img_path = path.rsplit('.', 1)[0] + '.jpg'
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=img_path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.commit()
                else:
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.commit()
            except Exception as e:
                print(e)
        return jsonify({'mess': 'success', 'pack_id': package.id})
    formats = []
    subform = SubFormat.query.filter_by(company_id=current_user.company_id).all()
    subforms = []
    if len(subform) > 0:
        for x in subform:
            sub = {
                'id': x.id,
                'name': x.name
            }
            subforms.append(sub)
    for data in query:
        if data.company_id is None or data.company_id == current_user.company_id:
            sub = [x for x in subforms if x['id'] == data.id]
            d = {
                'id': data.id,
                'name': data.name,
                'url': data.url,
                'api': data.api,
                'description': data.description,
                'sub_form': sub[0] if len(sub) > 0 else None,
                'company_id': data.company_id,
                'created_user': data.created_user,
            }
            formats.append(d)
    m = None
    if request.endpoint == 'report':
        m = REPORT
    if request.endpoint == 'license_plate':
        m = LICENSE_PLATE
    if request.endpoint == 'driver_license':
        m = DRIVER_LICENSE
    if request.endpoint == 'vehicle_verification':
        m = VEHICLE_VERIFICATION
    form = None
    for x in formats:
        if x['name'] == m:
            form = x
            break
    res = {
        'form': form,
        'subforms': subforms
    }
    
    return render_template('upload.html', title='Upload', data=res)


def update_sql_v2(data, company_id):
    formats = Format.query.filter().all()
    formats2 = SubFormat.query.filter_by(company_id=company_id).all()
    res = None
    f1 = [f.name for f in formats]
    f2 = [f.name for f in formats2]
    for d in data:
        try:
            if 'result' in d and d['result'] is not None:
                res = Result.query.filter_by(id=d['id']).first()
                if d['type'] in f1:
                    if d['type'] == REPORT:
                        output_image =  API_URL + '/static/img/' + d['result']['img'][0]
                        res.output_path = download(output_image)

                        # m = d['result']['text'][0]['raw']['result']
                        # boxes = sorted(m, key=lambda t: (t['y'], t['x']))
                        # print('-----boxes----\n', boxes)

                        resa = ext.main(os.path.join(UPLOAD_DIR, res.raw_path), d['result']['text'][0]['raw'])
                        d['result']['text'][0]['extracted'] = resa

                        # d['result']['text'][0]['extracted'] = process_res(d['result']['text'][0]['raw'])

                        res.result = json.dumps(d['result']['text'][0])
                        # res.raw_path = None
                        res.status = EXECUTED
                        # with open('E:/aimenext/aime-ocr/main/result.json', 'w') as fc:
                        #     json.dump(json.loads(res.result), fc, indent=3)
                        # print('---RESULT---')
                        # print(json.dumps(json.loads(res.result), indent=3, ensure_ascii=False))
                    elif d['type'] == VEHICLE_VERIFICATION:
                        output_url = Format.query.filter_by(name=VEHICLE_VERIFICATION).first().output
                        output_image = output_url + d['result']['img']
                        print('output', output_image)
                        # print(json.loads(d['result']))
                        # with open('car_result.json', 'w') as fc:
                        #     json.dump(json.loads(d['result'], fc, indent=4))

                        res.output_path = download(output_image)
                        tmp = {'extracted': {}, 'raw': d['result']['extra_result'],
                               'brand': d['result']['maker'].strip('0123456789').upper()}

                        for box in tmp['raw']['result']:
                            x1, y1 = tuple(ast.literal_eval(box['p1']))
                            x2, y2 = tuple(ast.literal_eval(box['p2']))
                            x3, y3 = tuple(ast.literal_eval(box['p3']))
                            x4, y4 = tuple(ast.literal_eval(box['p4']))
                            top_left_x = int(min([x1, x2, x3, x4]))
                            top_left_y = int(min([y1, y2, y3, y4]))
                            bot_right_x = int(max([x1, x2, x3, x4]))
                            bot_right_y = int(max([y1, y2, y3, y4]))
                            w = bot_right_x - top_left_x
                            h = bot_right_y - top_left_y
                            for key in ['p1', 'p2', 'p3', 'p4']:
                                box.pop(key)
                            box['x'] = top_left_x
                            box['y'] = top_left_y
                            box['w'] = w
                            box['h'] = h
                            box['category'] = "MACHINE_PRINTED_TEXT"

                        bboxes = d['result']['bboxes']
                        idx = 0
                        # print('-----------------here---------------------')
                        for key, value in d['result']['text'][0].items():
                            # print(key, ':  ', value)
                            tmp['extracted'][key] = [
                                [
                                    {
                                        "category": "MACHINE_PRINTED_TEXT",
                                        "direction": bboxes[key]['direction'],
                                        "id": idx,
                                        "text": value,
                                        "h": bboxes[key]['h'],
                                        "w": bboxes[key]['w'],
                                        "x": bboxes[key]['x'],
                                        "y": bboxes[key]['y']
                                    }
                                ]
                            ]
                            idx += 1

                        # print(json.dumps(tmp))
                        res.result = json.dumps(tmp)
                        res.status = EXECUTED
                    else:
                        for f in formats:
                            if d['type'] == f.name:
                                output_image = f.output + d['result']['img'][0]
                                res.output_path = download(output_image)
                                res.result = json.dumps(d['result']['text'][0])
                                # res.raw_path = None
                                res.status = EXECUTED
                elif d['type'] in f2:
                    output_image = API_URL + '/static/img/' + d['result']['img'][0]
                    res.output_path = download(output_image)
                    res.result = json.dumps(d['result']['text'])
                    res.status = EXECUTED
                else:
                    output_image = API_URL + '/static/img/' + d['result']['img'][0]
                    res.output_path = download(output_image)
                    res.result = json.dumps(d['result']['text'])
                    res.status = EXECUTED
                db.session.commit()
            else:
                res = Result.query.filter_by(id=d['id']).first()
                res.status = ERROR
                db.session.commit()
            r = {
                'id': res.id,
                'name': res.name,
                'raw_path': res.raw_path,
                'output_path': res.output_path,
                'type': res.type,
                'result': json.loads(res.result) if res.result is not None else None,
                'status': res.status,
                'correct_result': res.correct_result,
                'view_status': res.view_status,
                'created_at': res.created_at.strftime("%Y-%m-%d %H:%M:%S")
            }
            db.session.remove()
            socketio.emit('update value', {'data': [r], 'pkgId': res.package_id if res is not None else None}, namespace='/start_processing')
        except Exception as e:
            print(e)

import editdistance

def process_res(data):
    res = {}
    for x in data['result']:
    #    for y in drug_dict:
    #        if editdistance.eval(x['text'], y) / len(x['text']) < 0.3:
    #            x['text'] = y
    #            break
        res[x['id']] = [[x]]
    return res


def process_res_report(data):
    res = {}
    index = 1
    threshold_ratio_w = 100
    threshold_ratio_h = 100
    for x in data['result']:
        if data['size_w'] / x['w'] < threshold_ratio_w and data['size_h'] / x['h'] < threshold_ratio_h:
            res[str(index)] = [[x]]
            index += 1
    return res


# Check folder name:
@app.route('/checkPackage', methods=['POST'])
@login_required
def check_package():
    package_name = request.form['packageName']
    obj = Package.query.filter_by(package_name=package_name).first()
    mess = 'success' if not obj else 'fail'
    return make_response(
        jsonify(
            {"message": mess}
        )
    )


# Get list packages:
@app.route('/listPackage', methods=['GET'])
@login_required
def get_list_packages():
    packages = Package.query.filter(Package.user_id.in_([current_user.id])).order_by(asc(Package.id)).all()
    list_pacs = []
    for package in packages:
        user_name = User.query.filter_by(id=package.user_id).first().username
        files = Result.query.filter_by(package_id=package.id)
        cnt_confirmed = 0
        for file in files.all():
            if file.status == 5:
                cnt_confirmed += 1
        rate_confirmed = '{}/{}'.format(cnt_confirmed, int(files.count()))
        r = {
            'id': package.id,
            'name': package.package_name,
            'raw_path': "null",
            'output_path': None,
            'type': package.package_type if package.package_type else 'null',
            'result': None,
            'status': "None",
            'rate_confirmed': rate_confirmed,
            'correct_result': None,
            'view_status': None,
            'created_at': package.created_at,
            'created_ip': package.created_ip,
            'deleted_at': package.deleted_at,
            'user_name': user_name,
        }
        list_pacs.append(r)

    query1 = SubFormat.query.filter_by(company_id=current_user.company_id, format_id=None).all()
    formats = []
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)
    # return jsonify( data = list_pacs )
    return render_template('folder_list.html', data={'data': list_pacs, 'format': formats})


# Get list files:
@app.route('/listPackage/<packageId>', methods=['GET', 'POST'])
@login_required
def get_list_files(packageId):
    package = Package.query.filter_by(id=packageId).first()
    user = User.query.filter_by(id=current_user.id).first()
    query = Format.query.filter().all()
    query1 = SubFormat.query.filter_by(company_id=current_user.company_id).all()
    if request.method == 'POST':
        if int(user.limited) <= 0:
            return jsonify({'mess': 'limited'}), 400
        post = Post(user_id=current_user.id, created_ip=request.remote_addr)
        db.session.add(post)
        db.session.commit()

        img_data = request.files.getlist('img_data[]')
        for i, file in enumerate(img_data):
            img_type = request.form['type_img_' + str(i)]
            img_name = request.form['name_' + str(i)]
            if package:
                type_name = package.package_type
            else:
                type_name = None
            # if img_type != '':
            #     for d in query:
            #         if int(img_type) == int(d.id):
            #             type_name = d.name
            #             break
            #     for d in query1:
            #         if int(img_type) == int(d.id):
            #             type_name = d.name
            #             break
            # Add package object to db

            try:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.' + file.filename.rsplit('.', 1)[
                    1].lower()
                file.save(os.path.join(UPLOAD_DIR, path))
                if path.lower().endswith('.pdf'):
                    pages = convert_from_path(os.path.join(UPLOAD_DIR, path))
                    for idx, page in enumerate(pages):
                        img_path = path.rsplit('.', 1)[0] + '_' + str(idx) + '.jpg'
                        img = np.array(page)
                        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
                        # img = rotate(img)
                        cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                        name = img_name + '_' + str(idx)
                        if user.limited > 0:
                            user.limited -= 1
                            # Save image:
                            result = Result(name=name, raw_path=img_path, type=type_name, status=WAITING,
                                            post_id=post.id, created_ip=request.remote_addr, package_id=package.id)
                            db.session.add(result)
                            db.session.commit()
                elif path.lower().endswith('.tiff') or path.lower().endswith('.tif'):
                    img_path = path.rsplit('.', 1)[0] + '.jpg'
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=img_path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.commit()
                else:
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.commit()
            except Exception as e:
                print(e)
        return jsonify({'mess': 'success', 'pack_id': package.id})

    files = Result.query.filter_by(package_id=package.id).all()
    list_files = []
    for file in files:
        list_files.append({
            'id': file.id,
            'name': file.name,
            'raw_path': file.raw_path,
            'output_path': file.output_path,
            'type': file.type,
            'result': json.loads(file.result) if file.result is not None else None,
            'status': file.status,
            'correct_result': file.correct_result,
            'post_id': file.post_id,
            'view_status': file.view_status,
            'created_at': file.created_at,
            'created_ip': file.created_ip,
            'deleted_at': file.deleted_at,
        })
    # return jsonify(listFiles= list_files)
    query1 = SubFormat.query.filter_by(company_id=current_user.company_id, format_id=None).all()
    formats = []
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)
    return render_template('file_list.html', data={'data': list_files, 'format': formats, 'pack_id': package.id})


@start_new_thread
def processing_thread(data, company_id):
    formats = Format.query.filter().all()
    formats2 = SubFormat.query.filter_by(company_id=company_id).all()
    f1 = [f.name for f in formats]
    f2 = [f.name for f in formats2]
    resa = []
    # print(f2)
    for d in data:
        try:
            if d['type'] in f1:
                for f in formats:
                    if f.name == d['type']:
                        files = {'file': open(os.path.join(UPLOAD_DIR, d['name']), 'rb')}
                        url = f.url + f.api
                        r = requests.post(url, files=files, verify=False)

                        # with open('E:/aimenext/aime-ocr/main/raw.json', 'w') as fc:
                        #     json.dump(r.json(), fc, indent=4)
                        # print('-----------------RAW-----------\n', json.dumps(r.json(), indent=3, ensure_ascii=False))

                        d['result'] = r.json()
                        print('---------------------------\n', r.json())
                        d['status'] = EXECUTED
                        break
            elif d['type'] in f2:
                for f in formats2:
                    if d['type'] == f.name:
                        url = API_URL + '/get_text_cropped'
                        if f.description is not None:
                            width = int(json.loads(f.description)['img_w'])
                            height = int(json.loads(f.description)['img_h'])
                            img = cv2.imread(os.path.join(UPLOAD_DIR, d['name']), cv2.IMREAD_UNCHANGED)
                            img = cv2.resize(img, (width, height), interpolation=cv2.INTER_LINEAR)
                            cv2.imwrite(os.path.join(UPLOAD_DIR, d['name']), img)

                        files = {'file': open(os.path.join(UPLOAD_DIR, d['name']), 'rb')}
                        if f.description is not None:
                            payload = {'description': f.description}
                        else:
                            payload = {}
                        r = requests.post(url, data=payload, files=files)
                        res = r.json()
                        # with open('/home/phucnp/aimenext/aime-ocr/test/template2_result.txt', 'w+') as fc:
                        #     json.dump(res, fc, indent=3, ensure_ascii=False)
                        if f.description is not None:
                            extracted = extract(res['text'], json.loads(f.description)['results'])
                        else:
                            extracted = ext.extract_info(res['text'])
                        text = {
                            'extracted': extracted,
                            'raw': res['text']
                        }
                        d['result'] = {
                            'img': res['img'],
                            'text': text
                        }
                        d['status'] = EXECUTED
                        break
            else:
                # print('F3')
                # time.sleep(2)
                url = API_URL
                files = {'file': open(os.path.join(UPLOAD_DIR, d['name']), 'rb')}
                r = requests.post(url, files=files)
                res = r.json()
                text = {
                    'extracted': process_res(res['text'][0]['raw']),
                    'raw': res['text'][0]['raw']
                }
                d['result'] = {
                    'img': res['img'],
                    'text': text
                }
                d['status'] = EXECUTED
        except Exception as e:
            print("AAAAAAAAAAAAA", e)
            d['status'] = ERROR
            d['result'] = None

        resa.append(d)
        # socketio.emit('update value', {'data': [d]}, namespace='/start_processing')
        update_sql_v2([d], company_id)


@socketio.on('connect', namespace='/start_processing')
def start_processing():
    emit('connected', {'mess': 'Connect success'})


@socketio.on('process', namespace='/start_processing')
def process(message):
    message = message['data']
    obj = Result.query.filter(Result.id.in_(message)).all()
    user = User.query.filter_by(id=current_user.id).first()
    data = []
    res = []
    for ob in obj:
        ob.status = PROCESSING
        ob.type = message[str(ob.id)]
        d = {
            'id': ob.id,
            'name': os.path.join(UPLOAD_DIR, ob.raw_path),
            'type': ob.type
        }
        if int(user.limited) > 0:
            user.limited -= 1
            r = {
                'id': ob.id,
                'name': ob.name,
                'raw_path': ob.raw_path,
                'output_path': ob.output_path,
                'type': ob.type,
                'result': json.loads(ob.result) if ob.result is not None else None,
                'status': ob.status,
                'correct_result': ob.correct_result,
                'view_status': ob.view_status,
                'created_at': ob.created_at.strftime("%Y-%m-%d %H:%M:%S")
            }
            res.append(r)
            data.append(d)
        else:
            ob.status = LIMITED
        db.session.commit()
    socketio.emit('update value', {'data': res}, namespace='/start_processing')
    socketio.start_background_task(processing_thread, data, current_user.company_id)


@app.route("/get_text", methods=['GET', 'POST'])
@login_required
def get_text():
    url = API_URL + '/get_text'
    if 'file' in request.files:
        try:
            file = request.files['file']
            if 'model' in request.form:
                model = request.form['model']
            else:
                model = None
            if 'rows' in request.form:
                rows = request.form['rows']
            else:
                rows = 1
            if 'columns' in request.form:
                columns = request.form['columns']
            else:
                columns = 1
            files = {'file': file}
            payload = {'model': model}
            r = requests.post(url, data=payload, files=files)
            res = r.json()
            if 'result' in res and len(res['result']) > 1:
                d = {
                    'boxes': res['result'],
                    'xywh': [0, 0, res['size_w'], res['size_h']]
                }
                data = spl.split_data(d, int(columns), int(rows))
            else:
                data = [res['result']]
            return jsonify(data)
        except Exception as e:
            print("BBBBBBBBBBBBBBBBBB", e)
            return jsonify({'mess': 'error'}), 400


def encode_auth_token(user):
    payload = {
        "id": user.id,
        "expires": time.time() + 60 * 60 * 24 * 5
    }

    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def token_required(f):
    @wraps(f)
    def decode_auth_token(*args, **kwargs):
        # TODO: client get authorization token from response header and send authorization header request to server
        auth_header = request.headers['authorization']

        token = auth_header.split(' ')[-1] if auth_header else ''

        try:
            decoded_data = jwt.decode(token, JWT_SECRET, algorithms='HS256') if token else {}

            if not decoded_data and decoded_data['id'] and decoded_data['expires']:
                return jsonify({'status': 401, 'mess': 'Invalid token'}), 401

            user = User.query.filter_by(id=decoded_data['id']).first()

            if not user or user.id != decoded_data['id']:
                return jsonify({'status': 401, 'mess': 'Invalid user'}), 401

            if decoded_data['expires'] < time.time():
                return jsonify({'status': 401, 'mess': 'Token expired'}), 401

        except jwt.ExpiredSignatureError:
            return 'Token expired. Please log in again.'

        except jwt.InvalidTokenError:
            return 'Invalid token. Please log in again.'

        return f(user, *args, **kwargs)

    return decode_auth_token


@app.route("/api/login", methods=['POST'])
def api_login():
    user = User.query.filter_by(username=request.form['username']).first()

    if user and request.form['company_id'] == user.company_id and bcrypt.check_password_hash(user.password, request.form['password']):
        return jsonify({'mess': 'login success', 'token': encode_auth_token(user)})

    else:
        return jsonify({'mess': 'login failed', 'token': None}), 401


@app.route("/api/get_profile")
@token_required
def api_get_profile(user):
    try:
        company = Company.query.filter_by(uuid=user.company_id).first()
        profile_info = {
            'name': company.name,
            'uuid': company.uuid,
            'created_at': company.created_at
        }
        return jsonify({'profile_info': profile_info})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/register", methods=['GET', 'POST'])
def api_register():
    try:
        hashed_password = bcrypt.generate_password_hash(request.form['password']).decode('utf-8')

        new_user = User(name=(request.form['name']), username=request.form['username'], email=request.form['email'],
                    password=hashed_password, company_id=request.form['company_id'], created_ip=request.remote_addr)
        db.session.add(new_user)
        db.session.commit()

        return jsonify({'mess': 'register success'})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/create_company", methods=['POST'])
@token_required
def api_create_company(user):
    try:
        uuid = create_uuid()
        company = Company(name=request.form['name'], uuid=uuid, created_ip=request.remote_addr)
        db.session.add(company)
        db.session.commit()

        return jsonify({'company_added': str(company)}, 201)

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/create_form", methods=['POST'])
@token_required
def api_create_form(user):
    try:
        company_id = request.form['company_id'] if request.form['company_id'] != '' else None
        des = request.form['description'] if request.form['description'] != '' else None
        new_format = Format(name=request.form['name'], url=request.form['url'], api=request.form['api'],
                            company_id=company_id, description=des, created_user=user.id,
                            created_ip=request.remote_addr)

        db.session.add(new_format)
        db.session.commit()

        return jsonify({'new_format': str(new_format)})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/get_history", methods=['GET'])
@token_required
def api_get_history(user):
    try:
        post = Post.query.filter(Post.user_id.in_([user.id])).all()
        results = Result.query.filter(Result.post_id.in_([p.id for p in post])).all()
        res = []
        for data in results:
            r = {
                'id': data.id,
                'name': data.name,
                'raw_path': data.raw_path,
                'output_path': data.output_path,
                'type': data.type,
                'result': json.loads(data.result) if data.result is not None else None,
                'status': data.status,
                'correct_result': data.correct_result,
                'view_status': data.view_status,
                'created_at': data.created_at,
            }
            res.append(r)
        query1 = SubFormat.query.filter_by(company_id=user.company_id, format_id=None).all()

        formats = []
        for data in query1:
            r = {
                'id': data.id,
                'name': data.name
            }
            formats.append(r)

        return jsonify({'data': res, 'format': formats})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/get_detail", methods=['GET'])
@token_required
def api_get_detail(user):
    try:
        post = Post.query.filter(Post.user_id.in_([user.id])).all()
        results = Result.query.filter(Result.post_id.in_([p.id for p in post])).all()
        res = []
        for data in results:
            r = {
                'id': data.id,
                'name': data.name,
                'raw_path': data.raw_path,
                'output_path': data.output_path,
                'type': data.type,
                'result': json.loads(data.result) if data.result is not None else None,
                'status': data.status,
                'correct_result': data.correct_result,
                'view_status': data.view_status,
                'created_at': data.created_at,
            }
            res.append(r)

        return jsonify({'data': res})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/get_result")
@token_required
def api_get_result(user):
    try:
        id = None
        if 'id' in request.args:
            id = request.args['id']
        post = Post.query.filter(Post.user_id.in_([user.id])).all()
        post = ','.join([str(p.id) for p in post])
        results = db.engine.execute('SELECT A.* FROM ('
                                    '(SELECT * FROM result WHERE id <= {} AND post_id in ({}) ORDER BY id DESC LIMIT 5)'
                                    'UNION (SELECT * FROM result WHERE id > {} AND post_id in ({}) ORDER BY id ASC LIMIT 5 ))'
                                    'as A ORDER BY A.id'.format(id, post, id, post))

        res = []
        for data in results:
            r = {
                'id': data.id,
                'name': data.name,
                'raw_path': data.raw_path,
                'output_path': data.output_path,
                'type': data.type,
                'result': json.loads(data.result) if data.result is not None else None,
                'status': data.status,
                'correct_result': data.correct_result,
                'view_status': data.view_status,
                'created_at': data.created_at,
            }
            if id is not None and id == str(data.id):
                form = Format.query.filter_by(name=data.type).first()
                if form is None:
                    form = SubFormat.query.filter_by(company_id=user.company_id, name=data.type).first()
                if form is not None:
                    r['format'] = form.description
            res.append(r)

        return jsonify({'data': res})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/get_review")
@token_required
def api_get_review(user):
    try:
        package_id = None
        if 'id' in request.args:
            package_id = request.args['id']

        files = Result.query.filter_by(package_id=package_id)
        package = Package.query.filter_by(id=package_id).first()
        list_files = []
        cnt_confirmed = 0
        for file in files.all():
            r = {
                'id': file.id,
                'name': file.name,
                'raw_path': file.raw_path,
                'output_path': file.output_path,
                'type': file.type,
                'result': json.loads(file.result) if file.result is not None else None,
                'status': file.status,
                'correct_result': file.correct_result,
                'view_status': file.view_status,
                'created_at': file.created_at,
                'deleted_at': file.deleted_at,
            }
            if r['status'] == 5:
                cnt_confirmed += 1
            if id is not None and id == str(file.id):
                form = Format.query.filter_by(name=file.type).first()
                if form is None:
                    form = SubFormat.query.filter_by(company_id=user.company_id, name=file.type).first()
                if form is not None:
                    r['format'] = form.description
            list_files.append(r)
        rate_confirmed = '{}/{}'.format(cnt_confirmed, int(files.count()))
        return jsonify({'data': list_files, 'rate_confirmed': rate_confirmed, 'pack_name': package.package_name})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


# Confirm:
@app.route('/api/review/get_confirm', methods=['POST'])
@token_required
def api_get_confirm_file(user):
    json_data = request.json
    file_id = json_data['fileId']
    file = Result.query.filter_by(id=file_id).first()
    file.result = json.dumps(json_data['result'])
    file.status = CONFIRMED
    db.session.commit()

    return jsonify({"message": "success"})


@app.route("/api/test")
@token_required
def api_test(user):
    try:
        id = None
        if 'id' in request.args:
            id = request.args['id']
        post = Post.query.filter(Post.user_id.in_([user.id])).all()
        post = ','.join([str(p.id) for p in post])
        results = db.engine.execute('SELECT A.* FROM ('
                                    '(SELECT * FROM result WHERE id <= {} AND post_id in ({}) ORDER BY id DESC LIMIT 5)'
                                    'UNION (SELECT * FROM result WHERE id > {} AND post_id in ({}) '
                                    'ORDER BY id ASC LIMIT 5 )) as A ORDER BY A.id'.format(id, post, id, post))

        res = []
        for data in results:
            r = {
                'id': data.id,
                'name': data.name,
                'raw_path': data.raw_path,
                'output_path': data.output_path,
                'type': data.type,
                'result': data.result,
                'status': data.status,
                'correct_result': data.correct_result,
                'view_status': data.view_status,
                'created_at': data.created_at,
            }
            if id is not None and id == str(data.id):
                form = Format.query.filter_by(name=data.type).first()
                if form is None:
                    form = SubFormat.query.filter_by(company_id=user.company_id, name=data.type).first()
                if form is not None:
                    r['format'] = form.description
            res.append(r)

        return jsonify({'data': res})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/get_templates")
@token_required
def api_get_templates(user):
    try:
        template = SubFormat.query.filter_by(company_id=user.company_id, format_id=None).all()
        res = []
        for data in template:
            r = {
                'id': data.id,
                'name': data.name,
                'description': data.description,
                'company_id': data.company_id,
                'created_at': data.created_at,
            }
            res.append(r)

        return jsonify({'data': res})

    except Exception as e:
        return jsonify({'error': str(e)}, 400)


@app.route("/api/create_template", methods=['GET', 'POST'])
@token_required
def api_create_template(user):
    if request.method == 'POST':
        if 'name' in request.form:
            name = request.form['name']
            template = SubFormat.query.filter(
                and_(SubFormat.company_id.in_([user.company_id, None]), SubFormat.name == name)).all()
            if (len(template)) > 0:
                return jsonify({'mess': 'Template is existed'}), 400
            else:
                obj = SubFormat(name=name, company_id=user.company_id, created_ip=request.remote_addr,
                                created_user=user.id)
                db.session.add(obj)
                db.session.commit()

                return jsonify({'id': obj.id})


@app.route("/api/update_template/<id>")
@token_required
def api_update_template(user, id):
    template = SubFormat.query.filter_by(company_id=user.company_id, id=id).first()
    res = {
        'id': template.id,
        'name': template.name,
        'description': template.description,
        'img_path': template.img_path,
        'company_id': template.company_id,
        'created_at': template.created_at,
    }
    return jsonify({'data': res})


@app.route("/api/delete_result", methods=['GET', 'POST'])
@token_required
def api_delete_result(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            for d in obj:
                db.session.delete(d)
            db.session.commit()

            return jsonify({'mess': 'success'})


@app.route("/api/delete_folder", methods=['GET', 'POST'])
@token_required
def api_delete_folder(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            result = Result.query.filter(Result.package_id.in_(data)).all()
            for file in result:
                db.session.delete(file)
            db.session.commit()
            obj = Package.query.filter(Package.id.in_(data)).all()
            for d in obj:
                db.session.delete(d)
            db.session.commit()

            return jsonify({'mess': 'success'})


@app.route("/api/delete_template", methods=['POST'])
@token_required
def api_delete_template(user):
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            id = id.split(',')
            for index in id:
                obj = SubFormat.query.filter_by(id=index).first()
                db.session.delete(obj)
            db.session.commit()

        return jsonify({'mess': 'success'})


@app.route("/api/duplicate_template", methods=['POST'])
@token_required
def api_duplicate_template(user):
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            id = id.split(',')
            # for index in id:
            obj = SubFormat.query.filter_by(id=id).first()
            name = obj.name + ' (COPY)'
            obj = SubFormat(name=name, description=obj.description, img_path=obj.img_path, format_id=obj.format_id,
                            company_id=obj.company_id, created_ip=obj.created_ip, created_user=obj.created_user)
            db.session.add(obj)
            db.session.commit()

            return jsonify({'id': obj.id})


@app.route("/api/rename_template", methods=['POST'])
@token_required
def api_rename_template(user):
    if request.method == 'POST':
        if 'id' in request.form:
            id = request.form['id']
            if 'name' in request.form:
                name = request.form['name']
                obj = SubFormat.query.filter_by(id=id).first()
                obj.name = name
                db.session.commit()

        return jsonify({'mess': 'success'})


@app.route("/api/export", methods=['POST'])
@token_required
def api_export(user):
    import xlwt
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            book = xlwt.Workbook(encoding="utf-8")
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
            for d in obj:
                if d.result is not None:
                    name = d.name
                    if len(d.name) > 30:
                        name = name[:30]
                    sheet = book.add_sheet(name)
                    sheet.write(0, 0, "ID")
                    sheet.write(0, 1, "Text")
                    sheet.write(0, 2, "Probability")
                    i = 1
                    res = json.loads(d.result)
                    for x in res['raw']['result']:
                        sheet.write(i, 0, x['id'])
                        sheet.write(i, 1, x['text'])
                        sheet.write(i, 2, x['prob'])
                        i += 1

            book.save(os.path.join(UPLOAD_DIR, path))

            return jsonify({'path': '/static/uploaded/' + path})


@app.route("/api/save_export", methods=['POST'])
@token_required
def api_save_export(user):
    import xlwt
    if request.method == 'POST':
        if 'id' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            book = xlwt.Workbook(encoding="utf-8")
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.xls'
            if obj.result is not None:
                name = obj.name
                if len(obj.name) > 30:
                    name = name[:30]
                sheet = book.add_sheet(name)
                sheet.write(0, 0, "ID")
                sheet.write(0, 1, "Text")
                c = 1
                res = json.loads(obj.result)
                for i, x in enumerate(res['raw']['result']):
                    sheet.write(c, 0, i)
                    sheet.write(c, 1, x['text'])
                    c += 1
            book.save(os.path.join(UPLOAD_DIR, path))

            return jsonify({'path': '/static/uploaded/' + path})


@app.route("/api/save", methods=['POST'])
@token_required
def api_save_data(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data']
            obj = Result.query.filter_by(id=request.form['id']).first()
            obj.result = data
            db.session.commit()

            return jsonify({'success': True})


@app.route("/api/exportv2", methods=['POST'])
@token_required
def api_exportv2(user):
    if request.method == 'POST':
        if 'data' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            templates = SubFormat.query.filter(company_id=user.company_id).all()
            temp = [t.name for t in templates]
            if obj.type in temp:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                tmp = None
                for t in templates:
                    if obj.type == t.name:
                        tmp = json.loads(t.description)
                        break
                f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                extracted = json.loads(obj.result)['extracted']

                keys = sorted(tmp['results'], key=itemgetter('position'))
                rows = [[d['key'] for d in keys]]
                m = 0
                for x in extracted:
                    merge = []
                    for i in extracted[x]:
                        merge = merge + i
                    extracted[x] = merge
                    if len(extracted[x]) > m:
                        m = len(extracted[x])
                for i in range(m):
                    r = []
                    for x in keys:
                        try:
                            r.append(extracted[x['key']][i])
                        except:
                            r.append('')
                    rows.append(r)
                for row in rows:
                    f.write(','.join(row))
                    f.write('\n')

                return jsonify({'path': '/static/uploaded/' + path})


@app.route("/api/exportv3", methods=['POST'])
@token_required
def api_exportv3(user):
    if request.method == 'POST':
        if 'id' in request.form:
            obj = Result.query.filter_by(id=request.form['id']).first()
            templates = SubFormat.query.filter_by(company_id=user.company_id).all()
            temp = [t.name for t in templates]
            if obj.type in temp:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                tmp = None
                for t in templates:
                    if obj.type == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                if obj.result is not None:
                    extracted = json.loads(obj.result)['extracted']
                    suggestion = json.loads(obj.result)['suggestion']
                    skeys = {}
                    for s in suggestion:
                        skeys[s['key']] = s['text']

                    if extracted is not None:
                        if tmp is not None:
                            srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                            keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                            # rows = [[d['key'] for d in keys]]
                            if len(keys) > 0:
                                arrayl = srt[keys[-1]['position']]
                            else:
                                arrayl = 0

                            list_keys = [''] * (arrayl + 1)
                            for d in keys:
                                list_keys[srt[d['position']]] = d['key']

                            if len(keys) < len(extracted):
                                for d in extracted:
                                    if d not in list_keys:
                                        list_keys.append(d)
                            print(list_keys)

                            if len(suggestion) > 0:
                                list_keys = list_keys + [s['key'] for s in suggestion]
                            rows = [list_keys]
                            m = 0
                            for x in extracted:
                                merge = []
                                for i in extracted[x]:
                                    merge = merge + i
                                extracted[x] = merge
                                if len(extracted[x]) > m:
                                    m = len(extracted[x])
                            for i in range(m):
                                r = []
                                for x in list_keys:
                                    try:
                                        if x in [s['key'] for s in suggestion]:
                                            r.append(skeys[x].replace(',', '').replace('\t', ''))
                                        else:
                                            r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                    except:
                                        r.append('')
                                rows.append(r)
                        else:
                            keys = []
                            rows = []
                            m = 0
                            for k in extracted:
                                keys.append(k)
                                l = len(extracted[k][0])
                                if l > m:
                                    m = l
                            if len(suggestion) > 0:
                                keys = keys + [s['key'] for s in suggestion]
                            rows.append(keys)
                            for i in range(m):
                                r = []
                                for z in keys:
                                    try:
                                        if z in [s['key'] for s in suggestion]:
                                            r.append(skeys[z].replace(',', '').replace('\t', ''))
                                        else:
                                            r.append(extracted[z][0][i]['text'].replace(',', '').replace('\t', ''))
                                    except Exception as e:
                                        print(e)
                                        r.append('')
                                if i == 1 and len(suggestion) > 0:
                                    r = r + [s['text'].replace(',', '').replace('\t', '') for s in suggestion]
                                rows.append(r)
                        f.write("\uFEFF")
                        for row in rows:
                            f.write(','.join(row))
                            f.write('\n')
                        f.close()
                        return jsonify({'path': '/static/uploaded/' + path})
            else:
                if obj.result is not None:
                    extracted = json.loads(obj.result)['extracted']
                    print(extracted)
                    path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.csv'
                    f = open(os.path.join(UPLOAD_DIR, path), 'w', encoding="utf-8")
                    if extracted is not None:
                        f.write("\uFEFF")
                        f.write('項目,認識結果\n')
                        for data in extracted:
                            text = [x['text'].replace(',', '') for x in extracted[data][0]]
                            f.write('{},{}\n'.format(data, ','.join(text)))
                        f.close()
                        return jsonify({'path': '/static/uploaded/' + path})
                    else:
                        extracted = json.loads(obj.result)['raw']
                        if extracted is not None:
                            extracted = extracted['result']
                            f.write("\uFEFF")
                            f.write('項目,認識結果\n')
                            for data in extracted:
                                # text = [x['text'].replace(',', '') for x in extracted[data][0]]
                                f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                            f.close()
                        return jsonify({'path': '/static/uploaded/' + path})

    return jsonify({'success': False}), 400


@app.route("/api/export_multiple", methods=['POST'])
@token_required
def api_export_multiple(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.id.in_(data)).all()
            templates = SubFormat.query.filter_by(company_id=user.company_id).all()
            temp = {}
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f")
            if not os.path.exists(os.path.join(UPLOAD_DIR, path)):
                os.mkdir(os.path.join(UPLOAD_DIR, path))

            for d in obj:
                if d.type not in temp:
                    temp[d.type] = []
                temp[d.type].append(d)

            for ty in temp:
                tmp = None
                for t in templates:
                    if ty == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                if tmp is not None:
                    srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                    keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                    if len(keys) > 0:
                        arrayl = srt[keys[-1]['position']]
                    else:
                        arrayl = 0

                    list_keys = [''] * (arrayl + 1)
                    for d in keys:
                        list_keys[srt[d['position']]] = d['key']
                    rows = [list_keys]

                    for obj in temp[ty]:
                        extracted = json.loads(obj.result)['extracted']
                        m = 0
                        for x in extracted:
                            merge = []
                            for i in extracted[x]:
                                merge = merge + i
                            extracted[x] = merge
                            if len(extracted[x]) > m:
                                m = len(extracted[x])
                        for i in range(m):
                            r = []
                            for x in list_keys:
                                try:
                                    r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                except:
                                    r.append('')
                            rows.append(r)
                    f = open(os.path.join(UPLOAD_DIR, path, '{}.csv'.format(ty)), 'w', encoding="utf-8")

                    f.write("\uFEFF")
                    for row in rows:
                        f.write(','.join(row))
                        f.write('\n')
                    f.close()
                else:
                    for obj in temp[ty]:
                        fname = os.path.join(UPLOAD_DIR, path, '{}_{}.csv'.format(obj.name, obj.id))
                        f = open(fname, 'w', encoding="utf-8")
                        rows = []
                        if obj.result is not None:
                            extracted = json.loads(obj.result)['extracted']
                            if extracted is not None:
                                keys = []
                                m = 0
                                for k in extracted:
                                    keys.append(k)
                                    l = len(extracted[k][0])
                                    if l > m:
                                        m = l
                                rows.append(keys)
                                for i in range(m):
                                    r = []
                                    for z in keys:
                                        try:
                                            r.append(extracted[z][0][i]['text'].replace(',', ''))
                                        except Exception as e:
                                            print(e)
                                            r.append('')
                                    rows.append(r)
                                f.write("\uFEFF")
                                for row in rows:
                                    f.write(','.join(row))
                                    f.write('\n')
                                f.close()
                            else:
                                extracted = json.loads(obj.result)['raw']
                                f.write("\uFEFF")
                                f.write('項目,認識結果\n')
                                if extracted is not None:
                                    extracted = extracted['result']
                                    for data in extracted:
                                        f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                                    f.close()

            import shutil

            shutil.make_archive(os.path.join(UPLOAD_DIR, path), 'zip', os.path.join(UPLOAD_DIR, path))

            return jsonify({'path': '/static/uploaded/' + '{}.zip'.format(path)})


@app.route("/api/export_multiple_package", methods=['POST'])
@token_required
def api_export_package(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = request.form['data'].split(',')
            obj = Result.query.filter(Result.package_id.in_(data)).all()
            templates = SubFormat.query.filter_by(company_id=user.company_id).all()
            temp = {}
            path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f")
            if not os.path.exists(os.path.join(UPLOAD_DIR, path)):
                os.mkdir(os.path.join(UPLOAD_DIR, path))

            for d in obj:
                if d.type not in temp:
                    temp[d.type] = []
                temp[d.type].append(d)

            for ty in temp:
                tmp = None
                for t in templates:
                    if ty == t.name and t.description is not None:
                        tmp = json.loads(t.description)
                        break
                if tmp is not None:
                    srt = {b: i for i, b in enumerate(LIST_COLUMN)}
                    keys = sorted(tmp['results'], key=lambda x: srt[x['position']])
                    # rows = [[d['key'] for d in keys]]
                    if len(keys) > 0:
                        arrayl = srt[keys[-1]['position']]
                    else:
                        arrayl = 0

                    list_keys = [''] * (arrayl + 1)
                    for d in keys:
                        list_keys[srt[d['position']]] = d['key']
                    rows = [list_keys]

                    for obj in temp[ty]:
                        extracted = json.loads(obj.result)['extracted']
                        m = 0
                        # for key in extracted:
                        #     for i in range(len(extracted[key])):
                        #         extracted[key][i] = sorted(extracted[key][i], key=itemgetter('y'))
                        for x in extracted:
                            merge = []
                            for i in extracted[x]:
                                merge = merge + i
                            extracted[x] = merge
                            if len(extracted[x]) > m:
                                m = len(extracted[x])
                        for i in range(m):
                            r = []
                            for x in list_keys:
                                try:
                                    r.append(extracted[x][i]['text'].replace(',', '').replace('\t', ''))
                                except:
                                    r.append('')
                            rows.append(r)
                    f = open(os.path.join(UPLOAD_DIR, path, '{}.csv'.format(ty)), 'w', encoding="utf-8")

                    f.write("\uFEFF")
                    for row in rows:
                        f.write(','.join(row))
                        f.write('\n')
                    f.close()
                else:
                    for obj in temp[ty]:
                        fname = os.path.join(UPLOAD_DIR, path, '{}_{}.csv'.format(obj.name, obj.id))
                        f = open(fname, 'w', encoding="utf-8")
                        rows = []
                        if obj.result is not None:
                            extracted = json.loads(obj.result)['extracted']
                            if extracted is not None:
                                keys = []
                                m = 0
                                for k in extracted:
                                    keys.append(k)
                                    l = len(extracted[k][0])
                                    if l > m:
                                        m = l
                                rows.append(keys)
                                for i in range(m):
                                    r = []
                                    for z in keys:
                                        try:
                                            r.append(extracted[z][0][i]['text'].replace(',', ''))
                                        except Exception as e:
                                            print(e)
                                            r.append('')
                                    rows.append(r)
                                f.write("\uFEFF")
                                for row in rows:
                                    f.write(','.join(row))
                                    f.write('\n')
                                f.close()
                            else:
                                extracted = json.loads(obj.result)['raw']
                                f.write("\uFEFF")
                                f.write('項目,認識結果\n')
                                if extracted is not None:
                                    extracted = extracted['result']
                                    for data in extracted:
                                        # text = [x['text'].replace(',', '') for x in extracted[data][0]]
                                        f.write('{},{}\n'.format(data['id'], data['text'].replace(',', '')))
                                    f.close()

            import shutil

            shutil.make_archive(os.path.join(UPLOAD_DIR, path), 'zip', os.path.join(UPLOAD_DIR, path))

            return jsonify({'path': '/static/uploaded/' + '{}.zip'.format(path)})


@app.route("/api/save_template", methods=['POST'])
@token_required
def api_save_template(user):
    if request.method == 'POST':
        if 'data' in request.form:
            data = json.loads(request.form['data'])
            obj = SubFormat.query.filter_by(company_id=user.company_id, id=request.form['id']).first()
            if 'file' in request.files:
                file = request.files['file']
                if file.filename.lower().endswith('.pdf'):
                    pages = convert_from_bytes(file.read())
                    img = np.array(pages[0])
                    img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
                else:
                    img = cv2.imdecode(np.fromstring(file.read(), np.uint8), cv2.IMREAD_COLOR)

                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.jpg'
                # img = rotate(img)
                cv2.imwrite(os.path.join(UPLOAD_DIR, path), img)
                # img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                img_h = img.shape[0]
                img_w = img.shape[1]
            else:
                path = obj.img_path
                temp = json.loads(obj.description)
                img_h = temp['img_h']
                img_w = temp['img_w']
            d = {
                'results': data,
                'img_h': img_h,
                'img_w': img_w
            }
            obj.description = json.dumps(d)
            obj.img_path = path
            db.session.commit()
            return jsonify({'mess': 'success'})

        return jsonify({'mess': 'error'}), 400


@app.route("/api/update_pass", methods=['POST'])
@token_required
def api_update_pass(user):
    if request.method == 'POST':
        if 'pass' in request.form:
            data = request.form['pass']
            user.password = bcrypt.generate_password_hash(data).decode('utf-8')
            db.session.commit()

    return jsonify({'mess': 'update success'})


@app.route("/api/update_infor", methods=['POST'])
@token_required
def api_update_infor(user):
    if request.method == 'POST':
        if 'name' in request.form:
            data = request.form['name']
            user.name = data
            db.session.commit()

    return jsonify({'mess': 'update success'})


@app.route("/api/update_avatar", methods=['POST'])
@token_required
def api_update_avatar(user):
    if request.method == 'POST':
        if 'avatar' in request.files:
            file = request.files['avatar']
            filename = secure_filename(file.filename)
            file.save(os.path.join(IMG_DIR, filename))
            user.image_file = filename
            db.session.commit()

    return jsonify({'mess': 'update success'})


@app.route("/api/logout")
@login_required
def api_logout(user):
    return jsonify({'mess': 'logged out', 'token': None})


@app.route("/api/account", methods=['GET', 'POST'])
@token_required
def api_account(user):
    form = UpdateAccountForm()
    if form.validate_on_submit():
        if form.picture.data:
            picture_file = save_picture(form.picture.data)
            user.image_file = picture_file
        user.username = form.username.data
        user.email = form.email.data
        db.session.commit()

        return jsonify({'mess': 'Your account has been updated!'})

    elif request.method == 'GET':
        form.username.data = user.username
        form.email.data = user.email
    image_file = url_for('static', filename='profile_pics/' + user.image_file)

    return jsonify({'image_file': image_file, 'form': form})


@app.route("/api/update_view_status", methods=['POST'])
@token_required
def api_update_view_status(user):
    if request.method == 'POST':
        if 'id' in request.form:
            index = request.form['id']
            obj = Result.query.filter_by(id=index).first()
            obj.view_status = True
            db.session.commit()
        return jsonify({'mess': 'success'})


@app.route("/api/upload", methods=['GET', 'POST'])
@app.route("/api/report", endpoint='api_report', methods=['GET', 'POST'])
@app.route("/api/license_plate", endpoint='api_license_plate', methods=['GET', 'POST'])
@app.route("/api/driver_license", endpoint='api_driver_license', methods=['GET', 'POST'])
@app.route("/api/vehicle_verification", endpoint='api_vehicle_verification', methods=['GET', 'POST'])
@token_required
def api_upload(user):
    query = Format.query.filter().all()
    query1 = SubFormat.query.filter_by(company_id=user.company_id).all()
    data = []

    if request.method == 'POST':
        if int(user.limited) <= 0:
            return jsonify({'mess': 'limited'}), 400
        post = Post(user_id=user.id, created_ip=request.remote_addr)
        db.session.add(post)
        # Check duplicate package name
        package_name = Package.query.filter_by(user_id=user.id) \
            .filter_by(package_name=request.form['packageName']).first()

        if package_name:
            return jsonify({'mess': 'duplicate package name'}), 400

        package = Package(user_id=user.id, package_type='temporary', package_name=request.form['packageName'],
                          created_ip=request.remote_addr)

        img_data = request.files.getlist('img_data[]')
        for i, file in enumerate(img_data):
            img_type = request.form['type_img_' + str(i)]
            img_name = request.form['name_' + str(i)]
            type_name = 'unselected'
            if img_type != '':
                for d in query:
                    if int(img_type) == int(d.id):
                        type_name = d.name

                        break
                for d in query1:
                    if int(img_type) == int(d.id):
                        type_name = d.name
                        break
            # Add package object to db
            # type_name = type_name if request.endpoint == 'upload' else None
            if not i:
                package.package_type = type_name
                db.session.add(package)
                db.session.commit()

            try:
                path = datetime.datetime.now().strftime("%Y%m%d_%H%M%S%f") + '.' + file.filename.rsplit('.', 1)[
                    1].lower()
                file.save(os.path.join(UPLOAD_DIR, path))
                if path.lower().endswith('.pdf'):
                    pages = convert_from_path(os.path.join(UPLOAD_DIR, path))
                    for idx, page in enumerate(pages):
                        img_path = path.rsplit('.', 1)[0] + '_' + str(idx) + '.jpg'
                        img = np.array(page)
                        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
                        # img = rotate(img)
                        cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                        name = img_name + '_' + str(idx)
                        if user.limited > 0:
                            user.limited -= 1
                            # Save image:
                            result = Result(name=name, raw_path=img_path, type=type_name, status=WAITING,
                                            post_id=post.id, created_ip=request.remote_addr, package_id=package.id)
                            db.session.add(result)
                            db.session.flush()
                            d = {
                                'id': result.id,
                                'name': os.path.join(UPLOAD_DIR, img_path),
                                'type': type_name
                            }
                            data.append(d)
                            db.session.commit()
                elif path.lower().endswith('.tiff') or path.lower().endswith('.tif'):
                    img_path = path.rsplit('.', 1)[0] + '.jpg'
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, img_path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=img_path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.flush()
                        d = {
                            'id': result.id,
                            'name': os.path.join(UPLOAD_DIR, img_path),
                            'type': type_name
                        }
                        data.append(d)
                        db.session.commit()
                else:
                    img = cv2.imread(os.path.join(UPLOAD_DIR, path))
                    # img = rotate(img)
                    cv2.imwrite(os.path.join(UPLOAD_DIR, path), img)
                    if user.limited > 0:
                        user.limited -= 1
                        result = Result(name=img_name, raw_path=path, type=type_name, status=WAITING,
                                        post_id=post.id,
                                        created_ip=request.remote_addr, package_id=package.id)
                        db.session.add(result)
                        db.session.flush()
                        d = {
                            'id': result.id,
                            'name': os.path.join(UPLOAD_DIR, path),
                            'type': type_name
                        }
                        data.append(d)
                        db.session.commit()

                socketio.start_background_task(processing_thread, data, user.company_id)

            except Exception as e:
                print(e)
        return jsonify({'mess': 'success', 'pack_id': package.id})
    formats = []
    for data in query:
        if data.company_id is None or data.company_id == user.company_id:
            subform = SubFormat.query.filter_by(company_id=user.company_id, format_id=data.id).all()
            subforms = []
            if len(subform) > 0:
                for x in subform:
                    sub = {
                        'id': x.id,
                        'name': x.name
                    }
                    subforms.append(sub)
            d = {
                'id': data.id,
                'name': data.name,
                'url': data.url,
                'api': data.api,
                'description': data.description,
                'sub_form': subforms,
                'company_id': data.company_id,
                'created_user': data.created_user,
            }
            formats.append(d)
    m = None
    if request.endpoint == 'report':
        m = REPORT
    if request.endpoint == 'license_plate':
        m = LICENSE_PLATE
    if request.endpoint == 'driver_license':
        m = DRIVER_LICENSE
    if request.endpoint == 'vehicle_verification':
        m = VEHICLE_VERIFICATION
    form = None
    for x in formats:
        if x['name'] == m:
            form = x
            break

    return jsonify({'data': form})


# Check folder name:
@app.route('/api/checkPackage', methods=['POST'])
@token_required
def api_check_package(user):
    package_name = request.form['packageName']
    obj = Package.query.filter_by(user_id=user.id).filter_by(package_name=package_name).first()
    mess = 'success' if not obj else 'fail'
    return jsonify({"message": mess})


# Get admin list packages:
@app.route('/api/listPackage', methods=['GET'])
@token_required
def api_get_list_packages(user):
    packages = Package.query.order_by(asc(Package.id)).all()
    list_pacs = []
    for package in packages:
        user_name = User.query.filter_by(id=package.user_id).first().username
        files = Result.query.filter_by(package_id=package.id)
        cnt_confirmed = 0
        for file in files.all():
            if file.status == 5:
                cnt_confirmed += 1
        rate_confirmed = '{}/{}'.format(cnt_confirmed, int(files.count()))
        r = {
            'id': package.id,
            'name': package.package_name,
            'raw_path': "null",
            'output_path': None,
            'type': package.package_type if package.package_type else 'null',
            'result': None,
            'status': "None",
            'rate_confirmed': rate_confirmed,
            'correct_result': None,
            'view_status': None,
            'created_at': package.created_at,
            'created_ip': package.created_ip,
            'deleted_at': package.deleted_at,
            'user_name': user_name,
        }
        list_pacs.append(r)

    query1 = SubFormat.query.filter_by(company_id=user.company_id, format_id=None).all()
    formats = []
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)

    return jsonify({'data': list_pacs, 'format': formats})


# Get list packages with user id:
@app.route('/api/userListPackage', methods=['GET'])
@token_required
def api_get_user_list_packages(user):
    packages = Package.query.filter_by(user_id=user.id).all()

    if len(packages) == 0:
        return jsonify({'mess': 'package not found'}), 400

    list_pacs = []
    for package in packages:
        files = Result.query.filter_by(package_id=package.id)
        cnt_confirmed = 0
        for file in files.all():
            if file.status == 5:
                cnt_confirmed += 1
        rate_confirmed = '{}/{}'.format(cnt_confirmed, int(files.count()))
        r = {
            'id': package.id,
            'name': package.package_name,
            'raw_path': "null",
            'output_path': None,
            'type': package.package_type if package.package_type else 'null',
            'result': None,
            'status': "None",
            'rate_confirmed': rate_confirmed,
            'correct_result': None,
            'view_status': None,
            'created_at': package.created_at,
            'created_ip': package.created_ip,
            'deleted_at': package.deleted_at,
            'user_name': user.username,
        }
        list_pacs.append(r)

    query1 = SubFormat.query.filter_by(company_id=user.company_id, format_id=None).all()
    formats = []
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)

    return jsonify({'data': list_pacs, 'format': formats})


# Get list files:
@app.route('/api/listPackage/<packageId>', methods=['GET'])
@token_required
def api_get_list_files(user, packageId):
    package = Package.query.filter_by(id=packageId).first()

    files = Result.query.filter_by(package_id=package.id).all()
    list_files = []
    for file in files:
        list_files.append({
            'id': file.id,
            'name': file.name,
            'raw_path': file.raw_path,
            'output_path': file.output_path,
            'type': file.type,
            'result': json.loads(file.result) if file.result is not None else None,
            'status': file.status,
            'correct_result': file.correct_result,
            'post_id': file.post_id,
            'view_status': file.view_status,
            'created_at': file.created_at,
            'created_ip': file.created_ip,
            'deleted_at': file.deleted_at,
        })

    query1 = SubFormat.query.filter_by(company_id=user.company_id, format_id=None).all()
    formats = []
    for data in query1:
        r = {
            'id': data.id,
            'name': data.name
        }
        formats.append(r)

    return jsonify({'data': list_files, 'format': formats, 'pack_id': package.id})


@app.route("/api/get_text", methods=['GET', 'POST'])
@token_required
def api_get_text(user):
    url = 'http://demo2.aimenext.com:8080/get_text'
    if 'file' in request.files:
        try:
            file = request.files['file']
            if 'model' in request.form:
                model = request.form['model']
            else:
                model = None
            if 'rows' in request.form:
                rows = request.form['rows']
            else:
                rows = 1
            if 'columns' in request.form:
                columns = request.form['columns']
            else:
                columns = 1
            files = {'file': file}
            payload = {'model': model}
            r = requests.post(url, data=payload, files=files)
            res = r.json()
            if 'result' in res and len(res['result']) > 1:
                d = {
                    'boxes': res['result'],
                    'xywh': [0, 0, res['size_w'], res['size_h']]
                }
                data = spl.split_data(d, int(columns), int(rows))
            else:
                data = [res['result']]

            return jsonify({'data': data})

        except Exception as e:
            return jsonify({'mess': e}), 400
