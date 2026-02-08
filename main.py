from flask import Flask, jsonify
from dotenv import load_dotenv

load_dotenv()

from api.auth import auth_bp
from api.users import users_bp
from api.crews import crews_bp
from api.missions import missions_bp
from api.discover import discover_bp

app = Flask(__name__)

app.register_blueprint(auth_bp)
app.register_blueprint(users_bp)
app.register_blueprint(crews_bp)
app.register_blueprint(missions_bp)
app.register_blueprint(discover_bp)


@app.route('/')
def home():
    return jsonify({"status": "orbit works omg thank you"})


@app.route('/api/health')
def health():
    return jsonify({"status": "healthy"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
