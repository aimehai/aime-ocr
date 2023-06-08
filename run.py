from main import app, socketio

if __name__ == '__main__':
    socketio.run(app, host='127.0.0.1', port=8080, debug=False)
    # app.run(host='0.0.0.0', port=5555, debug=True)
