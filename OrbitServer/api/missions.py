import logging
import threading

from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.utils.validators import validate_mission_data
from OrbitServer.services.mission_service import (
    get_missions_for_user, create_new_mission, get_mission_detail,
    edit_mission, remove_mission, check_mission_expiration,
)
from OrbitServer.services.pod_service import join_mission, leave_mission
from OrbitServer.services.ai_suggestion_service import get_suggested_missions
from OrbitServer.services.embedding_service import get_or_create_mission_embedding
from OrbitServer.models.models import (
    list_pods, get_user_pod_for_mission, record_action,
)

logger = logging.getLogger(__name__)

missions_bp = Blueprint('missions', __name__, url_prefix='/api/missions')


def _strip_embedding(mission):
    """Strip the embedding vector from a mission dict -- the client never needs it."""
    if mission is None:
        return None
    d = dict(mission)
    d.pop('embedding', None)
    return d


def _annotate_pod_status(mission, user_id):
    """
    Mutate *mission* in-place with user_pod_status / user_pod_id fields.

    user_pod_status is one of:
        "in_pod"     -- user already joined a pod for this mission
        "not_joined" -- user hasn't joined yet and at least one open pod has room
        "pod_full"   -- every pod is full or no pods exist with room
    """
    try:
        mission_id = mission['id']
        user_pod = get_user_pod_for_mission(mission_id, user_id)
        if user_pod:
            mission['user_pod_status'] = 'in_pod'
            mission['user_pod_id'] = user_pod['id']
            return

        # Always allow joining — the backend creates a new pod when all are full.
        mission['user_pod_status'] = 'not_joined'
        mission['user_pod_id'] = None
    except Exception:
        logger.exception("Failed to annotate pod status for mission %s", mission.get('id'))
        mission['user_pod_status'] = 'not_joined'
        mission['user_pod_id'] = None


def _annotate_pod_status_batch(missions, user_id):
    """Annotate pod status for a list of missions using batched pod queries.

    Fetches all user pods once, then does per-mission lookups only for
    missions the user hasn't joined. Much faster than per-mission _annotate_pod_status.
    """
    from OrbitServer.models.models import get_user_pods as _get_user_pods
    try:
        user_pods = _get_user_pods(user_id)
        # Build {mission_id: pod_id} map from user's pods
        user_pod_map = {}
        for pod in user_pods:
            mid = pod.get('mission_id')
            if mid is not None:
                user_pod_map[str(mid)] = pod['id']
    except Exception:
        logger.exception("Failed to batch-fetch user pods")
        user_pod_map = {}

    for mission in missions:
        mid = mission['id']
        if str(mid) in user_pod_map:
            mission['user_pod_status'] = 'in_pod'
            mission['user_pod_id'] = user_pod_map[str(mid)]
        else:
            mission['user_pod_status'] = 'not_joined'
            mission['user_pod_id'] = None


# ── GET /missions ────────────────────────────────────────────────────────────

@missions_bp.route('', methods=['GET'])
@require_auth
def list_all():
    filters = {}
    tag = request.args.get('tag')
    year = request.args.get('year')
    if tag:
        filters['tag'] = tag
    if year:
        filters['year'] = year

    missions, err = get_missions_for_user(g.user_id, filters if filters else None)
    if err:
        return error(err, 500)

    _annotate_pod_status_batch(missions, g.user_id)

    return success([_strip_embedding(m) for m in missions])


# ── GET /missions/suggested ─────────────────────────────────────────────────

@missions_bp.route('/suggested', methods=['GET'])
@require_auth
def suggested():
    try:
        limit = min(int(request.args.get('limit', 5)), 10)
    except (TypeError, ValueError):
        limit = 5
    try:
        missions = get_suggested_missions(g.user_id, limit=limit)
    except Exception:
        logger.exception("Failed to get suggested missions")
        return success([])

    # Check expiration server-side and filter out deleted missions
    missions = [m for m in missions if check_mission_expiration(m) != 'deleted']

    # Annotate pod status — only for set missions; flex missions use RSVPs instead
    set_missions = [m for m in missions if m.get('mode') != 'flex']
    flex_missions = [m for m in missions if m.get('mode') == 'flex']
    _annotate_pod_status_batch(set_missions, g.user_id)
    for m in flex_missions:
        m['user_pod_status'] = 'not_joined'
        m['user_pod_id'] = None

    return success([_strip_embedding(m) for m in missions])


# ── POST /missions ───────────────────────────────────────────────────────────

@missions_bp.route('', methods=['POST'])
@require_auth
def create():
    data = request.get_json(silent=True) or {}

    valid, errors = validate_mission_data(data)
    if not valid:
        return error(errors, 400)

    mission = create_new_mission(data, g.user_id, creator_type='user')

    # Generate embedding asynchronously so the HTTP response isn't blocked.
    mission_id = mission['id']
    def _generate_embedding():
        try:
            get_or_create_mission_embedding(mission_id)
        except Exception:
            pass
    threading.Thread(target=_generate_embedding, daemon=True).start()

    return success(_strip_embedding(mission), 201)


# ── GET /missions/<id> ──────────────────────────────────────────────────────

@missions_bp.route('/<mission_id>', methods=['GET'])
@require_auth
def get_one(mission_id):
    mission = get_mission_detail(mission_id)
    if not mission:
        return error("Mission not found", 404)

    # Attach pod summaries
    pods = list_pods(mission_id)
    pod_summaries = []
    for pod in pods:
        members = pod.get('member_ids') or []
        pod_summaries.append({
            'pod_id': pod['id'],
            'member_count': len(members),
            'max_size': pod.get('max_size', 4),
            'status': pod.get('status'),
        })
    mission['pods'] = pod_summaries

    _annotate_pod_status(mission, g.user_id)

    return success(_strip_embedding(mission))


# ── PUT /missions/<id> ──────────────────────────────────────────────────────

@missions_bp.route('/<mission_id>', methods=['PUT'])
@require_auth
def update(mission_id):
    data = request.get_json(silent=True) or {}

    valid, errors = validate_mission_data(data, is_update=True)
    if not valid:
        return error(errors, 400)

    mission, err, status_code = edit_mission(mission_id, data, g.user_id)
    if err:
        return error(err, status_code)
    return success(_strip_embedding(mission))


# ── DELETE /missions/<id> ────────────────────────────────────────────────────

@missions_bp.route('/<mission_id>', methods=['DELETE'])
@require_auth
def delete(mission_id):
    result, err, status_code = remove_mission(mission_id, g.user_id)
    if err:
        return error(err, status_code)
    return success({"message": "Mission deleted successfully"})


# ── POST /missions/<id>/join ─────────────────────────────────────────────────

@missions_bp.route('/<mission_id>/join', methods=['POST'])
@require_auth
def join(mission_id):
    data = request.get_json(silent=True) or {}
    preferred_pod_id = data.get('pod_id')
    pod, err = join_mission(mission_id, g.user_id, preferred_pod_id=preferred_pod_id)
    if err:
        return error(err, 400)
    return success(pod, 201)


# ── DELETE /missions/<id>/leave ──────────────────────────────────────────────

@missions_bp.route('/<mission_id>/leave', methods=['DELETE'])
@require_auth
def leave(mission_id):
    result, err = leave_mission(mission_id, g.user_id)
    if err:
        return error(err, 400)
    return success({"message": "Left mission pod successfully"})


# ── POST /missions/<id>/skip ────────────────────────────────────────────────

@missions_bp.route('/<mission_id>/skip', methods=['POST'])
@require_auth
def skip(mission_id):
    mission = get_mission_detail(mission_id)
    if not mission:
        return error("Mission not found", 404)
    record_action(g.user_id, mission_id, 'skipped',
                  tags_snapshot=mission.get('tags') or [])
    return success({"message": "Mission skipped"})
