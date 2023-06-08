from flask_wtf import FlaskForm
from flask_wtf.file import FileField, FileAllowed
from flask_login import current_user
from wtforms import StringField, PasswordField, SubmitField, BooleanField, TextField
from wtforms.validators import DataRequired, Length, Email, EqualTo, ValidationError
from main.models import User


class RegistrationForm(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(min=2, max=20)])
    username = StringField('Username', validators=[DataRequired(), Length(min=2, max=20)])
    email = StringField('Email', validators=[DataRequired(), Email()])
    company_id = StringField('Company', validators=[DataRequired(), Length(min=2, max=20)])
    password = PasswordField('Password', validators=[DataRequired()])
    confirm_password = PasswordField('Confirm Password', validators=[DataRequired(), EqualTo('password')])
    submit = SubmitField('Sign Up')

    def validate_username(self, username):
        user = User.query.filter_by(username=username.data).first()
        if user:
            raise ValidationError('That username is taken. Please choose a different one.')

    def validate_email(self, email):
        user = User.query.filter_by(email=email.data).first()
        if user:
            raise ValidationError('That email is taken. Please choose a different one.')


class CreateCompany(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(min=2, max=20)])
    submit = SubmitField('Create')


class CreateFormat(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(min=2, max=20)])
    url = StringField('URL', validators=[DataRequired(), Length(min=20, max=100)])
    api = StringField('API', validators=[DataRequired(), Length(min=1, max=100)])
    description = TextField('Description')
    company_id = StringField('Company ID')
    submit = SubmitField('Create')


class LoginForm(FlaskForm):
    username = StringField('ユーザーID', validators=[DataRequired(), Length(min=2, max=20)])
    password = PasswordField('パスワード', validators=[DataRequired()])
    company_id = StringField('会社ID', validators=[DataRequired(), Length(min=2, max=20)])
    remember = BooleanField('ログインしたままにする')
    submit = SubmitField('ログイン')


class UpdateAccountForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired(), Length(min=2, max=20)])
    email = StringField('Email', validators=[DataRequired(), Email()])
    picture = FileField('Update Profile Picture', validators=[FileAllowed(['jpg', 'png'])])
    submit = SubmitField('Update')

    def validate_username(self, username):
        if username.data != current_user.username:
            user = User.query.filter_by(username=username.data).first()
            if user:
                raise ValidationError('That username is taken. Please choose a different one.')

    def validate_email(self, email):
        if email.data != current_user.email:
            user = User.query.filter_by(email=email.data).first()
            if user:
                raise ValidationError('That email is taken. Please choose a different one.')
