import datetime
import uuid

from google.cloud import datastore

client = datastore.Client()


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
        entity['created_at'] = datetime.datetime.utcnow()
    entity.update(data)
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


# ── Crew ──────────────────────────────────────────────────────────────────────

def create_crew(data, creator_id):
    key = client.key('Crew')
    entity = datastore.Entity(key=key)
    entity.update({
        'name': data['name'],
        'description': data.get('description', ''),
        'tags': data.get('tags', []),
        'creator_id': int(creator_id),
        'member_count': 1,
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    # auto-add creator as member
    add_crew_member(entity.key.id, creator_id)
    return _entity_to_dict(entity)


def get_crew(crew_id):
    key = client.key('Crew', int(crew_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def list_crews(filters=None):
    query = client.query(kind='Crew')
    if filters and filters.get('tag'):
        query.add_filter('tags', '=', filters['tag'])
    results = list(query.fetch(limit=50))
    return [_entity_to_dict(e) for e in results]


def update_crew_member_count(crew_id, delta):
    key = client.key('Crew', int(crew_id))
    entity = client.get(key)
    if entity:
        entity['member_count'] = entity.get('member_count', 0) + delta
        client.put(entity)


# ── CrewMember ────────────────────────────────────────────────────────────────

def add_crew_member(crew_id, user_id):
    member_key = f"{crew_id}_{user_id}"
    key = client.key('CrewMember', member_key)
    entity = datastore.Entity(key=key)
    entity.update({
        'crew_id': int(crew_id),
        'user_id': int(user_id),
        'joined_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_crew_member(crew_id, user_id):
    member_key = f"{crew_id}_{user_id}"
    key = client.key('CrewMember', member_key)
    entity = client.get(key)
    return _entity_to_dict(entity)


def remove_crew_member(crew_id, user_id):
    member_key = f"{crew_id}_{user_id}"
    key = client.key('CrewMember', member_key)
    client.delete(key)


def list_crew_members(crew_id):
    query = client.query(kind='CrewMember')
    query.add_filter('crew_id', '=', int(crew_id))
    results = list(query.fetch())
    return [_entity_to_dict(e) for e in results]


# ── Mission ───────────────────────────────────────────────────────────────────

def create_mission(data, creator_id):
    key = client.key('Mission')
    entity = datastore.Entity(key=key)
    entity.update({
        'title': data['title'],
        'description': data['description'],
        'tags': data.get('tags', []),
        'location': data.get('location', ''),
        'start_time': data['start_time'],
        'end_time': data['end_time'],
        'latitude': data.get('latitude'),
        'longitude': data.get('longitude'),
        'links': data.get('links', []),
        'images': data.get('images', []),
        'max_participants': data.get('max_participants', 0),
        'creator_id': int(creator_id),
        'hard_rsvp_count': 0,
        'soft_rsvp_count': 0,
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission(mission_id):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def update_mission(mission_id, data):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    if not entity:
        return None
    allowed = [
        'title', 'description', 'tags', 'location', 'start_time', 'end_time',
        'latitude', 'longitude', 'links', 'images', 'max_participants',
    ]
    for field in allowed:
        if field in data:
            entity[field] = data[field]
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


def delete_mission(mission_id):
    key = client.key('Mission', int(mission_id))
    client.delete(key)
    # Also delete all RSVPs for this mission
    query = client.query(kind='MissionRSVP')
    query.add_filter('mission_id', '=', int(mission_id))
    rsvps = list(query.fetch())
    for rsvp in rsvps:
        client.delete(rsvp.key)


def list_missions(filters=None):
    query = client.query(kind='Mission')
    if filters and filters.get('tag'):
        query.add_filter('tags', '=', filters['tag'])
    results = list(query.fetch(limit=50))
    return [_entity_to_dict(e) for e in results]


def update_mission_rsvp_count(mission_id, rsvp_type, delta):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    if entity:
        counter = 'hard_rsvp_count' if rsvp_type == 'hard' else 'soft_rsvp_count'
        entity[counter] = entity.get(counter, 0) + delta
        client.put(entity)


# ── MissionRSVP ──────────────────────────────────────────────────────────────

def add_mission_rsvp(mission_id, user_id, rsvp_type='hard'):
    rsvp_key = f"{mission_id}_{user_id}"
    key = client.key('MissionRSVP', rsvp_key)
    entity = datastore.Entity(key=key)
    entity.update({
        'mission_id': int(mission_id),
        'user_id': int(user_id),
        'rsvp_type': rsvp_type,
        'rsvped_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission_rsvp(mission_id, user_id):
    rsvp_key = f"{mission_id}_{user_id}"
    key = client.key('MissionRSVP', rsvp_key)
    entity = client.get(key)
    return _entity_to_dict(entity)


def remove_mission_rsvp(mission_id, user_id):
    """Remove an RSVP and return the rsvp_type for counter adjustment."""
    rsvp_key = f"{mission_id}_{user_id}"
    key = client.key('MissionRSVP', rsvp_key)
    entity = client.get(key)
    if not entity:
        return None
    rsvp_type = entity.get('rsvp_type', 'hard')
    client.delete(key)
    return rsvp_type


def list_mission_rsvps(mission_id):
    query = client.query(kind='MissionRSVP')
    query.add_filter('mission_id', '=', int(mission_id))
    results = list(query.fetch())
    return [_entity_to_dict(e) for e in results]


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
