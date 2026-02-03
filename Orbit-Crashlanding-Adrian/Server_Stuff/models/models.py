import datetime
import uuid

from google.cloud import datastore

client = datastore.Client()


def _entity_to_dict(entity):
    if entity is None:
        return None
    d = dict(entity)
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
        'time': data.get('time', ''),
        'creator_id': int(creator_id),
        'rsvp_count': 0,
        'created_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission(mission_id):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    return _entity_to_dict(entity)


def list_missions(filters=None):
    query = client.query(kind='Mission')
    if filters and filters.get('tag'):
        query.add_filter('tags', '=', filters['tag'])
    results = list(query.fetch(limit=50))
    return [_entity_to_dict(e) for e in results]


def update_mission_rsvp_count(mission_id, delta):
    key = client.key('Mission', int(mission_id))
    entity = client.get(key)
    if entity:
        entity['rsvp_count'] = entity.get('rsvp_count', 0) + delta
        client.put(entity)


# ── MissionRSVP ──────────────────────────────────────────────────────────────

def add_mission_rsvp(mission_id, user_id):
    rsvp_key = f"{mission_id}_{user_id}"
    key = client.key('MissionRSVP', rsvp_key)
    entity = datastore.Entity(key=key)
    entity.update({
        'mission_id': int(mission_id),
        'user_id': int(user_id),
        'rsvped_at': datetime.datetime.utcnow(),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_mission_rsvp(mission_id, user_id):
    rsvp_key = f"{mission_id}_{user_id}"
    key = client.key('MissionRSVP', rsvp_key)
    entity = client.get(key)
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
