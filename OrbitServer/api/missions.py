from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.validators import validate_mission_data
from OrbitServer.services.mission_service import (
    create_mission,
    rsvp_mission,
    list_missions,
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


@missions_bp.route('/<mission_id>/rsvp', methods=['POST'])
@require_auth
def rsvp(mission_id):
    result, err = rsvp_mission(mission_id, g.user_id)
    if err:
        return error(err, 400)
    return success(result)
