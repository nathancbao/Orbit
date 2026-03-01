from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.models.models import get_event_pod, update_event_pod
from OrbitServer.services.pod_service import (
    get_pod_with_members, vote_to_kick, confirm_attendance, leave_pod,
)
from OrbitServer.utils.helpers import safe_int

pods_bp = Blueprint('pods', __name__, url_prefix='/api/pods')


@pods_bp.route('/<pod_id>', methods=['GET'])
@require_auth
def get_pod(pod_id):
    pod, err, status_code = get_pod_with_members(pod_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(pod)


@pods_bp.route('/<pod_id>/name', methods=['PUT'])
@require_auth
def rename(pod_id):
    data = request.get_json(silent=True) or {}
    name = data.get('name', '').strip()
    if not name:
        return error("name is required", 400)
    if len(name) > 100:
        return error("name must be 100 characters or fewer", 400)

    pod = get_event_pod(pod_id)
    if not pod:
        return error("Pod not found", 404)

    uid = safe_int(g.user_id)
    if uid not in (pod.get('member_ids') or []):
        return error("You are not a member of this pod", 403)

    updated = update_event_pod(pod_id, {'name': name})
    return success(updated)


@pods_bp.route('/<pod_id>/leave', methods=['DELETE'])
@require_auth
def leave(pod_id):
    ok, err = leave_pod(pod_id, g.user_id)
    if not ok:
        msg, status_code = err
        return error(msg, status_code)
    return success({'message': 'You have left the pod'})


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
