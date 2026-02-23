from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.validators import validate_event_data
from OrbitServer.services.event_service import (
    get_events_for_user, create_new_event, get_event_detail,
    edit_event, remove_event,
)
from OrbitServer.services.pod_service import join_event, leave_event
from OrbitServer.services.ai_suggestion_service import get_suggested_events
from OrbitServer.models.models import (
    list_event_pods, get_user_pod_for_event, record_event_action,
)

events_bp = Blueprint('events', __name__, url_prefix='/api/events')


@events_bp.route('', methods=['GET'])
@require_auth
def list_all():
    filters = {}
    tag = request.args.get('tag')
    year = request.args.get('year')
    if tag:
        filters['tag'] = tag
    if year:
        filters['year'] = year

    events = get_events_for_user(g.user_id, filters if filters else None)

    # Annotate each event with the requesting user's pod status
    for event in events:
        pod = get_user_pod_for_event(event['id'], g.user_id)
        if pod:
            event['user_pod_status'] = 'in_pod'
            event['user_pod_id'] = pod['id']
        else:
            # Check if any open pod has room
            pods = list_event_pods(event['id'])
            max_pod_size = event.get('max_pod_size', 4)
            has_room = any(
                p['status'] == 'open' and len(p.get('member_ids') or []) < max_pod_size
                for p in pods
            )
            event['user_pod_status'] = 'not_joined' if has_room else 'pod_full'

    return success(events)


@events_bp.route('/suggested', methods=['GET'])
@require_auth
def suggested():
    limit = min(int(request.args.get('limit', 5)), 10)
    events = get_suggested_events(g.user_id, limit=limit)
    return success(events)


@events_bp.route('', methods=['POST'])
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_event_data(data)
    if not valid:
        return error(errors, 400)

    event = create_new_event(data, g.user_id, creator_type='user')
    return success(event, 201)


@events_bp.route('/<int:event_id>', methods=['GET'])
@require_auth
def get_one(event_id):
    event = get_event_detail(event_id)
    if not event:
        return error("Event not found", 404)

    # Attach pod info
    pods = list_event_pods(event_id)
    pod_summaries = []
    for pod in pods:
        members = pod.get('member_ids') or []
        pod_summaries.append({
            'pod_id': pod['id'],
            'member_count': len(members),
            'max_size': pod.get('max_size', 4),
            'status': pod.get('status'),
        })
    event['pods'] = pod_summaries

    # User's pod status
    user_pod = get_user_pod_for_event(event_id, g.user_id)
    event['user_pod_id'] = user_pod['id'] if user_pod else None

    return success(event)


@events_bp.route('/<int:event_id>', methods=['PUT'])
@require_auth
def update(event_id):
    data = request.get_json(silent=True) or {}

    valid, errors = validate_event_data(data, is_update=True)
    if not valid:
        return error(errors, 400)

    event, err = edit_event(event_id, data, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success(event)


@events_bp.route('/<int:event_id>', methods=['DELETE'])
@require_auth
def delete(event_id):
    result, err = remove_event(event_id, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success({"message": "Event deleted successfully"})


@events_bp.route('/<int:event_id>/join', methods=['POST'])
@require_auth
def join(event_id):
    pod, err = join_event(event_id, g.user_id)
    if err:
        return error(err, 400)
    return success(pod, 201)


@events_bp.route('/<int:event_id>/leave', methods=['DELETE'])
@require_auth
def leave(event_id):
    result, err = leave_event(event_id, g.user_id)
    if err:
        return error(err, 400)
    return success({"message": "Left event pod successfully"})


@events_bp.route('/<int:event_id>/skip', methods=['POST'])
@require_auth
def skip(event_id):
    event = get_event_detail(event_id)
    if not event:
        return error("Event not found", 404)
    record_event_action(g.user_id, event_id, 'skipped')
    return success({"message": "Event skipped"})
