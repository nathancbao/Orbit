from OrbitServer.models.models import (
    create_crew as db_create_crew,
    get_crew, get_crew_member, add_crew_member,
    remove_crew_member, update_crew_member_count,
    list_crews as db_list_crews,
)


def create_crew(data, creator_id):
    crew = db_create_crew(data, creator_id)
    return crew, None


def join_crew(crew_id, user_id):
    crew = get_crew(crew_id)
    if not crew:
        return None, "Crew not found"

    existing = get_crew_member(crew_id, user_id)
    if existing:
        return None, "Already a member of this crew"

    add_crew_member(crew_id, user_id)
    update_crew_member_count(crew_id, 1)
    return {"message": "Joined crew successfully"}, None


def leave_crew(crew_id, user_id):
    crew = get_crew(crew_id)
    if not crew:
        return None, "Crew not found"

    existing = get_crew_member(crew_id, user_id)
    if not existing:
        return None, "Not a member of this crew"

    remove_crew_member(crew_id, user_id)
    update_crew_member_count(crew_id, -1)
    return {"message": "Left crew successfully"}, None


def list_crews(filters=None):
    crews = db_list_crews(filters)
    return crews, None
