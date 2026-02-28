from OrbitServer.models.models import (
    create_mission, get_mission, delete_mission,
    list_missions_for_user, update_mission_status,
    transactional_mission_rsvp, list_all_missions,
)


def create_new_mission(data, creator_id):
    """Create and persist an activity-request mission. Returns (mission, None)."""
    mission = create_mission(data, creator_id)
    return mission, None


def get_all_missions():
    """Return all missions, newest first (for discover feed). Returns (list, None)."""
    missions = list_all_missions()
    return missions, None


def get_user_missions(user_id):
    """Return all missions posted by a user, newest first. Returns (list, None)."""
    missions = list_missions_for_user(user_id)
    return missions, None


def remove_mission(mission_id, user_id):
    """
    Delete a mission if the requesting user owns it.
    Returns (success, error_message, status_code).
    status_code is None on success.
    """
    mission = get_mission(mission_id)
    if not mission:
        return False, "Mission not found", 404
    if mission.get('creator_id') != int(user_id):
        return False, "Only the creator can delete this mission", 403
    delete_mission(mission_id)
    return True, None, None


def rsvp_mission(mission_id, user_id):
    """RSVP to a signal. Returns (mission_dict, error_string)."""
    return transactional_mission_rsvp(mission_id, user_id)


def discover_missions(limit=20, cursor_token=None, category=None, exclude_user_id=None):
    """Return paginated missions for the discover feed.

    Returns (list, next_cursor_or_None).
    """
    return list_all_missions(
        limit=limit,
        cursor_token=cursor_token,
        category=category,
        exclude_user_id=exclude_user_id,
    )
