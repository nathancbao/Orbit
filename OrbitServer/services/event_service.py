import threading

from OrbitServer.models.models import (
    create_event, get_event, update_event, delete_event,
    list_events, get_profile, store_event_embedding,
)
from OrbitServer.services.ai_suggestion_service import score_event_for_user
from OrbitServer.services.embedding_service import invalidate_cache, get_or_create_event_embedding


def get_events_for_user(user_id, filters=None):
    """Return all open events, scored by relevance for the user."""
    events = list_events(filters={'status': 'open', **(filters or {})})
    profile = get_profile(user_id) or {}
    user_interests = set(profile.get('interests') or [])
    user_year = profile.get('college_year', '')

    # Optionally filter by college year
    if filters and filters.get('year'):
        # Keep events without year restriction and events that include this year
        # (no year field on events yet, so this is a no-op placeholder)
        pass

    for event in events:
        event['match_score'] = score_event_for_user(event, user_interests)

    events.sort(key=lambda e: e.get('match_score', 0), reverse=True)
    return events


def create_new_event(data, creator_id, creator_type='user'):
    return create_event(data, creator_id, creator_type)


def get_event_detail(event_id):
    return get_event(event_id)


def edit_event(event_id, data, user_id):
    event = get_event(event_id)
    if not event:
        return None, "Event not found"
    if event['creator_id'] != int(user_id):
        return None, "Only the creator can edit this event"
    updated = update_event(event_id, data)

    # If content fields changed, invalidate cached embedding and regenerate
    content_fields = {'title', 'description', 'tags'}
    if content_fields & set(data.keys()):
        invalidate_cache(event_id)
        store_event_embedding(event_id, None)  # clear stale Datastore embedding
        def _regenerate():
            try:
                get_or_create_event_embedding(event_id)
            except Exception:
                pass
        threading.Thread(target=_regenerate, daemon=True).start()

    return updated, None


def remove_event(event_id, user_id):
    event = get_event(event_id)
    if not event:
        return False, "Event not found"
    if event['creator_id'] != int(user_id):
        return False, "Only the creator can delete this event"
    delete_event(event_id)
    return True, None
