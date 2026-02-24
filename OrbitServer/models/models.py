import datetime
import uuid

from google.cloud import datastore

client = datastore.Client()

COLLEGE_YEARS = {'freshman', 'sophomore', 'junior', 'senior', 'grad'}


def _deep_convert(obj):
    """Recursively convert embedded Datastore entities to plain dicts."""
    if hasattr(obj, 'items'):
        return {k: _deep_convert(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [_deep_convert(item) for item in obj]
    return obj


def _entity_to_dict(entity):
    if entity is None:
        return None
    d = _deep_convert(dict(entity))
    d['id'] = entity.key.id_or_name
    return d


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
# Fields: user_id, name, college_year, interests, trust_score, photo, email,
#         created_at, updated_at

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
        entity['trust_score'] = 3.0
        entity['created_at'] = datetime.datetime.utcnow()
    entity.update(data)
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


def adjust_trust_score(user_id, delta):
    """Add delta to a user's trust_score, clamped to [0.0, 5.0]."""
    key = client.key('Profile', int(user_id))
    entity = client.get(key)
    if entity:
        current = float(entity.get('trust_score', 3.0))
        entity['trust_score'] = max(0.0, min(5.0, current + delta))
        entity['updated_at'] = datetime.datetime.utcnow()
        client.put(entity)


# ── Event ─────────────────────────────────────────────────────────────────────
# Replaces Mission.
# Fields: id, title, description, tags, location, date (YYYY-MM-DD),
#         creator_id, creator_type (user|seeded|ai_suggested),
#         max_pod_size (default 4), status (open|completed|cancelled),
#         created_at, updated_at

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


def delete_event(event_id):
    key = client.key('Event', int(event_id))
    client.delete(key)
    # Cascade: delete all pods for this event
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
# Fields: id (UUID string), event_id, member_ids, max_size,
#         status (open|full|meeting_confirmed|completed|cancelled),
#         scheduled_time (string, nullable), scheduled_place (string, nullable),
#         confirmed_attendees, kick_votes {target_user_id: [voter_user_ids]},
#         created_at, expires_at

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
        'expires_at': now + datetime.timedelta(days=2),  # updated when time is set
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
    # Cascade: delete messages and votes
    query = client.query(kind='ChatMessage')
    query.add_filter('pod_id', '=', str(pod_id))
    for msg in list(query.fetch()):
        client.delete(msg.key)
    query2 = client.query(kind='Vote')
    query2.add_filter('pod_id', '=', str(pod_id))
    for vote in list(query2.fetch()):
        client.delete(vote.key)


def list_event_pods(event_id):
    query = client.query(kind='EventPod')
    query.add_filter('event_id', '=', int(event_id))
    results = list(query.fetch())
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


# ── ChatMessage ───────────────────────────────────────────────────────────────
# Fields: id (UUID), pod_id, user_id, content, message_type, created_at

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
# Fields: id (UUID), pod_id, created_by, vote_type (time|place),
#         options [list of strings], votes {user_id_str: option_index},
#         status (open|closed), result (string), created_at, closed_at

def create_vote(pod_id, created_by, vote_type, options):
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


def list_votes_for_pod(pod_id):
    query = client.query(kind='Vote')
    query.add_filter('pod_id', '=', str(pod_id))
    results = list(query.fetch())
    return [_entity_to_dict(e) for e in results]


# ── UserEventHistory ──────────────────────────────────────────────────────────
# Fields: id (UUID), user_id, event_id, pod_id, action, attended, points_earned,
#         created_at

def record_event_action(user_id, event_id, action, pod_id=None):
    """Record that a user interacted with an event (joined/browsed/skipped)."""
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


# ── Mission (Activity Request) ────────────────────────────────────────────────
# Fields: id (UUID string), creator_id, title, description,
#         activity_category (matches Swift ActivityCategory raw values),
#         custom_activity_name (string or None),
#         min_group_size, max_group_size,
#         availability [{"date": "<ISO8601>", "time_blocks": ["morning", ...]}],
#         status (pending_match | matched), created_at
#
# NOTE: When the Swift MissionsViewModel is wired to this API, AvailabilitySlot
# will need a CodingKeys mapping for time_blocks ↔ "time_blocks" (snake_case).

def create_mission(data, creator_id):
    mission_id = str(uuid.uuid4())
    key = client.key('Mission', mission_id)
    entity = datastore.Entity(key=key, exclude_from_indexes=['availability'])
    entity.update({
        'creator_id': int(creator_id),
        'title': data.get('title', ''),
        'description': data.get('description', ''),
        'activity_category': data.get('activity_category', 'Custom'),
        'custom_activity_name': data.get('custom_activity_name'),
        'min_group_size': int(data.get('min_group_size', 2)),
        'max_group_size': int(data.get('max_group_size', 6)),
        'availability': data.get('availability', []),
        'status': 'pending_match',
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission(mission_id):
    key = client.key('Mission', str(mission_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def delete_mission(mission_id):
    key = client.key('Mission', str(mission_id))
    client.delete(key)


def list_missions_for_user(user_id):
    query = client.query(kind='Mission')
    query.add_filter('creator_id', '=', int(user_id))
    query.order = ['-created_at']
    results = list(query.fetch())
    return [_entity_to_dict(e) for e in results]


def update_mission_status(mission_id, status):
    key = client.key('Mission', str(mission_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['status'] = status
    client.put(entity)
    return _entity_to_dict(entity)


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
        'created_at': datetime.datetime.utcnow(),
        'expires_at': datetime.datetime.utcnow() + datetime.timedelta(minutes=10),
    })
    client.put(entity)


def get_verification_code(email):
    key = client.key('VerificationCode', email)
    entity = client.get(key)
    return _entity_to_dict(entity)


def delete_verification_code(email):
    key = client.key('VerificationCode', email)
    client.delete(key)
