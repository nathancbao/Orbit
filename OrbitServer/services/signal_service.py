import datetime
import logging

from OrbitServer.models.models import (
    create_signal, get_signal, delete_signal, update_signal,
    list_signals_for_user, list_all_signals,
    transactional_signal_rsvp, list_rsvped_signals,
    create_signal_pod, get_pod, transactional_pod_update,
    get_user,
)
from OrbitServer.services.ai_suggestion_service import score_mission_for_user
from OrbitServer.utils.colleges import filter_by_distance

logger = logging.getLogger(__name__)

# How long after a signal's last availability date before auto-deletion
_SIGNAL_GRACE_PERIOD = datetime.timedelta(hours=24)
# Fallback lifetime when availability dates can't be parsed (matches pod TTL)
_SIGNAL_FALLBACK_TTL = datetime.timedelta(days=14)


def _parse_availability_date(value):
    """Parse an availability slot date -- 'YYYY-MM-DD' or full ISO 8601."""
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.date.fromisoformat(value[:10])
    except ValueError:
        return None


def signal_expiry_datetime(signal):
    """UTC datetime after which a signal should be deleted.

    24h after the end (23:59) of the latest availability date; if no
    availability date parses, created_at + 14 days; if created_at is also
    unusable, None (never expires).
    """
    latest = None
    for slot in signal.get('availability') or []:
        if not isinstance(slot, dict):
            continue
        d = _parse_availability_date(slot.get('date'))
        if d and (latest is None or d > latest):
            latest = d
    if latest is not None:
        end_of_day = datetime.datetime.combine(latest, datetime.time(23, 59))
        return end_of_day + _SIGNAL_GRACE_PERIOD

    created = signal.get('created_at')
    if isinstance(created, str):
        try:
            created = datetime.datetime.fromisoformat(created.replace('Z', ''))
        except ValueError:
            created = None
    if isinstance(created, datetime.datetime):
        return created.replace(tzinfo=None) + _SIGNAL_FALLBACK_TTL
    return None


def check_signal_expiration(signal):
    """Delete a signal past its expiry. Returns 'active' or 'deleted'."""
    if not signal:
        return 'deleted'
    expiry = signal_expiry_datetime(signal)
    if expiry is not None and datetime.datetime.utcnow() > expiry:
        try:
            delete_signal(signal['id'])
        except Exception:
            logger.exception("Failed to auto-delete expired signal %s", signal.get('id'))
        return 'deleted'
    return 'active'


def filter_expired_signals(signals):
    """Drop (and delete) expired signals from a list."""
    return [s for s in signals if check_signal_expiration(s) != 'deleted']


def _score_signals(signals, user_id):
    """Score signals using the same AI scoring as missions."""
    user = get_user(user_id) or {}
    user_interests = set(user.get('interests') or [])
    for signal in signals:
        signal['match_score'] = score_mission_for_user(signal, user_interests)


def create_new_signal(data, creator_id):
    """Create and persist a signal. Returns (signal, None)."""
    # Stamp the creator's college for distance filtering in the feeds
    creator = get_user(creator_id) or {}
    signal = create_signal(data, creator_id, college=creator.get('college') or '')
    return signal, None


def get_all_signals(user_id=None, limit=20, cursor=None, category=None, tag=None):
    """Return signals, newest first (for discover feed).

    Returns (list, next_cursor, None).
    """
    signals, next_cursor = list_all_signals(
        limit=limit, cursor=cursor, category=category, tag=tag,
    )
    # Expiry + distance filtering happen after pagination, so a page can
    # come back short of `limit` -- acceptable at this scale.
    signals = filter_expired_signals(signals)
    if user_id is not None:
        signals = filter_by_distance(signals, get_user(user_id) or {})
        _resolve_pod_ids(signals, user_id)
        _score_signals(signals, user_id)
    return signals, next_cursor, None


def get_user_signals(user_id):
    """Return all signals posted by a user, newest first. Returns (list, None)."""
    signals = filter_expired_signals(list_signals_for_user(user_id))
    _resolve_pod_ids(signals, user_id)
    _score_signals(signals, user_id)
    return signals, None


def get_rsvped_signals(user_id):
    """Return all signals the user has RSVP'd to. pod_id always included."""
    signals = filter_expired_signals(list_rsvped_signals(user_id))
    _resolve_pod_ids(signals, user_id)
    _score_signals(signals, user_id)
    return signals, None


def fetch_signal(signal_id, user_id):
    """Return a single signal by ID with pod info resolved. Returns (signal, error)."""
    signal = get_signal(signal_id)
    if not signal:
        return None, "Signal not found"
    if check_signal_expiration(signal) == 'deleted':
        return None, "Signal not found"
    _resolve_pod_ids([signal], user_id)
    _score_signals([signal], user_id)
    return signal, None


def remove_signal(signal_id, user_id):
    """
    Delete a signal if the requesting user owns it.
    Returns (success, error_message, status_code).
    status_code is None on success.
    """
    signal = get_signal(signal_id)
    if not signal:
        return False, "Signal not found", 404
    if signal.get('creator_id') != int(user_id):
        return False, "Only the creator can delete this signal", 403
    delete_signal(signal_id)
    return True, None, None


def edit_signal(signal_id, data, user_id):
    """
    Edit a signal. Returns (signal, error_message, status_code).
    status_code is None on success.
    """
    signal = get_signal(signal_id)
    if not signal:
        return None, "Signal not found", 404
    if signal.get('creator_id') != int(user_id):
        return None, "Only the creator can edit this signal", 403
    updated = update_signal(signal_id, data)
    return updated, None, None


def rsvp_signal(signal_id, user_id):
    """RSVP to a signal and create/join its pod. Returns (signal_dict, error_string)."""
    from OrbitServer.services.pod_service import at_pod_limit, MAX_PODS_PER_USER

    # Enforce the pod cap for new RSVPs only — re-RSVPs fall through so the
    # frontend can recover the existing pod.
    existing_signal = get_signal(signal_id)
    if not existing_signal:
        return None, "Signal not found"
    already_rsvped = int(user_id) in (existing_signal.get('rsvps') or [])
    if not already_rsvped and at_pod_limit(user_id):
        return None, f"You can only be in {MAX_PODS_PER_USER} pods at a time"

    signal, err = transactional_signal_rsvp(signal_id, user_id)
    if err:
        # For "already RSVP'd", still return the signal with pod_id so the
        # frontend can open the pod instead of showing "waiting for a pod".
        if signal is None and "already" in (err or "").lower():
            existing = get_signal(signal_id)
            if existing:
                pod_id = _user_pod_id(existing, user_id)
                if pod_id:
                    pod = get_pod(pod_id)
                    if not pod:
                        max_size = int(existing.get('max_group_size', 6))
                        create_signal_pod(pod_id, signal_id, max_size, user_id)
                    existing['pod_id'] = pod_id
                return existing, None
        return signal, err

    # Determine which pod this user belongs to
    pod_id = _user_pod_id(signal, user_id)
    if pod_id:
        pod = get_pod(pod_id)
        if not pod:
            max_size = int(signal.get('max_group_size', 6))
            create_signal_pod(pod_id, signal_id, max_size, user_id)
        else:
            uid = int(user_id)
            if uid not in (pod.get('member_ids') or []):
                _add_member_to_pod(pod_id, user_id, pod.get('max_size', 6))

    # Return pod_id (singular) for frontend convenience
    signal['pod_id'] = pod_id
    return signal, None


def _user_pod_id(signal, user_id):
    """Return the pod_id for the pod the user is assigned to, or None."""
    rsvps = signal.get('rsvps') or []
    pod_ids = signal.get('pod_ids') or []
    uid = int(user_id)
    if uid not in rsvps or not pod_ids:
        return None
    idx = rsvps.index(uid)
    max_gs = int(signal.get('max_group_size', 6))
    pod_index = min(idx // max_gs, len(pod_ids) - 1)
    return pod_ids[pod_index]


def _add_member_to_pod(pod_id, user_id, max_size):
    """Add a user to an existing signal pod via transactional update."""
    def _update(entity):
        member_ids = list(entity.get('member_ids') or [])
        uid = int(user_id)
        if uid in member_ids:
            return 'already_joined'
        member_ids.append(uid)
        entity['member_ids'] = member_ids
        if len(member_ids) >= int(max_size):
            entity['status'] = 'full'
        return 'joined'
    transactional_pod_update(pod_id, _update)


def _resolve_pod_ids(signals, user_id):
    """Replace pod_ids list with a single pod_id for the requesting user's pod.

    If the user is in a pod, sets pod_id to their specific pod and includes
    scheduled_time when the meeting has been confirmed.
    Otherwise, removes pod-related fields from the response.
    """
    for s in signals:
        user_pod = _user_pod_id(s, user_id)
        # Clean internal pod_ids from response; expose only pod_id
        s.pop('pod_ids', None)
        if user_pod:
            s['pod_id'] = user_pod
            pod = get_pod(user_pod)
            if pod and pod.get('scheduled_time'):
                s['scheduled_time'] = pod['scheduled_time']
        else:
            s.pop('pod_id', None)
