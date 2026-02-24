from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.validators import validate_mission_data
from OrbitServer.services.mission_service import (
    create_new_mission, get_user_missions, remove_mission,
)

missions_bp = Blueprint('missions', __name__, url_prefix='/api/missions')


# ── GET /missions ─────────────────────────────────────────────────────────────
# Returns all missions created by the authenticated user.
# Maps to: MissionsViewModel.loadMissions() (currently mocked — future use)

@missions_bp.route('', methods=['GET'])
@require_auth
def list_missions():
    missions, err = get_user_missions(g.user_id)
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
# NOTE: When Swift AvailabilitySlot is wired to this API, add CodingKeys:
#   "time_blocks" → timeBlocks  (currently no CodingKeys on AvailabilitySlot)

@missions_bp.route('', methods=['POST'])
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
    result, err = remove_mission(mission_id, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success({"message": "Mission deleted"})
