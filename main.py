import os

from flask import Flask, jsonify

from OrbitServer.utils.rate_limit import limiter
from OrbitServer.api.auth import auth_bp
from OrbitServer.api.users import users_bp
from OrbitServer.api.events import events_bp
from OrbitServer.api.pods import pods_bp
from OrbitServer.api.chat import chat_bp
from OrbitServer.api.missions import missions_bp

app = Flask(__name__)

limiter.init_app(app)

app.register_blueprint(auth_bp)
app.register_blueprint(users_bp)
app.register_blueprint(events_bp)
app.register_blueprint(pods_bp)
app.register_blueprint(chat_bp)
app.register_blueprint(missions_bp)


@app.route('/')
def home():
    return jsonify({"status": "orbit works omg thank you"})


@app.route('/api/health')
def health():
    return jsonify({"status": "healthy"})


@app.route('/_ah/warmup')
def warmup():
    """GAE warmup handler — pre-establishes the Datastore gRPC connection
    so the first real user request doesn't pay cold-start latency."""
    from OrbitServer.models.models import client
    try:
        # Lightweight keys-only query to force gRPC channel init
        q = client.query(kind='Mission')
        q.keys_only()
        list(q.fetch(limit=1))
    except Exception:
        pass
    return jsonify({"status": "warm"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=os.environ.get('FLASK_DEBUG', '0') == '1')
