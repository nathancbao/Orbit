from flask import Blueprint, request

from utils.responses import success, error
from utils.validators import validate_edu_email
from services.auth_service import (
    send_verification_code,
    verify_code,
    refresh_access_token,
    logout,
)

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')


@auth_bp.route('/send-code', methods=['POST'])
def send_code():
    data = request.get_json(silent=True) or {}
    email = data.get('email', '')

    valid, result = validate_edu_email(email)
    if not valid:
        return error(result, 400)

    email = result  # cleaned email
    try:
        send_verification_code(email)
    except Exception as e:
        return error(f"Failed to send verification code: {str(e)}", 500)

    return success({"message": "Verification code sent"})


@auth_bp.route('/verify-code', methods=['POST'])
def verify():
    data = request.get_json(silent=True) or {}
    email = data.get('email', '')
    code = data.get('code', '')

    if not email or not code:
        return error("Email and code are required", 400)

    tokens, err = verify_code(email.strip().lower(), str(code).strip())
    if err:
        return error(err, 400)

    return success(tokens)


@auth_bp.route('/refresh', methods=['POST'])
def refresh():
    data = request.get_json(silent=True) or {}
    refresh_token = data.get('refresh_token', '')

    if not refresh_token:
        return error("refresh_token is required", 400)

    result, err = refresh_access_token(refresh_token)
    if err:
        return error(err, 401)

    return success(result)


@auth_bp.route('/logout', methods=['POST'])
def logout_route():
    data = request.get_json(silent=True) or {}
    refresh_token = data.get('refresh_token', '')

    if not refresh_token:
        return error("refresh_token is required", 400)

    logout(refresh_token)
    return success({"message": "Logged out successfully"})
