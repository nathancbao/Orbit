from OrbitServer.models.models import (
    create_signal, get_signal, delete_signal,
    list_signals_for_user, list_all_signals,
    transactional_signal_rsvp, list_rsvped_signals,
    create_signal_pod, get_pod, transactional_pod_update,
    get_user,
)
from OrbitServer.services.ai_suggestion_service import score_mission_for_user



def _score_signals(signals, user_id):
    """Score signals using the same AI scoring as missions."""
    user = get_user(user_id) or {}
    user_interests = set(user.get('interests') or [])
    for signal in signals:
        signal['match_score'] = score_mission_for_user(signal, user_interests)


def create_new_signal(data, creator_id):
    """Create and persist a signal. Returns (signal, None)."""
    signal = create_signal(data, creator_id)
    return signal, None


def get_all_signals(user_id=None, limit=20, cursor=None, category=None, tag=None):
    """Return signals, newest first (for discover feed).

    Returns (list, next_cursor, None).
    """
    signals, next_cursor = list_all_signals(
        limit=limit, cursor=cursor, category=category, tag=tag,
    )
    if user_id is not None:
        _resolve_pod_ids(signals, user_id)
        _score_signals(signals, user_id)
    return signals, next_cursor, None


def get_user_signals(user_id):
    """Return all signals posted by a user, newest first. Returns (list, None)."""
    signals = list_signals_for_user(user_id)
    _resolve_pod_ids(signals, user_id)
    _score_signals(signals, user_id)
    return signals, None


def get_rsvped_signals(user_id):
    """Return all signals the user has RSVP'd to. pod_id always included."""
    signals = list_rsvped_signals(user_id)
    _resolve_pod_ids(signals, user_id)
    _score_signals(signals, user_id)
    return signals, None


def fetch_signal(signal_id, user_id):
    """Return a single signal by ID with pod info resolved. Returns (signal, error)."""
    signal = get_signal(signal_id)
    if not signal:
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


def rsvp_signal(signal_id, user_id):
    """RSVP to a signal and create/join its pod. Returns (signal_dict, error_string)."""
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
    uid = int(user_id)
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
