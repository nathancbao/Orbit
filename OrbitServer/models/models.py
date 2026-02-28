"""Re-export hub — all existing `from OrbitServer.models.models import X` still works.

Actual implementations live in:
  base.py, user_models.py, event_models.py, chat_models.py,
  mission_models.py, auth_models.py
"""

# ── base ──────────────────────────────────────────────────────────────────────
from OrbitServer.models.base import client, _deep_convert, _entity_to_dict  # noqa: F401

# ── user ──────────────────────────────────────────────────────────────────────
from OrbitServer.models.user_models import (  # noqa: F401
    COLLEGE_YEARS,
    create_user, get_user_by_email, get_user,
    get_profile, upsert_profile, adjust_trust_score,
)

# ── event / pod / history ─────────────────────────────────────────────────────
from OrbitServer.models.event_models import (  # noqa: F401
    create_event, get_event, update_event, store_event_embedding,
    delete_event, list_events,
    create_event_pod, get_event_pod, update_event_pod, delete_event_pod,
    list_event_pods, get_user_pod_for_event, find_open_pod_for_event,
    transactional_pod_update, get_user_pods,
    record_event_action, get_user_event_history, update_event_history,
    get_history_entry,
)

# ── chat / votes ─────────────────────────────────────────────────────────────
from OrbitServer.models.chat_models import (  # noqa: F401
    create_chat_message, list_chat_messages,
    create_vote, get_vote, update_vote, transactional_vote_update,
    list_votes_for_pod,
)

# ── mission / signal ─────────────────────────────────────────────────────────
from OrbitServer.models.mission_models import (  # noqa: F401
    create_mission, get_mission, delete_mission,
    list_missions_for_user, update_mission_status,
    transactional_mission_rsvp, list_all_missions,
)

# ── auth ──────────────────────────────────────────────────────────────────────
from OrbitServer.models.auth_models import (  # noqa: F401
    store_refresh_token, get_refresh_token, delete_refresh_token,
    store_verification_code, increment_failed_attempts,
    get_verification_code, delete_verification_code,
)
