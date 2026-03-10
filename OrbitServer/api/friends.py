from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.services.friend_service import (
    get_friends, send_friend_request,
    get_incoming_requests, get_outgoing_requests,
    accept_friend_request, decline_friend_request,
    remove_friend, get_friendship_status, search_users,
)

friends_bp = Blueprint('friends', __name__, url_prefix='/api/friends')


# ── GET /friends/search ──────────────────────────────────────────────────────

@friends_bp.route('/search', methods=['GET'])
@require_auth
def search():
    q = request.args.get('q', '').strip()
    if len(q) < 3:
        return error("Query must be at least 3 characters", 400)
    data, err = search_users(q, g.user_id)
    if err:
        return error(err, 500)
    return success(data)


# ── GET /friends ──────────────────────────────────────────────────────────────

@friends_bp.route('', methods=['GET'])
@require_auth
def list_friends():
    data, err = get_friends(g.user_id)
    if err:
        return error(err, 500)
    return success(data)


# ── POST /friends/requests ────────────────────────────────────────────────────

@friends_bp.route('/requests', methods=['POST'])
@require_auth
def create_request():
    body = request.get_json(silent=True) or {}
    to_user_id = body.get('to_user_id')
    if to_user_id is None or int(to_user_id) == 0:
        return error("to_user_id is required", 400)

    data, err = send_friend_request(g.user_id, to_user_id)
    if err:
        return error(err, 409)
    return success(data, 201)


# ── GET /friends/requests/incoming ────────────────────────────────────────────

@friends_bp.route('/requests/incoming', methods=['GET'])
@require_auth
def incoming_requests():
    data, err = get_incoming_requests(g.user_id)
    if err:
        return error(err, 500)
    return success(data)


# ── GET /friends/requests/outgoing ────────────────────────────────────────────

@friends_bp.route('/requests/outgoing', methods=['GET'])
@require_auth
def outgoing_requests():
    data, err = get_outgoing_requests(g.user_id)
    if err:
        return error(err, 500)
    return success(data)


# ── POST /friends/requests/<id>/accept ────────────────────────────────────────

@friends_bp.route('/requests/<int:request_id>/accept', methods=['POST'])
@require_auth
def accept(request_id):
    data, err, status_code = accept_friend_request(request_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(data)


# ── POST /friends/requests/<id>/decline ───────────────────────────────────────

@friends_bp.route('/requests/<int:request_id>/decline', methods=['POST'])
@require_auth
def decline(request_id):
    data, err, status_code = decline_friend_request(request_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(data)


# ── DELETE /friends/<id> ──────────────────────────────────────────────────────

@friends_bp.route('/<int:friendship_id>', methods=['DELETE'])
@require_auth
def remove(friendship_id):
    data, err, status_code = remove_friend(friendship_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(data)


# ── GET /friends/status/<user_id> ─────────────────────────────────────────────

@friends_bp.route('/status/<int:user_id>', methods=['GET'])
@require_auth
def status(user_id):
    data, err = get_friendship_status(g.user_id, user_id)
    if err:
        return error(err, 500)
    return success(data)
