from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.services.chat_service import (
    get_dm_messages, send_dm_message, get_dm_conversations,
)

dm_bp = Blueprint('dm', __name__, url_prefix='/api/dm')


@dm_bp.route('/conversations', methods=['GET'])
@require_auth
def conversations():
    data, err = get_dm_conversations(g.user_id)
    if err:
        return error(err, 500)
    return success(data)


@dm_bp.route('/<int:friend_id>/messages', methods=['GET'])
@require_auth
def messages(friend_id):
    data, err = get_dm_messages(g.user_id, friend_id)
    if err:
        return error(err, 403)
    return success(data)


@dm_bp.route('/<int:friend_id>/messages', methods=['POST'])
@require_auth
def send(friend_id):
    body = request.get_json(silent=True) or {}
    content = (body.get('content') or '').strip()
    if not content:
        return error("content is required", 400)
    if len(content) > 2000:
        return error("message too long", 400)
    msg, err = send_dm_message(g.user_id, friend_id, content)
    if err:
        return error(err, 403)
    return success(msg)
