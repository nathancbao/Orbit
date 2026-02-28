import datetime
import uuid

from google.cloud import datastore

from OrbitServer.models.base import client, _entity_to_dict


# ── ChatMessage ───────────────────────────────────────────────────────────────

def create_chat_message(pod_id, user_id, content, message_type='text'):
    msg_id = str(uuid.uuid4())
    key = client.key('ChatMessage', msg_id)
    entity = datastore.Entity(key=key, exclude_from_indexes=['content'])
    entity.update({
        'pod_id': str(pod_id),
        'user_id': int(user_id),
        'content': content,
        'message_type': message_type,
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def list_chat_messages(pod_id, limit=100):
    query = client.query(kind='ChatMessage')
    query.add_filter('pod_id', '=', str(pod_id))
    query.order = ['created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


# ── Vote ──────────────────────────────────────────────────────────────────────

def create_vote(pod_id, created_by, vote_type, options, expected_voters=None):
    vote_id = str(uuid.uuid4())
    key = client.key('Vote', vote_id)
    entity = datastore.Entity(key=key)
    entity.update({
        'pod_id': str(pod_id),
        'created_by': int(created_by),
        'vote_type': vote_type,
        'options': list(options),
        'votes': {},
        'status': 'open',
        'result': None,
        'expected_voters': expected_voters,
        'created_at': datetime.datetime.utcnow(),
        'closed_at': None,
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_vote(vote_id):
    key = client.key('Vote', str(vote_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_vote(vote_id, data):
    key = client.key('Vote', str(vote_id))
    entity = client.get(key)
    if not entity:
        return None
    for field in ['votes', 'status', 'result', 'closed_at']:
        if field in data:
            entity[field] = data[field]
    client.put(entity)
    return _entity_to_dict(entity)


def transactional_vote_update(vote_id, update_fn):
    """Atomically read-modify-write a Vote inside a Datastore transaction."""
    with client.transaction():
        key = client.key('Vote', str(vote_id))
        entity = client.get(key)
        if not entity:
            return None, None
        result = update_fn(entity)
        client.put(entity)
        return result, _entity_to_dict(entity)


def list_votes_for_pod(pod_id, limit=100):
    query = client.query(kind='Vote')
    query.add_filter('pod_id', '=', str(pod_id))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]
