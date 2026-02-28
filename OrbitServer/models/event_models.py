import datetime
import uuid

from google.cloud import datastore

from OrbitServer.models.base import client, _entity_to_dict


# ── Event ─────────────────────────────────────────────────────────────────────

def create_event(data, creator_id, creator_type='user'):
    key = client.key('Event')
    entity = datastore.Entity(key=key)
    entity.update({
        'title': data['title'],
        'description': data['description'],
        'tags': data.get('tags', []),
        'location': data.get('location', ''),
        'date': data.get('date', ''),
        'creator_id': int(creator_id),
        'creator_type': creator_type,
        'max_pod_size': int(data.get('max_pod_size', 4)),
        'status': 'open',
        'embedding': None,
        'created_at': datetime.datetime.utcnow(),
        'updated_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_event(event_id):
    key = client.key('Event', int(event_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_event(event_id, data):
    key = client.key('Event', int(event_id))
    entity = client.get(key)
    if not entity:
        return None
    allowed = ['title', 'description', 'tags', 'location', 'date', 'max_pod_size', 'status']
    for field in allowed:
        if field in data:
            entity[field] = data[field]
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


def store_event_embedding(event_id, embedding: list):
    """Persist a float embedding vector to an Event entity."""
    key = client.key('Event', int(event_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['embedding'] = embedding
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return True


def delete_event(event_id):
    key = client.key('Event', int(event_id))
    client.delete(key)
    for pod in list_event_pods(event_id):
        delete_event_pod(pod['id'])


def list_events(filters=None):
    query = client.query(kind='Event')
    if filters and filters.get('tag'):
        query.add_filter('tags', '=', filters['tag'])
    if filters and filters.get('status'):
        query.add_filter('status', '=', filters['status'])
    results = list(query.fetch(limit=100))
    return [_entity_to_dict(e) for e in results]


# ── EventPod ──────────────────────────────────────────────────────────────────

def create_event_pod(event_id, max_size=4, first_member_id=None):
    pod_id = str(uuid.uuid4())
    key = client.key('EventPod', pod_id)
    entity = datastore.Entity(key=key)
    now = datetime.datetime.utcnow()
    member_ids = [int(first_member_id)] if first_member_id else []
    entity.update({
        'event_id': int(event_id),
        'member_ids': member_ids,
        'max_size': int(max_size),
        'status': 'open',
        'scheduled_time': None,
        'scheduled_place': None,
        'confirmed_attendees': [],
        'kick_votes': {},
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=2),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_event_pod(pod_id):
    key = client.key('EventPod', str(pod_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_event_pod(pod_id, data):
    key = client.key('EventPod', str(pod_id))
    entity = client.get(key)
    if not entity:
        return None
    allowed = [
        'member_ids', 'status', 'scheduled_time', 'scheduled_place',
        'confirmed_attendees', 'kick_votes', 'expires_at',
    ]
    for field in allowed:
        if field in data:
            entity[field] = data[field]
    client.put(entity)
    return _entity_to_dict(entity)


def delete_event_pod(pod_id):
    key = client.key('EventPod', str(pod_id))
    client.delete(key)
    query = client.query(kind='ChatMessage')
    query.add_filter('pod_id', '=', str(pod_id))
    query.keys_only()
    for msg in query.fetch(limit=1000):
        client.delete(msg.key)
    query2 = client.query(kind='Vote')
    query2.add_filter('pod_id', '=', str(pod_id))
    query2.keys_only()
    for vote in query2.fetch(limit=1000):
        client.delete(vote.key)


def list_event_pods(event_id, limit=500):
    query = client.query(kind='EventPod')
    query.add_filter('event_id', '=', int(event_id))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def get_user_pod_for_event(event_id, user_id):
    """Return the pod this user belongs to for a given event, or None."""
    for pod in list_event_pods(event_id):
        if int(user_id) in (pod.get('member_ids') or []):
            return pod
    return None


def find_open_pod_for_event(event_id):
    """Return the first open pod with room, or None."""
    for pod in list_event_pods(event_id):
        if pod['status'] == 'open' and len(pod.get('member_ids') or []) < pod['max_size']:
            return pod
    return None


def transactional_pod_update(pod_id, update_fn):
    """Atomically read-modify-write an EventPod inside a Datastore transaction."""
    with client.transaction():
        key = client.key('EventPod', str(pod_id))
        entity = client.get(key)
        if not entity:
            return None, None
        result = update_fn(entity)
        client.put(entity)
        return result, _entity_to_dict(entity)


def get_user_pods(user_id, limit=100):
    """Return all EventPod entities the user is a member of."""
    query = client.query(kind='EventPod')
    query.add_filter('member_ids', '=', int(user_id))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


# ── UserEventHistory ──────────────────────────────────────────────────────────

def record_event_action(user_id, event_id, action, pod_id=None, tags_snapshot=None):
    hist_id = str(uuid.uuid4())
    key = client.key('UserEventHistory', hist_id)
    entity = datastore.Entity(key=key)
    entity.update({
        'user_id': int(user_id),
        'event_id': int(event_id),
        'pod_id': str(pod_id) if pod_id else None,
        'action': action,
        'attended': None,
        'points_earned': 0,
        'tags_snapshot': list(tags_snapshot) if tags_snapshot else [],
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_user_event_history(user_id, limit=50):
    query = client.query(kind='UserEventHistory')
    query.add_filter('user_id', '=', int(user_id))
    query.order = ['-created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def update_event_history(hist_id, data):
    key = client.key('UserEventHistory', str(hist_id))
    entity = client.get(key)
    if not entity:
        return None
    for field in ['attended', 'points_earned']:
        if field in data:
            entity[field] = data[field]
    client.put(entity)
    return _entity_to_dict(entity)


def get_history_entry(user_id, event_id):
    """Get the most recent history entry for a user/event pair."""
    query = client.query(kind='UserEventHistory')
    query.add_filter('user_id', '=', int(user_id))
    query.add_filter('event_id', '=', int(event_id))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None
