from flask_socketio import SocketIO
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_login import LoginManager
import os
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', '5791628bb0b13ce0c676dfde280ba24')
# app.config['SQLALCHEMY_DATABASE_URI'] = "mysql+pymysql://root:12345678@localhost/aimeocrdev"
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://{}:{}@{}/{}'.format(
    os.getenv('DB_USER', 'root'),
    os.getenv('DB_PASSWORD', '12345678'),
    os.getenv('DB_HOST', '127.0.0.1'),
    os.getenv('DB_NAME', 'aimeocr')
)

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_POOL_SIZE'] = 20
app.config['SQLALCHEMY_POOL_TIMEOUT'] = 300
db = SQLAlchemy(app)
db.init_app(app)

socketio = SocketIO(app, async_mode="threading", logger=True, engineio_logger=True, pingInterval=5000, cors_allowed_origins="*")

# with app.app_context():
#     from main import routes
#     db.create_all()

bcrypt = Bcrypt(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'
login_manager.login_message_category = 'info'

# with app.app_context():
#     from main import routes
#     db.create_all()
from main import routes	
