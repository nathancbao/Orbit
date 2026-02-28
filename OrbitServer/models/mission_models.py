import datetime
import uuid

from google.cloud import datastore

from OrbitServer.models.base import client, _entity_to_dict


# ── Mission (Activity Request / Signal) ───────────────────────────────────────

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
        'rsvps': [],
        'status': 'pending',
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


def list_missions_for_user(user_id, limit=100):
    query = client.query(kind='Mission')
    query.add_filter('creator_id', '=', int(user_id))
    query.order = ['-created_at']
    results = list(query.fetch(limit=limit))
    return [_entity_to_dict(e) for e in results]


def update_mission_status(mission_id, status):
    """Update signal/mission status. Valid values: 'pending' | 'active'."""
    key = client.key('Mission', str(mission_id))
    entity = client.get(key)
    if not entity:
        return None
    entity['status'] = status
    client.put(entity)
    return _entity_to_dict(entity)


def transactional_mission_rsvp(mission_id, user_id):
    """Atomically add a user to a mission's rsvps list.

    Returns (mission_dict, error_string).
    - Rejects duplicate RSVPs.
    - Auto-transitions status to 'active' when rsvps >= min_group_size.
    """
    with client.transaction():
        key = client.key('Mission', str(mission_id))
        entity = client.get(key)
        if not entity:
            return None, "Mission not found"

        rsvps = list(entity.get('rsvps') or [])
        uid = int(user_id)
        if uid in rsvps:
            return None, "You have already RSVP'd to this signal"

        rsvps.append(uid)
        entity['rsvps'] = rsvps

        min_gs = int(entity.get('min_group_size', 2))
        if len(rsvps) >= min_gs and entity.get('status') == 'pending':
            entity['status'] = 'active'

        client.put(entity)
        return _entity_to_dict(entity), None


def list_all_missions(limit=50, cursor_token=None, category=None, exclude_user_id=None):
    """Return missions for the discover feed with optional filters.

    Returns (list_of_missions, next_cursor_token_or_None).
    """
    query = client.query(kind='Mission')
    if category:
        query.add_filter('activity_category', '=', category)
    query.order = ['-created_at']

    query_iter = query.fetch(limit=limit, start_cursor=cursor_token)
    page = next(query_iter.pages)
    missions = [_entity_to_dict(e) for e in page]

    # Filter out expired signals (all availability dates in the past)
    today = datetime.date.today().isoformat()
    filtered = []
    for m in missions:
        avail = m.get('availability') or []
        if avail and all(slot.get('date', '') < today for slot in avail):
            continue
        if exclude_user_id and m.get('creator_id') == int(exclude_user_id):
            continue
        filtered.append(m)

    next_cursor = query_iter.next_page_token
    return filtered, next_cursor
