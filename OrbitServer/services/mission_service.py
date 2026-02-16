import datetime

from OrbitServer.models.models import (
    create_mission as db_create_mission,
    get_mission, get_mission_rsvp, add_mission_rsvp,
    remove_mission_rsvp, update_mission_rsvp_count,
    list_missions as db_list_missions, list_mission_rsvps,
    update_mission as db_update_mission,
    delete_mission as db_delete_mission,
    get_profile,
)


def _is_expired(mission):
    """A mission is expired 1 hour after its end_time."""
    end_time_str = mission.get('end_time')
    if not end_time_str:
        return False
    try:
        end = datetime.datetime.fromisoformat(end_time_str.replace('Z', '+00:00'))
        now = datetime.datetime.utcnow().replace(tzinfo=end.tzinfo)
        return now > end + datetime.timedelta(hours=1)
    except (ValueError, AttributeError):
        return False


def create_mission(data, creator_id):
    mission = db_create_mission(data, creator_id)
    return mission, None


def get_single_mission(mission_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"
    return mission, None


def update_mission(mission_id, data, user_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"
    if mission['creator_id'] != int(user_id):
        return None, "Only the creator can update this mission"
    updated = db_update_mission(mission_id, data)
    return updated, None


def delete_mission(mission_id, user_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"
    if mission['creator_id'] != int(user_id):
        return None, "Only the creator can delete this mission"
    db_delete_mission(mission_id)
    return {"message": "Mission deleted successfully"}, None


def rsvp_mission(mission_id, user_id, rsvp_type='hard'):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"

    if _is_expired(mission):
        return None, "This mission has expired"

    existing = get_mission_rsvp(mission_id, user_id)
    if existing:
        return None, "Already RSVPed to this mission"

    # Capacity check for hard RSVP
    max_p = mission.get('max_participants', 0)
    if rsvp_type == 'hard' and max_p > 0:
        if mission.get('hard_rsvp_count', 0) >= max_p:
            return None, "Mission is at full capacity"

    add_mission_rsvp(mission_id, user_id, rsvp_type)
    update_mission_rsvp_count(mission_id, rsvp_type, 1)
    return {"message": "RSVPed to mission successfully"}, None


def leave_mission(mission_id, user_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"

    existing = get_mission_rsvp(mission_id, user_id)
    if not existing:
        return None, "Not RSVPed to this mission"

    rsvp_type = remove_mission_rsvp(mission_id, user_id)
    if rsvp_type:
        update_mission_rsvp_count(mission_id, rsvp_type, -1)
    return {"message": "Left mission successfully"}, None


def list_missions(filters=None):
    missions = db_list_missions(filters)
    # Filter out expired missions
    active = [m for m in missions if not _is_expired(m)]
    return active, None


def get_my_missions(user_id):
    """Get missions the user created or RSVPed to."""
    all_missions = db_list_missions()
    created = [m for m in all_missions if m.get('creator_id') == int(user_id)]

    # Find missions user RSVPed to
    rsvped_ids = set()
    for m in all_missions:
        rsvp = get_mission_rsvp(m['id'], user_id)
        if rsvp:
            rsvped_ids.add(m['id'])

    rsvped = [m for m in all_missions if m['id'] in rsvped_ids and m.get('creator_id') != int(user_id)]

    combined = created + rsvped
    # Filter out expired
    active = [m for m in combined if not _is_expired(m)]
    return active, None


def get_participants(mission_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"

    rsvps = list_mission_rsvps(mission_id)
    participants = []
    for rsvp in rsvps:
        profile = get_profile(rsvp['user_id'])
        participants.append({
            'user_id': rsvp['user_id'],
            'rsvp_type': rsvp.get('rsvp_type', 'hard'),
            'rsvped_at': rsvp.get('rsvped_at'),
            'profile': profile,
        })
    return participants, None
