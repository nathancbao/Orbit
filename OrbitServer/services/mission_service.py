import datetime
import logging
import threading

from OrbitServer.models.models import (
    create_mission, get_mission, update_mission, delete_mission,
    list_missions, get_user, store_mission_embedding,
)
from OrbitServer.services.ai_suggestion_service import score_mission_for_user
from OrbitServer.services.embedding_service import invalidate_cache, get_or_create_mission_embedding

logger = logging.getLogger(__name__)

# How long after end time before auto-deletion
_MISSION_GRACE_PERIOD = datetime.timedelta(hours=2)


def _mission_end_datetime(mission):
    """Compute the end datetime for a set mission. Returns datetime or None."""
    date_str = mission.get('date', '')
    if not date_str:
        return None
    try:
        dt = datetime.datetime.strptime(date_str, '%Y-%m-%d')
    except (ValueError, TypeError):
        return None

    end_time = mission.get('end_time', '')
    start_time = mission.get('start_time', '')

    if end_time:
        try:
            parts = end_time.split(':')
            return dt.replace(hour=int(parts[0]), minute=int(parts[1]) if len(parts) > 1 else 0)
        except (ValueError, IndexError):
            pass

    if start_time:
        try:
            parts = start_time.split(':')
            return dt.replace(hour=int(parts[0]), minute=int(parts[1]) if len(parts) > 1 else 0) + datetime.timedelta(hours=2)
        except (ValueError, IndexError):
            pass

    # Date only — treat end of day as end time
    return dt.replace(hour=23, minute=59)


def check_mission_expiration(mission):
    """Check a mission against server time and handle expiration.

    - If past end time: updates status to 'completed' in DB.
    - If past end time + 1 hour: deletes mission entirely.

    Returns:
      'active'    — mission is still ongoing
      'completed' — mission ended, within grace period
      'deleted'   — mission was auto-deleted
      None        — no end time could be determined
    """
    if not mission or mission.get('mode') == 'flex':
        return 'active'

    if mission.get('status') in ('cancelled',):
        return mission['status']

    end_dt = _mission_end_datetime(mission)
    if not end_dt:
        return None

    now = datetime.datetime.utcnow()

    if now > end_dt + _MISSION_GRACE_PERIOD:
        # Past grace period — delete
        try:
            delete_mission(mission['id'])
        except Exception:
            logger.exception("Failed to auto-delete expired mission %s", mission.get('id'))
        return 'deleted'

    if now > end_dt:
        # Past end time but within grace period — mark completed
        if mission.get('status') != 'completed':
            try:
                update_mission(mission['id'], {'status': 'completed'})
            except Exception:
                logger.exception("Failed to mark mission %s as completed", mission.get('id'))
            mission['status'] = 'completed'
        return 'completed'

    return 'active'


def get_missions_for_user(user_id, filters=None):
    """Return all open missions, scored by relevance for the user. Returns (list, error)."""
    try:
        missions = list_missions(filters={'status': 'open', **(filters or {})})
    except Exception as e:
        logger.exception("Failed to list missions")
        return [], str(e)

    user = get_user(user_id) or {}
    user_interests = set(user.get('interests') or [])

    # Check expiration server-side and filter out deleted missions
    live = []
    for mission in missions:
        result = check_mission_expiration(mission)
        if result == 'deleted':
            continue
        mission['match_score'] = score_mission_for_user(mission, user_interests)
        live.append(mission)

    live.sort(key=lambda m: m.get('match_score', 0), reverse=True)
    return live, None


def create_new_mission(data, creator_id, creator_type='user'):
    return create_mission(data, creator_id, creator_type)


def get_mission_detail(mission_id):
    mission = get_mission(mission_id)
    if not mission:
        return None
    result = check_mission_expiration(mission)
    if result == 'deleted':
        return None
    return mission


def edit_mission(mission_id, data, user_id):
    """
    Edit a mission. Returns (mission, error_message, status_code).
    status_code is None on success.
    """
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found", 404
    if mission['creator_id'] != int(user_id):
        return None, "Only the creator can edit this mission", 403
    updated = update_mission(mission_id, data)

    # If content fields changed, invalidate cached embedding and regenerate
    content_fields = {'title', 'description', 'tags'}
    if content_fields & set(data.keys()):
        invalidate_cache(mission_id)
        store_mission_embedding(mission_id, None)  # clear stale Datastore embedding
        def _regenerate():
            try:
                get_or_create_mission_embedding(mission_id)
            except Exception:
                pass
        threading.Thread(target=_regenerate, daemon=True).start()

    return updated, None, None


def remove_mission(mission_id, user_id):
    """
    Remove a mission. Returns (success, error_message, status_code).
    status_code is None on success.
    """
    mission = get_mission(mission_id)
    if not mission:
        return False, "Mission not found", 404
    if mission['creator_id'] != int(user_id):
        return False, "Only the creator can delete this mission", 403
    delete_mission(mission_id)
    return True, None, None
