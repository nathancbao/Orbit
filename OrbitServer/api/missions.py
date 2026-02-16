from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.validators import validate_mission_data
from OrbitServer.services.mission_service import (
    create_mission,
    rsvp_mission,
    leave_mission,
    list_missions,
    get_single_mission,
    update_mission,
    delete_mission,
    get_my_missions,
    get_participants,
)

missions_bp = Blueprint('missions', __name__, url_prefix='/api/missions')


@missions_bp.route('/', methods=['POST'])
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_mission_data(data)
    if not valid:
        return error(errors, 400)

    mission, err = create_mission(data, g.user_id)
    if err:
        return error(err, 500)
    return success(mission, 201)


@missions_bp.route('/', methods=['GET'])
def list_all():
    filters = {}
    tag = request.args.get('tag')
    if tag:
        filters['tag'] = tag

    missions, err = list_missions(filters if filters else None)
    if err:
        return error(err, 500)
    return success(missions)


@missions_bp.route('/mine', methods=['GET'])
@require_auth
def mine():
    missions, err = get_my_missions(g.user_id)
    if err:
        return error(err, 500)
    return success(missions)


@missions_bp.route('/<mission_id>', methods=['GET'])
def get_one(mission_id):
    mission, err = get_single_mission(mission_id)
    if err:
        return error(err, 404)
    return success(mission)


@missions_bp.route('/<mission_id>', methods=['PUT'])
@require_auth
def update(mission_id):
    data = request.get_json(silent=True) or {}

    valid, errors = validate_mission_data(data, is_update=True)
    if not valid:
        return error(errors, 400)

    mission, err = update_mission(mission_id, data, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success(mission)


@missions_bp.route('/<mission_id>', methods=['DELETE'])
@require_auth
def delete(mission_id):
    result, err = delete_mission(mission_id, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success(result)


@missions_bp.route('/<mission_id>/rsvp', methods=['POST'])
@require_auth
def rsvp(mission_id):
    data = request.get_json(silent=True) or {}
    rsvp_type = data.get('rsvp_type', 'hard')
    if rsvp_type not in ('hard', 'soft'):
        return error("rsvp_type must be 'hard' or 'soft'", 400)

    result, err = rsvp_mission(mission_id, g.user_id, rsvp_type)
    if err:
        return error(err, 400)
    return success(result)


@missions_bp.route('/<mission_id>/rsvp', methods=['DELETE'])
@require_auth
def leave(mission_id):
    result, err = leave_mission(mission_id, g.user_id)
    if err:
        return error(err, 400)
    return success(result)


@missions_bp.route('/<mission_id>/participants', methods=['GET'])
def participants(mission_id):
    result, err = get_participants(mission_id)
    if err:
        return error(err, 404)
    return success(result)
