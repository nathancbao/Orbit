import threading

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
from OrbitServer.services.embedding_service import get_or_create_event_embedding
from OrbitServer.models.models import (
    list_event_pods, get_user_pod_for_event, record_event_action,
)

events_bp = Blueprint('events', __name__, url_prefix='/api/events')


def _to_str_id(event):
    """
    Return a copy of the event dict safe for the Swift client:
      - 'id' coerced to str  (Swift Mission.id: String)
      - 'embedding' stripped (512-float vector the client never needs;
        stripping also sidesteps any numpy-float serialization edge cases)
    """
    if event is None:
        return None
    d = {**event, 'id': str(event['id'])}
    d.pop('embedding', None)
    return d


def _annotate_pod_status(event, user_id):
    """
    Mutate *event* in-place with user_pod_status / user_pod_id fields.

    user_pod_status is one of:
        "in_pod"    – user already joined a pod for this event
        "not_joined" – user hasn't joined yet and at least one open pod has room
        "pod_full"   – every pod is full or no pods exist with room
    """
    event_id = event['id']
    user_pod = get_user_pod_for_event(event_id, user_id)
    if user_pod:
        event['user_pod_status'] = 'in_pod'
        event['user_pod_id'] = user_pod['id']
        return

    pods = list_event_pods(event_id)
    has_room = not pods or any(
        p['status'] == 'open' and len(p.get('member_ids') or []) < p.get('max_size', 4)
        for p in pods
    )
    event['user_pod_status'] = 'not_joined' if has_room else 'pod_full'
    event['user_pod_id'] = None


# ── GET /events ───────────────────────────────────────────────────────────────

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

    for event in events:
        _annotate_pod_status(event, g.user_id)

    return success([_to_str_id(e) for e in events])


# ── GET /events/suggested ────────────────────────────────────────────────────

@events_bp.route('/suggested', methods=['GET'])
@require_auth
def suggested():
    limit = min(int(request.args.get('limit', 5)), 10)
    events = get_suggested_events(g.user_id, limit=limit)

    for event in events:
        _annotate_pod_status(event, g.user_id)

    return success([_to_str_id(e) for e in events])


# ── POST /events ──────────────────────────────────────────────────────────────

@events_bp.route('', methods=['POST'])
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_event_data(data)
    if not valid:
        return error(errors, 400)

    event = create_new_event(data, g.user_id, creator_type='user')

    # Generate embedding asynchronously so the HTTP response isn't blocked.
    # If this fails, lazy generation will retry on the first recommendation request.
    event_id = event['id']
    def _generate_embedding():
        try:
            get_or_create_event_embedding(event_id)
        except Exception:
            pass
    threading.Thread(target=_generate_embedding, daemon=True).start()

    return success(_to_str_id(event), 201)


# ── GET /events/<id> ─────────────────────────────────────────────────────────

@events_bp.route('/<int:event_id>', methods=['GET'])
@require_auth
def get_one(event_id):
    event = get_event_detail(event_id)
    if not event:
        return error("Event not found", 404)

    # Attach pod summaries (matches Swift Event.pods: [PodSummary]?)
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

    # Annotate user-specific pod status (was missing in original GET /events/<id>)
    _annotate_pod_status(event, g.user_id)

    return success(_to_str_id(event))


# ── PUT /events/<id> ─────────────────────────────────────────────────────────

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
    return success(_to_str_id(event))


# ── DELETE /events/<id> ───────────────────────────────────────────────────────

@events_bp.route('/<int:event_id>', methods=['DELETE'])
@require_auth
def delete(event_id):
    result, err = remove_event(event_id, g.user_id)
    if err:
        status = 404 if "not found" in err.lower() else 403
        return error(err, status)
    return success({"message": "Event deleted successfully"})


# ── POST /events/<id>/join ────────────────────────────────────────────────────

@events_bp.route('/<int:event_id>/join', methods=['POST'])
@require_auth
def join(event_id):
    pod, err = join_event(event_id, g.user_id)
    if err:
        return error(err, 400)
    return success(pod, 201)


# ── DELETE /events/<id>/leave ─────────────────────────────────────────────────

@events_bp.route('/<int:event_id>/leave', methods=['DELETE'])
@require_auth
def leave(event_id):
    result, err = leave_event(event_id, g.user_id)
    if err:
        return error(err, 400)
    return success({"message": "Left event pod successfully"})


# ── POST /events/<id>/skip ────────────────────────────────────────────────────

@events_bp.route('/<int:event_id>/skip', methods=['POST'])
@require_auth
def skip(event_id):
    event = get_event_detail(event_id)
    if not event:
        return error("Event not found", 404)
    record_event_action(g.user_id, event_id, 'skipped',
                        tags_snapshot=event.get('tags') or [])
    return success({"message": "Event skipped"})
