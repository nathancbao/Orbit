import datetime
import uuid

from google.cloud import datastore
from google.cloud.datastore.query import PropertyFilter

from OrbitServer.utils.cache import mission_cache, pod_cache, user_cache

client = datastore.Client()

COLLEGE_YEARS = {'freshman', 'sophomore', 'junior', 'senior', 'grad'}


def _deep_convert(obj):
    """Recursively convert embedded Datastore entities and datetimes to JSON-safe types."""
    if isinstance(obj, datetime.datetime):
        return obj.replace(tzinfo=None).isoformat() + 'Z'
    if isinstance(obj, datetime.date):
        return obj.isoformat()
    if hasattr(obj, 'items'):
        return {k: _deep_convert(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_deep_convert(item) for item in obj]
    return obj


def _entity_to_dict(entity):
    if entity is None:
        return None
    d = _deep_convert(dict(entity))
    d['id'] = str(entity.key.id_or_name)
    return d


# ── User (merged with Profile) ──────────────────────────────────────────────
# Fields: email, name, college_year, interests, photo, trust_score,
#         created_at, updated_at

def create_user(email):
    key = client.key('User')
    entity = datastore.Entity(key=key)
    entity.update({
        'email': email,
        'name': '',
        'college_year': '',
        'interests': [],
        'photo': None,
        'gallery_photos': [],
        'bio': '',
        'links': [],
        'gender': '',
        'mbti': '',
        'trust_score': 0.0,
        'created_at': datetime.datetime.utcnow(),
        'updated_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_user_by_email(email):
    query = client.query(kind='User')
    query.add_filter(filter=PropertyFilter('email', '=', email))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


def get_user(user_id):
    cached = user_cache.get(int(user_id))
    if cached is not None:
        return cached
    key = client.key('User', int(user_id))
    entity = client.get(key)
    result = _entity_to_dict(entity)
    if result is not None:
        user_cache.set(int(user_id), result)
    return result


def update_user(user_id, data):
    key = client.key('User', int(user_id))
    entity = client.get(key)
    if entity is None:
        entity = datastore.Entity(key=key)
        entity['trust_score'] = 0.0
        entity['created_at'] = datetime.datetime.utcnow()
    entity.update(data)
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    user_cache.invalidate(int(user_id))
    return _entity_to_dict(entity)


def adjust_trust_score(user_id, delta):
    """Add delta to a user's trust_score, clamped to [0.0, 5.0].
    Uses a transaction to avoid lost updates from concurrent adjustments."""
    with client.transaction():
        key = client.key('User', int(user_id))
        entity = client.get(key)
        if entity:
            current = float(entity.get('trust_score', 0.0))
            entity['trust_score'] = max(0.0, min(5.0, current + delta))
            entity['updated_at'] = datetime.datetime.utcnow()
            client.put(entity)
    user_cache.invalidate(int(user_id))


def list_all_users(limit=10000):
    """Fetch all User records for model training."""
    query = client.query(kind='User')
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def search_users(query_str, exclude_user_id=None, limit=20):
    """Search users by name or email (case-insensitive partial match).

    Datastore doesn't support LIKE queries, so we fetch users and filter
    in Python. This is acceptable for moderate user counts.
    """
    q_lower = query_str.lower()
    query = client.query(kind='User')
    results = []
    for entity in query.fetch(limit=2000):
        name = (entity.get('name') or '').lower()
        email = (entity.get('email') or '').lower()
        if q_lower in name or q_lower in email:
            d = _entity_to_dict(entity)
            if exclude_user_id is not None and str(d.get('id')) == str(exclude_user_id):
                continue
            results.append(d)
            if len(results) >= limit:
                break
    return results


# ── Mission (was Event) ─────────────────────────────────────────────────────
# Fixed-date activities. Browseable in the discovery feed.
# Fields: id, title, description, tags, location, date (YYYY-MM-DD),
#         creator_id, creator_type (user|seeded|ai_suggested),
#         max_pod_size (default 4), status (open|completed|cancelled),
#         created_at, updated_at

def create_mission(data, creator_id, creator_type='user'):
    key = client.key('Mission')
    entity = datastore.Entity(key=key)
    entity.update({
        'title': data['title'],
        'description': data.get('description', ''),
        'tags': data.get('tags', []),
        'location': data.get('location', ''),
        'date': data.get('date', ''),
        'start_time': data.get('start_time'),
        'end_time': data.get('end_time'),
        'creator_id': int(creator_id),
        'creator_type': creator_type,
        'max_pod_size': int(data.get('max_pod_size', 4)),
        'utc_offset': data.get('utc_offset', 0),
        'status': 'open',
        'embedding': None,
        'created_at': datetime.datetime.utcnow(),
        'updated_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission(mission_id):
    cached = mission_cache.get(int(mission_id))
    if cached is not None:
        return cached
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    result = _entity_to_dict(entity)
    if result is not None:
        mission_cache.set(int(mission_id), result)
    return result


def update_mission(mission_id, data):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    if not entity:
        return None
    allowed = ['title', 'description', 'tags', 'location', 'date', 'start_time', 'end_time', 'max_pod_size', 'status']
    for field in allowed:
        if field in data:
            entity[field] = data[field]
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    mission_cache.invalidate(int(mission_id))
    return _entity_to_dict(entity)


def store_mission_embedding(mission_id, embedding: list):
    """Persist a float embedding vector to a Mission entity."""
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['embedding'] = embedding
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return True


def delete_mission(mission_id):
    key = client.key('Mission', int(mission_id))
    client.delete(key)
    mission_cache.invalidate(int(mission_id))
    # Cascade: delete all pods for this mission
    for pod in list_pods(mission_id):
        delete_pod(pod['id'])


def get_missions_batch(mission_ids):
    """Fetch multiple missions in a single Datastore multi-get. Returns {id: dict}."""
    if not mission_ids:
        return {}
    keys = [client.key('Mission', int(mid)) for mid in mission_ids]
    entities = client.get_multi(keys)
    result = {}
    for entity in entities:
        if entity is not None:
            d = _entity_to_dict(entity)
            result[d['id']] = d
    return result


def list_missions(filters=None):
    query = client.query(kind='Mission')
    if filters and filters.get('tag'):
        query.add_filter(filter=PropertyFilter('tags', '=', filters['tag']))
    if filters and filters.get('status'):
        query.add_filter(filter=PropertyFilter('status', '=', filters['status']))
    results = list(query.fetch(limit=100))
    return [_entity_to_dict(e) for e in results]


# ── Pod (was EventPod) ──────────────────────────────────────────────────────
# Fields: id (UUID string), mission_id, member_ids, max_size, name (string, nullable),
#         status (open|full|meeting_confirmed|completed|cancelled),
#         scheduled_time (string, nullable), scheduled_place (string, nullable),
#         confirmed_attendees, kick_votes {target_user_id: [voter_user_ids]},
#         created_at, expires_at

def create_pod(mission_id, max_size=4, first_member_id=None):
    pod_id = str(uuid.uuid4())
    key = client.key('Pod', pod_id)
    entity = datastore.Entity(key=key)
    now = datetime.datetime.utcnow()
    member_ids = [int(first_member_id)] if first_member_id else []
    entity.update({
        'mission_id': int(mission_id),
        'member_ids': member_ids,
        'max_size': int(max_size),
        'name': None,
        'status': 'open',
        'scheduled_time': None,
        'scheduled_place': None,
        'confirmed_attendees': [],
        'kick_votes': {},
        'schedule_data': {'entries': {}},
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=14),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_pod(pod_id):
    cached = pod_cache.get(str(pod_id))
    if cached is not None:
        return cached
    key = client.key('Pod', str(pod_id))
    entity = client.get(key)
    result = _entity_to_dict(entity)
    if result is not None:
        pod_cache.set(str(pod_id), result)
    return result


def update_pod(pod_id, data):
    key = client.key('Pod', str(pod_id))
    entity = client.get(key)
    if not entity:
        return None
    allowed = [
        'member_ids', 'status', 'scheduled_time', 'scheduled_place',
        'scheduled_end_time', 'confirmed_attendees', 'kick_votes',
        'expires_at', 'name', 'schedule_data',
        'survey_completed_by', 'completed_at',
    ]
    for field in allowed:
        if field in data:
            entity[field] = data[field]
    client.put(entity)
    pod_cache.invalidate(str(pod_id))
    return _entity_to_dict(entity)


def delete_pod(pod_id):
    key = client.key('Pod', str(pod_id))
    client.delete(key)
    pod_cache.invalidate(str(pod_id))
    # Cascade: delete messages and votes (batched to avoid memory issues)
    query = client.query(kind='ChatMessage')
    query.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    query.keys_only()
    for msg in query.fetch(limit=1000):
        client.delete(msg.key)
    query2 = client.query(kind='Vote')
    query2.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    query2.keys_only()
    for vote in query2.fetch(limit=1000):
        client.delete(vote.key)


def list_pods(mission_id, limit=500):
    query = client.query(kind='Pod')
    query.add_filter(filter=PropertyFilter('mission_id', '=', int(mission_id)))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def get_user_pod_for_mission(mission_id, user_id):
    """Return the pod this user belongs to for a given mission, or None."""
    for pod in list_pods(mission_id):
        if int(user_id) in (pod.get('member_ids') or []):
            return pod
    return None


def find_open_pod_for_mission(mission_id):
    """Return the first open pod with room, or None."""
    for pod in list_pods(mission_id):
        if pod['status'] == 'open' and len(pod.get('member_ids') or []) < pod['max_size']:
            return pod
    return None


def transactional_pod_update(pod_id, update_fn):
    """Atomically read-modify-write a Pod inside a Datastore transaction.

    update_fn(entity) is called with the raw Datastore entity.
    It should mutate the entity in place and return a result value.
    Returns (result, updated_pod_dict) or (None, None) if pod not found.
    """
    with client.transaction():
        key = client.key('Pod', str(pod_id))
        entity = client.get(key)
        if not entity:
            return None, None
        result = update_fn(entity)
        client.put(entity)
    pod_cache.invalidate(str(pod_id))
    return result, _entity_to_dict(entity)


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
    query.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    query.order = ['created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


# ── Vote ──────────────────────────────────────────────────────────────────────
# Fields: id (UUID), pod_id, created_by, vote_type (time|place),
#         options [list of strings], votes {user_id_str: option_index},
#         status (open|closed), result (string), created_at, closed_at

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
    """Atomically read-modify-write a Vote inside a Datastore transaction.

    update_fn(entity) is called with the raw Datastore entity.
    It should mutate the entity in place and return a result value.
    Returns (result, updated_vote_dict) or (None, None) if vote not found.
    """
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
    query.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


# ── UserHistory (was UserEventHistory) ────────────────────────────────────────
# Fields: id (UUID), user_id, mission_id, pod_id, action, attended, points_earned,
#         created_at

def record_action(user_id, mission_id, action, pod_id=None, tags_snapshot=None):
    """Record that a user interacted with a mission (joined/browsed/skipped).

    tags_snapshot: list of tags from the mission at interaction time, used by the
    ML recommendation engine for behavioral decay scoring.
    """
    hist_id = str(uuid.uuid4())
    key = client.key('UserHistory', hist_id)
    entity = datastore.Entity(key=key)
    entity.update({
        'user_id': int(user_id),
        'mission_id': int(mission_id),
        'pod_id': str(pod_id) if pod_id else None,
        'action': action,
        'attended': None,
        'points_earned': 0,
        'tags_snapshot': list(tags_snapshot) if tags_snapshot else [],
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_user_history(user_id, limit=50):
    query = client.query(kind='UserHistory')
    query.add_filter(filter=PropertyFilter('user_id', '=', int(user_id)))
    query.order = ['-created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def list_all_history(limit=10000):
    """Fetch all UserHistory records for model training."""
    query = client.query(kind='UserHistory')
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def update_history(hist_id, data):
    key = client.key('UserHistory', str(hist_id))
    entity = client.get(key)
    if not entity:
        return None
    for field in ['attended', 'points_earned', 'enjoyment_rating']:
        if field in data:
            entity[field] = data[field]
    client.put(entity)
    return _entity_to_dict(entity)


def get_history_entry(user_id, mission_id):
    """Get the most recent history entry for a user/mission pair."""
    query = client.query(kind='UserHistory')
    query.add_filter(filter=PropertyFilter('user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('mission_id', '=', int(mission_id)))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


# ── Signal (was Mission — spontaneous activity requests) ──────────────────────
# Fields: id (UUID string), creator_id, title, description,
#         activity_category (matches Swift ActivityCategory raw values),
#         custom_activity_name (string or None),
#         min_group_size (3+), max_group_size (<=8),
#         availability [{"date": "<ISO8601>", "time_blocks": ["morning", ...]}],
#         links (list of URL strings, max 2),
#         pod_ids (list of pod UUID strings, max 2, assigned on RSVP),
#         status (pending | active), created_at

def create_signal(data, creator_id):
    signal_id = str(uuid.uuid4())
    key = client.key('Signal', signal_id)
    entity = datastore.Entity(key=key, exclude_from_indexes=['availability', 'links'])
    entity.update({
        'creator_id': int(creator_id),
        'title': data.get('title', ''),
        'description': data.get('description', ''),
        'activity_category': data.get('activity_category', 'Custom'),
        'custom_activity_name': data.get('custom_activity_name'),
        'min_group_size': int(data.get('min_group_size', 3)),
        'max_group_size': int(data.get('max_group_size', 6)),
        'availability': data.get('availability', []),
        'tags': data.get('tags', []),
        'links': data.get('links', []),
        'time_range_start': int(data.get('time_range_start', 9)),
        'time_range_end': int(data.get('time_range_end', 21)),
        'rsvps': [],
        'status': 'pending',
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_signal(signal_id):
    key = client.key('Signal', str(signal_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def delete_signal(signal_id):
    key = client.key('Signal', str(signal_id))
    client.delete(key)


def list_signals_for_user(user_id, limit=100):
    query = client.query(kind='Signal')
    query.add_filter(filter=PropertyFilter('creator_id', '=', int(user_id)))
    query.order = ['-created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def list_all_signals(limit=50, cursor=None, category=None, tag=None):
    """Return Signal entities, newest first (for discover feed).

    Supports cursor-based pagination and optional category/tag filter.
    Returns (list_of_dicts, next_cursor_string_or_None).
    """
    query = client.query(kind='Signal')
    if category:
        query.add_filter(filter=PropertyFilter('activity_category', '=', category))
    if tag:
        query.add_filter(filter=PropertyFilter('tags', '=', tag))
    query.order = ['-created_at']
    # Cursor comes in as a string from the API — encode to bytes for Datastore
    start = cursor.encode('utf-8') if isinstance(cursor, str) else cursor
    query_iter = query.fetch(limit=limit, start_cursor=start)
    page = next(query_iter.pages)
    results = [_entity_to_dict(e) for e in page]
    next_cursor = query_iter.next_page_token
    return results, next_cursor.decode('utf-8') if next_cursor else None


def list_rsvped_signals(user_id, limit=100):
    """Return all Signal entities where user_id is in the rsvps list."""
    query = client.query(kind='Signal')
    query.add_filter(filter=PropertyFilter('rsvps', '=', int(user_id)))
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def remove_signal_rsvp(signal_id, user_id):
    """Remove a user from a signal's rsvps list."""
    key = client.key('Signal', str(signal_id))
    entity = client.get(key)
    if not entity:
        return
    rsvps = list(entity.get('rsvps') or [])
    uid = int(user_id)
    if uid in rsvps:
        rsvps.remove(uid)
        entity['rsvps'] = rsvps
        client.put(entity)


def update_signal_status(signal_id, status):
    """Update signal status. Valid values: 'pending' | 'active'."""
    key = client.key('Signal', str(signal_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['status'] = status
    client.put(entity)
    return _entity_to_dict(entity)


def transactional_signal_rsvp(signal_id, user_id):
    """Atomically add a user to a signal's rsvps list.

    Returns (signal_dict, error_string).
    - Rejects duplicate RSVPs.
    - Caps total RSVPs at 2 x max_group_size (2 pods max).
    - Auto-transitions status to 'active' when rsvps >= min_group_size.
    - Manages pod_ids list: first pod on first RSVP, second when pod 1 is full.
    """
    result = None
    err = None

    with client.transaction():
        key = client.key('Signal', str(signal_id))
        entity = client.get(key)
        if not entity:
            err = "Signal not found"
        else:
            rsvps = list(entity.get('rsvps') or [])
            uid = int(user_id)
            max_gs = int(entity.get('max_group_size', 6))

            if uid in rsvps:
                err = "You have already RSVP'd to this signal"
            elif len(rsvps) >= max_gs * 2:
                err = "This signal is full"
            else:
                rsvps.append(uid)
                entity['rsvps'] = rsvps

                min_gs = int(entity.get('min_group_size', 3))
                if len(rsvps) >= min_gs and entity.get('status') == 'pending':
                    entity['status'] = 'active'

                # Manage pod_ids: first pod on first RSVP, second on overflow
                pod_ids = list(entity.get('pod_ids') or [])
                # Migrate from old single pod_id field
                if not pod_ids and entity.get('pod_id'):
                    pod_ids = [entity['pod_id']]
                if not pod_ids:
                    pod_ids.append(str(uuid.uuid4()))
                elif len(rsvps) > max_gs and len(pod_ids) < 2:
                    pod_ids.append(str(uuid.uuid4()))
                entity['pod_ids'] = pod_ids

                client.put(entity)
                result = _entity_to_dict(entity)

    return result, err


def create_signal_pod(pod_id, signal_id, max_size=6, first_member_id=None):
    """Create a Pod linked to a signal (not a mission)."""
    key = client.key('Pod', str(pod_id))
    entity = datastore.Entity(key=key)
    now = datetime.datetime.utcnow()
    member_ids = [int(first_member_id)] if first_member_id else []
    entity.update({
        'mission_id': None,
        'signal_id': str(signal_id),
        'member_ids': member_ids,
        'max_size': int(max_size),
        'name': None,
        'status': 'open',
        'scheduled_time': None,
        'scheduled_place': None,
        'confirmed_attendees': [],
        'kick_votes': {},
        'schedule_data': {'entries': {}},
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=14),
    })
    client.put(entity)
    return _entity_to_dict(entity)


# ── Pod user membership query ────────────────────────────────────────────────

def get_user_pods(user_id, limit=100):
    """Return all Pod entities the user is a member of, enriched with mission_title,
    mission_tags, and has_pending_survey."""
    query = client.query(kind='Pod')
    query.add_filter(filter=PropertyFilter('member_ids', '=', int(user_id)))
    results = list(query.fetch(limit=limit))
    pods = [_entity_to_dict(e) for e in results]

    now = datetime.datetime.utcnow()
    survey_window = datetime.timedelta(days=7)

    # Filter out expired pods (2 hours after scheduled_end_time)
    live_pods = []
    for pod in pods:
        end_time_raw = pod.get('scheduled_end_time')
        if end_time_raw:
            end_dt = None
            if isinstance(end_time_raw, str):
                try:
                    end_dt = datetime.datetime.fromisoformat(
                        end_time_raw.replace('Z', '+00:00')
                    ).replace(tzinfo=None)
                except (ValueError, TypeError):
                    end_dt = None
            elif isinstance(end_time_raw, datetime.datetime):
                end_dt = end_time_raw
            if end_dt and now > end_dt + datetime.timedelta(hours=2):
                # Pod expired — delete and skip
                delete_pod(pod['id'])
                continue
        live_pods.append(pod)
    pods = live_pods

    for pod in pods:
        mission_id = pod.get('mission_id')
        if mission_id is not None:
            mission = get_mission(int(mission_id))
            pod['mission_title'] = mission.get('title', 'Untitled') if mission else 'Untitled'
            pod['mission_tags'] = mission.get('tags', []) if mission else []
        else:
            pod['mission_title'] = 'Untitled'
            pod['mission_tags'] = []

        # Survey eligibility: completed pod, user hasn't submitted, within 7-day window
        survey_completed_by = pod.get('survey_completed_by') or []
        completed_at_raw = pod.get('completed_at')
        if completed_at_raw and isinstance(completed_at_raw, str):
            try:
                completed_at = datetime.datetime.fromisoformat(completed_at_raw.replace('Z', '+00:00')).replace(tzinfo=None)
            except ValueError:
                completed_at = None
        else:
            completed_at = completed_at_raw if isinstance(completed_at_raw, datetime.datetime) else None

        pod['has_pending_survey'] = (
            pod.get('status') == 'completed'
            and int(user_id) not in survey_completed_by
            and (completed_at is None or (now - completed_at) < survey_window)
        )

    return pods


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


# ── FriendRequest ─────────────────────────────────────────────────────────────

def create_friend_request(from_user_id, to_user_id):
    key = client.key('FriendRequest')
    entity = datastore.Entity(key=key)
    entity.update({
        'from_user_id': int(from_user_id),
        'to_user_id': int(to_user_id),
        'status': 'pending',
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_friend_request(request_id):
    key = client.key('FriendRequest', int(request_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_friend_request_status(request_id, status):
    key = client.key('FriendRequest', int(request_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['status'] = status
    client.put(entity)
    return _entity_to_dict(entity)


def list_incoming_friend_requests(user_id):
    query = client.query(kind='FriendRequest')
    query.add_filter(filter=PropertyFilter('to_user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('status', '=', 'pending'))
    results = list(query.fetch(limit=100))
    return [_entity_to_dict(e) for e in results]


def list_outgoing_friend_requests(user_id):
    query = client.query(kind='FriendRequest')
    query.add_filter(filter=PropertyFilter('from_user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('status', '=', 'pending'))
    results = list(query.fetch(limit=100))
    return [_entity_to_dict(e) for e in results]


def find_pending_request(from_user_id, to_user_id):
    """Find a pending FriendRequest between two users (one direction)."""
    query = client.query(kind='FriendRequest')
    query.add_filter(filter=PropertyFilter('from_user_id', '=', int(from_user_id)))
    query.add_filter(filter=PropertyFilter('to_user_id', '=', int(to_user_id)))
    query.add_filter(filter=PropertyFilter('status', '=', 'pending'))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


# ── Friendship ────────────────────────────────────────────────────────────────

def create_friendship(user_id, friend_id):
    """Create a single directional Friendship entity."""
    key = client.key('Friendship')
    entity = datastore.Entity(key=key)
    entity.update({
        'user_id': int(user_id),
        'friend_id': int(friend_id),
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_friendship(friendship_id):
    key = client.key('Friendship', int(friendship_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def list_friendships(user_id):
    query = client.query(kind='Friendship')
    query.add_filter(filter=PropertyFilter('user_id', '=', int(user_id)))
    results = list(query.fetch(limit=500))
    return [_entity_to_dict(e) for e in results]


def find_friendship(user_id, friend_id):
    """Find a Friendship entity for user_id -> friend_id."""
    query = client.query(kind='Friendship')
    query.add_filter(filter=PropertyFilter('user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('friend_id', '=', int(friend_id)))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


def delete_friendship(friendship_id):
    key = client.key('Friendship', int(friendship_id))
    client.delete(key)


# ── DM Helpers ────────────────────────────────────────────────────────────────

def dm_conversation_id(user_a, user_b):
    """Deterministic conversation ID for a DM between two users."""
    a, b = sorted([int(user_a), int(user_b)])
    return f"dm_{a}_{b}"


def list_dm_conversations(user_id):
    """Return distinct DM conversation IDs this user participates in,
    along with the last message in each conversation.

    DMs reuse the ChatMessage entity with pod_id = 'dm_<a>_<b>'.
    """
    uid = int(user_id)
    query = client.query(kind='ChatMessage')
    # Fetch DM messages — filter by prefix isn't possible in Datastore,
    # so we scan and filter in Python (fine for moderate DM volume).
    results = list(query.fetch(limit=5000))
    conversations = {}
    for entity in results:
        pid = entity.get('pod_id', '')
        if not pid.startswith('dm_'):
            continue
        # Check if this user is a participant
        parts = pid.split('_')
        if len(parts) != 3:
            continue
        if str(uid) not in (parts[1], parts[2]):
            continue
        d = _entity_to_dict(entity)
        existing = conversations.get(pid)
        if existing is None or d['created_at'] > existing['created_at']:
            conversations[pid] = d
    return list(conversations.values())


# ── SurveyResponse ────────────────────────────────────────────────────────────
# Fields: id (UUID), user_id, pod_id, mission_id, enjoyment_rating,
#         added_interests, member_votes, created_at

def create_survey_response(user_id, pod_id, mission_id, enjoyment_rating, added_interests, member_votes):
    survey_id = str(uuid.uuid4())
    key = client.key('SurveyResponse', survey_id)
    entity = datastore.Entity(key=key)
    entity.update({
        'user_id': int(user_id),
        'pod_id': str(pod_id),
        'mission_id': int(mission_id) if mission_id is not None else None,
        'enjoyment_rating': int(enjoyment_rating),
        'added_interests': list(added_interests) if added_interests else [],
        'member_votes': dict(member_votes) if member_votes else {},
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_user_survey_for_pod(user_id, pod_id):
    """Check if a user already submitted a survey for this pod."""
    query = client.query(kind='SurveyResponse')
    query.add_filter(filter=PropertyFilter('user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


# ── PodInvite ────────────────────────────────────────────────────────────────
# Fields: id, pod_id, from_user_id, to_user_id, status (pending|accepted|declined),
#         created_at

def create_pod_invite(pod_id, from_user_id, to_user_id):
    key = client.key('PodInvite')
    entity = datastore.Entity(key=key)
    entity.update({
        'pod_id': str(pod_id),
        'from_user_id': int(from_user_id),
        'to_user_id': int(to_user_id),
        'status': 'pending',
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_pod_invite(invite_id):
    key = client.key('PodInvite', int(invite_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_pod_invite_status(invite_id, status):
    key = client.key('PodInvite', int(invite_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['status'] = status
    client.put(entity)
    return _entity_to_dict(entity)


def list_incoming_pod_invites(user_id):
    query = client.query(kind='PodInvite')
    query.add_filter(filter=PropertyFilter('to_user_id', '=', int(user_id)))
    query.add_filter(filter=PropertyFilter('status', '=', 'pending'))
    results = list(query.fetch(limit=100))
    return [_entity_to_dict(e) for e in results]


def find_pending_pod_invite(pod_id, from_user_id, to_user_id):
    """Find an existing pending invite for this pod/user pair."""
    query = client.query(kind='PodInvite')
    query.add_filter(filter=PropertyFilter('pod_id', '=', str(pod_id)))
    query.add_filter(filter=PropertyFilter('to_user_id', '=', int(to_user_id)))
    query.add_filter(filter=PropertyFilter('status', '=', 'pending'))
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None
