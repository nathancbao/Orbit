import datetime

from google.cloud import datastore

from OrbitServer.models.base import client, _entity_to_dict


# ── RefreshToken ──────────────────────────────────────────────────────────────

def store_refresh_token(token, user_id):
    key = client.key('RefreshToken', token)
    entity = datastore.Entity(key=key)
    entity.update({
        'user_id': int(user_id),
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)


def get_refresh_token(token):
    key = client.key('RefreshToken', token)
    entity = client.get(key)
    return _entity_to_dict(entity)


def delete_refresh_token(token):
    key = client.key('RefreshToken', token)
    client.delete(key)


# ── VerificationCode ─────────────────────────────────────────────────────────

def store_verification_code(email, code):
    key = client.key('VerificationCode', email)
    entity = datastore.Entity(key=key)
    entity.update({
        'email': email,
        'code': code,
        'failed_attempts': 0,
        'created_at': datetime.datetime.utcnow(),
        'expires_at': datetime.datetime.utcnow() + datetime.timedelta(minutes=10),
    })
    client.put(entity)


def increment_failed_attempts(email):
    """Increment failed_attempts counter. Returns new count."""
    key = client.key('VerificationCode', email)
    entity = client.get(key)
    if not entity:
        return 0
    count = int(entity.get('failed_attempts', 0)) + 1
    entity['failed_attempts'] = count
    client.put(entity)
    return count


def get_verification_code(email):
    key = client.key('VerificationCode', email)
    entity = client.get(key)
    return _entity_to_dict(entity)


def delete_verification_code(email):
    key = client.key('VerificationCode', email)
    client.delete(key)
