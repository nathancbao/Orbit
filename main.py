import os

from flask import Flask, jsonify

from OrbitServer.utils.rate_limit import limiter
from OrbitServer.api.auth import auth_bp
from OrbitServer.api.users import users_bp
from OrbitServer.api.missions import missions_bp
from OrbitServer.api.pods import pods_bp
from OrbitServer.api.chat import chat_bp
from OrbitServer.api.signals import signals_bp
from OrbitServer.api.notifications import notifications_bp
from OrbitServer.api.friends import friends_bp

app = Flask(__name__)

limiter.init_app(app)

app.register_blueprint(auth_bp)
app.register_blueprint(users_bp)
app.register_blueprint(missions_bp)
app.register_blueprint(pods_bp)
app.register_blueprint(chat_bp)
app.register_blueprint(signals_bp)
app.register_blueprint(notifications_bp)
app.register_blueprint(friends_bp)


@app.route('/')
def home():
    return jsonify({"status": "orbit works omg thank you"})


@app.route('/api/health')
def health():
    return jsonify({"status": "healthy"})


@app.route('/_ah/warmup')
def warmup():
    """GAE warmup handler -- pre-establishes the Datastore gRPC connection
    and pre-loads ML models so user requests don't pay cold-start latency."""
    import threading
    from OrbitServer.models.models import client

    try:
        # Lightweight keys-only query to force gRPC channel init
        q = client.query(kind='Signal')
        q.keys_only()
        list(q.fetch(limit=1))
    except Exception:
        pass

    # Pre-load fastembed model in a background thread (takes ~5-10s)
    def _warmup_fastembed():
        try:
            from OrbitServer.services.embedding_service import _get_model
            _get_model()
        except Exception:
            pass

    # Pre-train LightFM model in a background thread
    def _warmup_lightfm():
        try:
            from OrbitServer.services.lightfm_service import warmup as lfm_warmup
            lfm_warmup()
        except Exception:
            pass

    threading.Thread(target=_warmup_fastembed, daemon=True).start()
    threading.Thread(target=_warmup_lightfm, daemon=True).start()

    return jsonify({"status": "warm"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=os.environ.get('FLASK_DEBUG', '0') == '1')
