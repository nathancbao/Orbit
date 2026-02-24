from OrbitServer.models.models import (
    create_mission, get_mission, delete_mission,
    list_missions_for_user, update_mission_status,
)


def create_new_mission(data, creator_id):
    """Create and persist an activity-request mission. Returns (mission, None)."""
    mission = create_mission(data, creator_id)
    return mission, None


def get_user_missions(user_id):
    """Return all missions posted by a user, newest first. Returns (list, None)."""
    missions = list_missions_for_user(user_id)
    return missions, None


def remove_mission(mission_id, user_id):
    """
    Delete a mission if the requesting user owns it.
    Returns (True, None) or (False, error_string).
    """
    mission = get_mission(mission_id)
    if not mission:
        return False, "Mission not found"
    if mission.get('creator_id') != int(user_id):
        return False, "Only the creator can delete this mission"
    delete_mission(mission_id)
    return True, None
