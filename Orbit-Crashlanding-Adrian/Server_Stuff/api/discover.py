from flask import Blueprint, g

from utils.responses import success, error
from utils.auth import require_auth
from services.matching_service import (
    suggested_users,
    suggested_crews,
    suggested_missions,
)

discover_bp = Blueprint('discover', __name__, url_prefix='/api/discover')


@discover_bp.route('/users', methods=['GET'])
@require_auth
def discover_users():
    users = suggested_users(g.user_id)
    return success(users)


@discover_bp.route('/crews', methods=['GET'])
@require_auth
def discover_crews():
    crews = suggested_crews(g.user_id)
    return success(crews)


@discover_bp.route('/missions', methods=['GET'])
@require_auth
def discover_missions():
    missions = suggested_missions(g.user_id)
    return success(missions)
