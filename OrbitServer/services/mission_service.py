import logging
import threading

from OrbitServer.models.models import (
    create_mission, get_mission, update_mission, delete_mission,
    list_missions, get_user, store_mission_embedding,
)
from OrbitServer.services.ai_suggestion_service import score_mission_for_user
from OrbitServer.services.embedding_service import invalidate_cache, get_or_create_mission_embedding

logger = logging.getLogger(__name__)


def get_missions_for_user(user_id, filters=None):
    """Return all open missions, scored by relevance for the user. Returns (list, error)."""
    try:
        missions = list_missions(filters={'status': 'open', **(filters or {})})
    except Exception as e:
        logger.exception("Failed to list missions")
        return [], str(e)

    user = get_user(user_id) or {}
    user_interests = set(user.get('interests') or [])

    for mission in missions:
        mission['match_score'] = score_mission_for_user(mission, user_interests)

    missions.sort(key=lambda m: m.get('match_score', 0), reverse=True)
    return missions, None


def create_new_mission(data, creator_id, creator_type='user'):
    return create_mission(data, creator_id, creator_type)


def get_mission_detail(mission_id):
    return get_mission(mission_id)


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
