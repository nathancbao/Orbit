import datetime

from google.cloud import datastore

from OrbitServer.models.base import client, _entity_to_dict

COLLEGE_YEARS = {'freshman', 'sophomore', 'junior', 'senior', 'grad'}


# ── User ──────────────────────────────────────────────────────────────────────

def create_user(email):
    key = client.key('User')
    entity = datastore.Entity(key=key)
    entity.update({
        'email': email,
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_user_by_email(email):
    query = client.query(kind='User')
    query.add_filter('email', '=', email)
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


def get_user(user_id):
    key = client.key('User', int(user_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


# ── Profile ───────────────────────────────────────────────────────────────────

def get_profile(user_id):
    key = client.key('Profile', int(user_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def upsert_profile(user_id, data):
    key = client.key('Profile', int(user_id))
    entity = client.get(key)
    if entity is None:
        entity = datastore.Entity(key=key)
        entity['user_id'] = int(user_id)
        entity['trust_score'] = 0.0
        entity['created_at'] = datetime.datetime.utcnow()
    entity.update(data)
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


def adjust_trust_score(user_id, delta):
    """Add delta to a user's trust_score, clamped to [0.0, 5.0]."""
    with client.transaction():
        key = client.key('Profile', int(user_id))
        entity = client.get(key)
        if entity:
            current = float(entity.get('trust_score', 0.0))
            entity['trust_score'] = max(0.0, min(5.0, current + delta))
            entity['updated_at'] = datetime.datetime.utcnow()
            client.put(entity)
