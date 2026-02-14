"""
Signals — Data Layer

Entity types:
  Signal      – A pending group invite (expires 7 days).
  Pod         – An accepted group (lasts 7 days).
  ContactInfo – A user's revealable contact info.

Legacy PodQueue / old Pod entities are no longer created but existing
Datastore rows are harmless (schemaless DB).
"""

import datetime
import uuid

from google.cloud import datastore

client = datastore.Client()

SIGNAL_TTL_DAYS = 7
POD_TTL_DAYS = 7


def _entity_to_dict(entity):
    """Convert a Datastore entity to a plain dict with an 'id' field."""
    if entity is None:
        return None
    d = dict(entity)
    d['id'] = entity.key.id_or_name
    return d


# ── Signal CRUD ──────────────────────────────────────────────────────────────

def create_signal(creator_id, target_user_ids):
    """Create a new Signal entity with a 7-day TTL.

    Parameters:
        creator_id: user who triggered the search
        target_user_ids: list of all matched user ids (including creator)

    Returns the new signal as a dict.
    """
    signal_id = str(uuid.uuid4())
    key = client.key('Signal', signal_id)
    now = datetime.datetime.utcnow()
    entity = datastore.Entity(key=key)
    entity.update({
        'creator_id': int(creator_id),
        'target_user_ids': [int(uid) for uid in target_user_ids],
        'accepted_user_ids': [],
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=SIGNAL_TTL_DAYS),
        'status': 'pending',
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_signal(signal_id):
    """Get a single signal by ID."""
    key = client.key('Signal', signal_id)
    entity = client.get(key)
    return _entity_to_dict(entity)


def get_signal_for_user(user_id):
    """Find the most recent *pending* signal that includes this user."""
    query = client.query(kind='Signal')
    query.add_filter('target_user_ids', '=', int(user_id))
    query.add_filter('status', '=', 'pending')
    query.order = ['-created_at']
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


def accept_signal(signal_id, user_id):
    """Record a user's acceptance on a signal.

    Returns the updated signal dict.
    """
    key = client.key('Signal', signal_id)
    entity = client.get(key)
    if entity is None:
        return None

    accepted = list(entity.get('accepted_user_ids', []))
    uid = int(user_id)
    if uid not in accepted:
        accepted.append(uid)
    entity['accepted_user_ids'] = accepted

    # If everyone accepted → mark signal as accepted
    targets = entity.get('target_user_ids', [])
    if set(accepted) >= set(targets):
        entity['status'] = 'accepted'

    client.put(entity)
    return _entity_to_dict(entity)


def expire_signal(signal_id):
    """Mark a signal as expired."""
    key = client.key('Signal', signal_id)
    entity = client.get(key)
    if entity:
        entity['status'] = 'expired'
        client.put(entity)


# ── Pod CRUD ─────────────────────────────────────────────────────────────────

def create_pod_from_signal(signal):
    """Convert an accepted Signal into a Pod with a 7-day TTL.

    Parameters:
        signal: dict with at minimum 'target_user_ids' and 'id'

    Returns the new pod as a dict.
    """
    pod_id = str(uuid.uuid4())
    key = client.key('Pod', pod_id)
    now = datetime.datetime.utcnow()
    entity = datastore.Entity(key=key)
    entity.update({
        'members': [int(uid) for uid in signal['target_user_ids']],
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=POD_TTL_DAYS),
        'revealed': False,
        'signal_id': str(signal['id']),
    })
    client.put(entity)
    return _entity_to_dict(entity)


def get_active_pod(user_id):
    """Find the most recent pod that contains this user."""
    query = client.query(kind='Pod')
    query.add_filter('members', '=', int(user_id))
    query.order = ['-created_at']
    results = list(query.fetch(limit=1))
    return _entity_to_dict(results[0]) if results else None


def reveal_pod(pod_id):
    """Set revealed=True on a pod."""
    key = client.key('Pod', pod_id)
    entity = client.get(key)
    if entity:
        entity['revealed'] = True
        client.put(entity)
        return _entity_to_dict(entity)
    return None


# ── ContactInfo CRUD ─────────────────────────────────────────────────────────

def upsert_contact_info(user_id, data):
    """Create or update a user's revealable contact info.

    data may contain 'instagram' and/or 'phone'.
    Returns the upserted dict.
    """
    key = client.key('ContactInfo', int(user_id))
    entity = client.get(key)
    if entity is None:
        entity = datastore.Entity(key=key)
    if 'instagram' in data:
        entity['instagram'] = data['instagram']
    if 'phone' in data:
        entity['phone'] = data['phone']
    entity['updated_at'] = datetime.datetime.utcnow()
    client.put(entity)
    return _entity_to_dict(entity)


def get_contact_info(user_id):
    """Get a user's revealable contact info."""
    key = client.key('ContactInfo', int(user_id))
    entity = client.get(key)
    return _entity_to_dict(entity)
