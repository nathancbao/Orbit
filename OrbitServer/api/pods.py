from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.services.pod_service import (
    get_pod_with_members, vote_to_kick, confirm_attendance,
)

pods_bp = Blueprint('pods', __name__, url_prefix='/api/pods')


@pods_bp.route('/<pod_id>', methods=['GET'])
@require_auth
def get_pod(pod_id):
    pod, err, status_code = get_pod_with_members(pod_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(pod)


@pods_bp.route('/<pod_id>/kick', methods=['POST'])
@require_auth
def kick(pod_id):
    data = request.get_json(silent=True) or {}
    target_user_id = data.get('target_user_id')
    if not target_user_id:
        return error("target_user_id is required", 400)

    pod, kicked, err, status_code = vote_to_kick(pod_id, g.user_id, target_user_id)
    if err:
        return error(err, status_code)
    return success({
        'pod': pod,
        'kicked': kicked,
        'message': "Kick vote recorded" if not kicked else "User kicked from pod",
    })


@pods_bp.route('/<pod_id>/confirm-attendance', methods=['POST'])
@require_auth
def confirm(pod_id):
    pod, err, status_code = confirm_attendance(pod_id, g.user_id)
    if err:
        return error(err, status_code)
    return success({'pod': pod, 'message': "Attendance confirmed! Points awarded."})
