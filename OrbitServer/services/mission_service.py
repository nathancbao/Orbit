from OrbitServer.models.models import (
    create_mission as db_create_mission,
    get_mission, get_mission_rsvp, add_mission_rsvp,
    update_mission_rsvp_count,
    list_missions as db_list_missions,
)


def create_mission(data, creator_id):
    mission = db_create_mission(data, creator_id)
    return mission, None


def rsvp_mission(mission_id, user_id):
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"

    existing = get_mission_rsvp(mission_id, user_id)
    if existing:
        return None, "Already RSVPed to this mission"

    add_mission_rsvp(mission_id, user_id)
    update_mission_rsvp_count(mission_id, 1)
    return {"message": "RSVPed to mission successfully"}, None


def list_missions(filters=None):
    missions = db_list_missions(filters)
    return missions, None
