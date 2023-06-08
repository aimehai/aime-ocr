from datetime import datetime
from main import db, login_manager
from flask_login import UserMixin


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


class Company(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    name = db.Column(db.String(50), unique=True, nullable=False)
    uuid = db.Column(db.String(20), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.String(60), nullable=True)

    def __repr__(self):
        return f"User('{self.name}', '{self.uuid}', '{self.created_at}')"


class User(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    username = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    image_file = db.Column(db.String(60), nullable=True, default='default.jpg')
    password = db.Column(db.String(60), nullable=False)
    company_id = db.Column(db.String(20), db.ForeignKey('company.uuid'), nullable=False)
    limited = db.Column(db.Integer, default=100)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)

    def __repr__(self):
        return f"User('{self.id}', '{self.username}', '{self.email}', '{self.image_file}')"


class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.String(60), nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

    def __repr__(self):
        return f"Post('{self.id}', '{self.created_at}')"


class Result(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    raw_path = db.Column(db.String(100), nullable=True)
    output_path = db.Column(db.String(100), nullable=True)
    type = db.Column(db.String(100), nullable=True)
    result = db.Column(db.Text, nullable=True)
    status = db.Column(db.Integer, nullable=False, default=0)
    correct_result = db.Column(db.Text, nullable=True)
    view_status = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id'), nullable=False)
    package_id = db.Column(db.Integer, db.ForeignKey('package.id'), nullable=False)

    def __repr__(self):
        return f"Result('{self.id}', '{self.raw_path}', '{self.output_path}', '{self.result}', '{self.type}', '{self.correct_result}', '{self.view_status}', '{self.created_at}')"


class Package(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    package_name = db.Column(db.String(100), nullable=False)
    package_type = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)

    def __repr__(self):
        return f"Package('{self.id}', '{self.user_id}', '{self.package_name}', '{self.created_at}')"


class Format(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    url = db.Column(db.String(200), nullable=False)
    api = db.Column(db.String(200), nullable=False)
    output = db.Column(db.String(200), nullable=True)
    description = db.Column(db.String(1000), nullable=True)
    company_id = db.Column(db.String(20), db.ForeignKey('company.uuid'), nullable=True)
    created_user = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)
    sub_format = db.relationship('SubFormat', backref='format', lazy=True)

    def __repr__(self):
        return f"Result('{self.id}', '{self.name}', '{self.url}', '{self.api}', '{self.description}', '{self.company_id}', '{self.created_user}', '{self.sub_format}')"


class SubFormat(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    img_path = db.Column(db.String(500), nullable=True)
    company_id = db.Column(db.String(20), db.ForeignKey('company.uuid'), nullable=False)
    format_id = db.Column(db.Integer, db.ForeignKey('format.id'), nullable=True)
    created_user = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)

    def __repr__(self):
        return f"SubFormat('{self.id}', '{self.name}', '{self.description}', '{self.company_id}', '{self.created_user}')"


class Division(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    company_id = db.Column(db.String(20), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.String(60), nullable=True)

    def __repr__(self):
        return f"User('{self.name}', '{self.uuid}', '{self.created_at}')"


class SubCompany(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    company_id = db.Column(db.String(20), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.String(60), nullable=True)

    def __repr__(self):
        return f"User('{self.name}', '{self.uuid}', '{self.created_at}')"


class Rule(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=True)
    template = db.Column(db.Text, nullable=True)
    company_id = db.Column(db.String(20), db.ForeignKey('company.uuid'), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_ip = db.Column(db.String(20), nullable=False)
    deleted_at = db.Column(db.String(60), nullable=True)

    def __repr__(self):
        return f"Rule('{self.name}', '{self.id}', '{self.created_at}')"
