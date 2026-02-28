from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.rate_limit import limiter
from OrbitServer.utils.validators import validate_mission_data
from OrbitServer.services.mission_service import (
    create_new_mission, get_user_missions, get_all_missions,
    remove_mission, rsvp_mission,
)

missions_bp = Blueprint('missions', __name__, url_prefix='/api/missions')


# ── GET /missions ─────────────────────────────────────────────────────────────
# Returns all missions created by the authenticated user.
# Maps to: MissionsViewModel.loadMissions()

@missions_bp.route('', methods=['GET'])
@require_auth
def list_missions():
    missions, err = get_user_missions(g.user_id)
    if err:
        return error(err, 500)
    return success(missions)


# ── GET /missions/discover ────────────────────────────────────────────────────
# Returns all missions (discover feed for all users).

@missions_bp.route('/discover', methods=['GET'])
@require_auth
def discover():
    missions, err = get_all_missions()
    if err:
        return error(err, 500)
    return success(missions)


# ── POST /missions ────────────────────────────────────────────────────────────
# Create a new activity-request mission.
# Swift body (snake_case):
#   activity_category, custom_activity_name?, min_group_size, max_group_size,
#   availability: [{"date": "<ISO8601>", "time_blocks": ["morning", ...]}],
#   description?
#
# Swift AvailabilitySlot has CodingKeys mapping timeBlocks ↔ "time_blocks".

@missions_bp.route('', methods=['POST'])
@limiter.limit("10 per minute")
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_mission_data(data)
    if not valid:
        return error(errors, 400)

    mission, err = create_new_mission(data, g.user_id)
    if err:
        return error(err, 500)
    return success(mission, 201)


# ── DELETE /missions/<id> ─────────────────────────────────────────────────────
# Delete a mission. Only the creator can delete.
# Maps to: MissionsViewModel.deleteMission(id:) (currently client-side only)

@missions_bp.route('/<mission_id>', methods=['DELETE'])
@require_auth
def delete(mission_id):
    result, err, status_code = remove_mission(mission_id, g.user_id)
    if err:
        return error(err, status_code)
    return success({"message": "Mission deleted"})


# ── POST /missions/<id>/rsvp ─────────────────────────────────────────────────
# "I'm Down" — add the authenticated user to the mission's rsvps list.

@missions_bp.route('/<mission_id>/rsvp', methods=['POST'])
@require_auth
def rsvp(mission_id):
    mission, err = rsvp_mission(mission_id, g.user_id)
    if err:
        status_code = 404 if "not found" in err.lower() else 409
        return error(err, status_code)
    return success(mission)
