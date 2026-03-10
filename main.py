import os

from flask import Flask, jsonify, render_template_string

from OrbitServer.utils.rate_limit import limiter
from OrbitServer.api.auth import auth_bp
from OrbitServer.api.users import users_bp
from OrbitServer.api.missions import missions_bp
from OrbitServer.api.pods import pods_bp
from OrbitServer.api.chat import chat_bp
from OrbitServer.api.signals import signals_bp
from OrbitServer.api.notifications import notifications_bp
from OrbitServer.api.friends import friends_bp
from OrbitServer.api.dm import dm_bp
from OrbitServer.models.models import get_user

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
app.register_blueprint(dm_bp)


@app.route('/')
def home():
    return jsonify({"status": "orbit works omg thank you"})


# ── Deep Link Route — GET /friend/<user_id> ─────────────────────────────────
# Public page shown when someone opens a shared friend link in a browser.
# Attempts to open the Orbit app via universal link; shows fallback otherwise.

FRIEND_PAGE_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ name }} on Orbit</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            background: white;
            border-radius: 24px;
            padding: 40px 32px;
            max-width: 380px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
        }
        .avatar {
            width: 96px;
            height: 96px;
            border-radius: 50%;
            object-fit: cover;
            margin-bottom: 16px;
        }
        .avatar-placeholder {
            width: 96px;
            height: 96px;
            border-radius: 50%;
            background: linear-gradient(135deg, #667eea, #764ba2);
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 16px;
            font-size: 36px;
            font-weight: bold;
            color: white;
        }
        h1 { font-size: 22px; margin-bottom: 6px; }
        .subtitle {
            color: #666;
            font-size: 15px;
            margin-bottom: 28px;
        }
        .open-btn {
            display: block;
            width: 100%;
            padding: 16px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 14px;
            font-size: 17px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            margin-bottom: 16px;
        }
        .open-btn:hover { opacity: 0.92; }
        .fallback {
            color: #999;
            font-size: 13px;
        }
        .fallback a { color: #667eea; text-decoration: none; }
    </style>
</head>
<body>
    <div class="card">
        {% if photo %}
            <img class="avatar" src="{{ photo }}" alt="{{ name }}">
        {% else %}
            <div class="avatar-placeholder">{{ initial }}</div>
        {% endif %}
        <h1>{{ name }}</h1>
        <p class="subtitle">invited you to connect on Orbit</p>
        <a class="open-btn" href="https://orbit-app-486204.wl.r.appspot.com/friend/{{ user_id }}">
            Open in Orbit
        </a>
        <p class="fallback">
            Don't have Orbit? <a href="#">Download it here</a> (coming soon)
        </p>
    </div>
    <script>
        // Try to open the app immediately via universal link — the <a> tag
        // serves as fallback if the app is not installed.
    </script>
</body>
</html>'''

FRIEND_NOT_FOUND_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Not Found — Orbit</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            background: white;
            border-radius: 24px;
            padding: 40px 32px;
            max-width: 380px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
        }
        h1 { font-size: 22px; margin-bottom: 10px; }
        p { color: #666; font-size: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>User not found</h1>
        <p>This invite link may be invalid or expired.</p>
    </div>
</body>
</html>'''


@app.route('/friend/<int:user_id>')
def friend_deep_link(user_id):
    """Public deep-link page for friend invitations."""
    user = get_user(user_id)
    if not user:
        return render_template_string(FRIEND_NOT_FOUND_TEMPLATE), 404

    name = user.get('name', 'Someone')
    photo = user.get('photo')
    initial = name[0].upper() if name else '?'

    return render_template_string(
        FRIEND_PAGE_TEMPLATE,
        name=name,
        photo=photo,
        initial=initial,
        user_id=user_id,
    )


@app.route('/api/health')
def health():
    return jsonify({"status": "healthy"})


@app.route('/.well-known/apple-app-site-association')
def apple_app_site_association():
    """Serve the AASA file so iOS recognises universal links for this domain."""
    aasa = {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": "25YX97TQQ4.com.orbitecs191.orbit",
                    "paths": ["/friend/*"]
                }
            ]
        }
    }
    response = jsonify(aasa)
    response.headers['Content-Type'] = 'application/json'
    return response


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
