from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.models.models import get_pod, update_pod
from OrbitServer.services.pod_service import (
    get_pod_with_members, vote_to_kick, confirm_attendance, leave_pod,
)
from OrbitServer.services.schedule_service import submit_availability, confirm_slot
from OrbitServer.services.pod_invite_service import (
    send_pod_invite, accept_pod_invite, decline_pod_invite, get_incoming_invites,
)
from OrbitServer.services.survey_service import submit_survey
from OrbitServer.utils.validators import validate_schedule_slots
from OrbitServer.utils.helpers import safe_int

pods_bp = Blueprint('pods', __name__, url_prefix='/api/pods')


@pods_bp.route('/<pod_id>', methods=['GET'])
@require_auth
def get_pod_detail(pod_id):
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

    pod = get_pod(pod_id)
    if not pod:
        return error("Pod not found", 404)

    uid = safe_int(g.user_id)
    if uid not in (pod.get('member_ids') or []):
        return error("You are not a member of this pod", 403)

    updated = update_pod(pod_id, {'name': name})
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


@pods_bp.route('/<pod_id>/schedule/availability', methods=['POST'])
@require_auth
def submit_schedule_availability(pod_id):
    data = request.get_json(silent=True) or {}
    name = data.get('name', '')
    join_index = data.get('join_index', 0)
    slots = data.get('slots', [])

    valid, err = validate_schedule_slots(slots)
    if not valid:
        return error(err, 400)

    pod, err = submit_availability(pod_id, g.user_id, name, join_index, slots)
    if err:
        return error(err, 400)
    return success(pod)


@pods_bp.route('/<pod_id>/schedule/confirm', methods=['POST'])
@require_auth
def confirm_schedule_slot(pod_id):
    data = request.get_json(silent=True) or {}
    date_str = data.get('date')
    hour = data.get('hour')

    if not date_str or hour is None:
        return error("date and hour are required", 400)

    pod, err = confirm_slot(pod_id, g.user_id, date_str, hour)
    if err:
        return error(err, 400)
    return success(pod)


# ── Post-Activity Survey ────────────────────────────────────────────────────

@pods_bp.route('/<pod_id>/survey', methods=['POST'])
@require_auth
def submit_pod_survey(pod_id):
    data = request.get_json(silent=True) or {}
    enjoyment_rating = data.get('enjoyment_rating')
    added_interests = data.get('added_interests', [])
    member_votes = data.get('member_votes', {})

    if enjoyment_rating is None:
        return error("enjoyment_rating is required", 400)

    result, err = submit_survey(g.user_id, pod_id, enjoyment_rating, added_interests, member_votes)
    if err:
        status_code = 409 if "already submitted" in err.lower() else 400
        if "not found" in err.lower():
            status_code = 404
        elif "not a member" in err.lower():
            status_code = 403
        return error(err, status_code)
    return success(result)


@pods_bp.route('/<pod_id>/survey/status', methods=['GET'])
@require_auth
def survey_status(pod_id):
    from OrbitServer.models.models import get_user_survey_for_pod
    existing = get_user_survey_for_pod(g.user_id, pod_id)
    return success({'submitted': existing is not None})


# ── Pod Invites ──────────────────────────────────────────────────────────────

@pods_bp.route('/<pod_id>/invite', methods=['POST'])
@require_auth
def invite_to_pod(pod_id):
    data = request.get_json(silent=True) or {}
    to_user_id = data.get('to_user_id')
    if to_user_id is None:
        return error("to_user_id is required", 400)
    invite, err, status_code = send_pod_invite(pod_id, g.user_id, int(to_user_id))
    if err:
        return error(err, status_code)
    return success(invite)


@pods_bp.route('/invites/incoming', methods=['GET'])
@require_auth
def incoming_invites():
    data, err = get_incoming_invites(g.user_id)
    if err:
        return error(err, 500)
    return success(data)


@pods_bp.route('/invites/<int:invite_id>/accept', methods=['POST'])
@require_auth
def accept_invite(invite_id):
    pod, err, status_code = accept_pod_invite(invite_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(pod)


@pods_bp.route('/invites/<int:invite_id>/decline', methods=['POST'])
@require_auth
def decline_invite(invite_id):
    result, err, status_code = decline_pod_invite(invite_id, g.user_id)
    if err:
        return error(err, status_code)
    return success(result)
