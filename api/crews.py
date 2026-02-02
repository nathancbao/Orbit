from flask import Blueprint, request, g

from utils.responses import success, error
from utils.auth import require_auth
from utils.validators import validate_crew_data
from services.crew_service import (
    create_crew,
    join_crew,
    leave_crew,
    list_crews,
)

crews_bp = Blueprint('crews', __name__, url_prefix='/api/crews')


@crews_bp.route('/', methods=['POST'])
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_crew_data(data)
    if not valid:
        return error(errors, 400)

    crew, err = create_crew(data, g.user_id)
    if err:
        return error(err, 500)
    return success(crew, 201)


@crews_bp.route('/', methods=['GET'])
def list_all():
    filters = {}
    tag = request.args.get('tag')
    if tag:
        filters['tag'] = tag

    crews, err = list_crews(filters if filters else None)
    if err:
        return error(err, 500)
    return success(crews)


@crews_bp.route('/<crew_id>/join', methods=['POST'])
@require_auth
def join(crew_id):
    result, err = join_crew(crew_id, g.user_id)
    if err:
        return error(err, 400)
    return success(result)


@crews_bp.route('/<crew_id>/leave', methods=['POST'])
@require_auth
def leave(crew_id):
    result, err = leave_crew(crew_id, g.user_id)
    if err:
        return error(err, 400)
    return success(result)
