from flask import Blueprint, request, g

from utils.responses import success, error
from utils.auth import require_auth
from utils.validators import validate_profile_data
from services.user_service import get_user_profile, update_user_profile, upload_photo

users_bp = Blueprint('users', __name__, url_prefix='/api/users')


@users_bp.route('/me', methods=['GET'])
@require_auth
def get_me():
    profile, err = get_user_profile(g.user_id)
    if err:
        return error(err, 404)
    return success(profile)


@users_bp.route('/me', methods=['PUT'])
@require_auth
def update_me():
    data = request.get_json(silent=True) or {}
    if not data:
        return error("No data provided", 400)

    valid, errors = validate_profile_data(data)
    if not valid:
        return error(errors, 400)

    profile, err = update_user_profile(g.user_id, data)
    if err:
        return error(err, 500)
    return success(profile)


@users_bp.route('/me/photo', methods=['POST'])
@require_auth
def upload_me_photo():
    if 'photo' not in request.files:
        return error("No photo file provided", 400)

    file = request.files['photo']
    if file.filename == '':
        return error("No file selected", 400)

    profile, err = upload_photo(g.user_id, file)
    if err:
        return error(err, 500)
    return success(profile)


@users_bp.route('/<user_id>', methods=['GET'])
def get_user_public(user_id):
    profile, err = get_user_profile(user_id)
    if err:
        return error(err, 404)
    return success(profile)
