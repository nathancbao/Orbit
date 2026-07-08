import os
import datetime
import logging
import uuid
from functools import wraps

import jwt
from flask import request, g

from OrbitServer.utils.responses import error

logger = logging.getLogger(__name__)

_DEV_SECRET_FALLBACK = 'dev-secret-change-me'


def _load_jwt_secret():
    """Resolve the JWT signing secret.

    In production (running on App Engine, where GAE_ENV is set) a real secret is
    mandatory: refuse to start rather than silently sign tokens with a
    publicly-known value, which would let anyone forge tokens for any user. In
    local dev the fallback is allowed for convenience.
    """
    secret = os.environ.get('JWT_SECRET')
    in_production = bool(os.environ.get('GAE_ENV'))
    if in_production and (not secret or secret == _DEV_SECRET_FALLBACK):
        raise RuntimeError(
            "JWT_SECRET is missing or set to the insecure dev default in a "
            "production environment. Set a strong JWT_SECRET before deploying."
        )
    return secret or _DEV_SECRET_FALLBACK


JWT_SECRET = _load_jwt_secret()
ACCESS_TOKEN_EXPIRY = datetime.timedelta(minutes=15)
REFRESH_TOKEN_EXPIRY = datetime.timedelta(days=7)


def create_access_token(user_id):
    payload = {
        'user_id': user_id,
        'type': 'access',
        'jti': uuid.uuid4().hex,
        'exp': datetime.datetime.utcnow() + ACCESS_TOKEN_EXPIRY,
        'iat': datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def create_refresh_token(user_id):
    # A unique jti guarantees every refresh token is distinct even when two are
    # minted in the same second — required by rotation, which stores the new
    # token's hash and deletes the old one's. Without it, a same-second rotation
    # would store then delete the same hash and orphan the session.
    payload = {
        'user_id': user_id,
        'type': 'refresh',
        'jti': uuid.uuid4().hex,
        'exp': datetime.datetime.utcnow() + REFRESH_TOKEN_EXPIRY,
        'iat': datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def decode_token(token):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload, None
    except jwt.ExpiredSignatureError:
        return None, "Token has expired"
    except jwt.InvalidTokenError:
        return None, "Invalid token"


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            logger.warning("Auth failed: missing/invalid header for %s %s",
                           request.method, request.path)
            return error("Missing or invalid Authorization header", 401)

        token = auth_header[7:]
        payload, err = decode_token(token)
        if err:
            logger.warning("Auth failed: %s for %s %s (token prefix: %s...)",
                           err, request.method, request.path, token[:20] if token else "empty")
            return error(err, 401)

        if payload.get('type') != 'access':
            return error("Invalid token type", 401)

        g.user_id = payload['user_id']
        return f(*args, **kwargs)
    return decorated
