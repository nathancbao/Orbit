import os
import datetime
import logging
from functools import wraps

import jwt
from flask import request, g

from OrbitServer.utils.responses import error

logger = logging.getLogger(__name__)

JWT_SECRET = os.environ.get('JWT_SECRET', 'dev-secret-change-me')
ACCESS_TOKEN_EXPIRY = datetime.timedelta(minutes=15)
REFRESH_TOKEN_EXPIRY = datetime.timedelta(days=7)


def create_access_token(user_id):
    payload = {
        'user_id': user_id,
        'type': 'access',
        'exp': datetime.datetime.utcnow() + ACCESS_TOKEN_EXPIRY,
        'iat': datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def create_refresh_token(user_id):
    payload = {
        'user_id': user_id,
        'type': 'refresh',
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
