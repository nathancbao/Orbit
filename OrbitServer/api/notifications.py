from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.models.models import (
    list_notifications, mark_notifications_read, mark_all_notifications_read,
    count_unread_notifications, save_device_token, delete_device_token,
)

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api')


@notifications_bp.route('/notifications', methods=['GET'])
@require_auth
def get_notifications():
    limit = request.args.get('limit', 50, type=int)
    limit = min(limit, 200)
    notifications = list_notifications(g.user_id, limit=limit)
    unread_count = count_unread_notifications(g.user_id)
    return success({'notifications': notifications, 'unread_count': unread_count})


@notifications_bp.route('/notifications/read', methods=['POST'])
@require_auth
def read_notifications():
    data = request.get_json(silent=True) or {}
    notification_ids = data.get('notification_ids', [])
    if not notification_ids or not isinstance(notification_ids, list):
        return error("notification_ids must be a non-empty list", 400)
    mark_notifications_read(g.user_id, notification_ids)
    return success({'message': 'Notifications marked as read'})


@notifications_bp.route('/notifications/read-all', methods=['POST'])
@require_auth
def read_all_notifications():
    mark_all_notifications_read(g.user_id)
    return success({'message': 'All notifications marked as read'})


@notifications_bp.route('/notifications/unread-count', methods=['GET'])
@require_auth
def unread_count():
    count = count_unread_notifications(g.user_id)
    return success({'unread_count': count})


@notifications_bp.route('/devices', methods=['POST'])
@require_auth
def register_device():
    data = request.get_json(silent=True) or {}
    token = data.get('token', '').strip()
    if not token:
        return error("token is required", 400)
    device = save_device_token(g.user_id, token)
    return success(device, 201)


@notifications_bp.route('/devices', methods=['DELETE'])
@require_auth
def unregister_device():
    data = request.get_json(silent=True) or {}
    token = data.get('token', '').strip()
    if not token:
        return error("token is required", 400)
    delete_device_token(token)
    return success({'message': 'Device token removed'})
