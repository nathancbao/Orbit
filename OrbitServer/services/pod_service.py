import datetime

from OrbitServer.models.models import (
    get_event, get_event_pod, update_event_pod, create_event_pod,
    find_open_pod_for_event, get_user_pod_for_event,
    list_event_pods, get_profile, record_event_action,
    adjust_trust_score, transactional_pod_update,
)
from OrbitServer.utils.helpers import safe_int as _safe_int

ATTENDANCE_CONFIRM_POINTS = 50
NO_SHOW_PENALTY = -20
KICK_MAJORITY_THRESHOLD = 0.5  # >50% of other members


def _compute_pod_compatibility(user_interests: set, pod_members: list) -> float:
    """
    Average Jaccard similarity between user_interests and each pod member's interests.
    Returns 0.0 for empty pods or empty user interest sets.
    """
    if not pod_members or not user_interests:
        return 0.0
    total = 0.0
    for member in pod_members:
        member_interests = set(member.get('interests') or [])
        union = user_interests | member_interests
        if not union:
            continue
        total += len(user_interests & member_interests) / len(union)
    return total / len(pod_members)


def _find_best_pod_for_user(event_id: int, user_interests: set, max_pod_size: int):
    """
    Return the open pod with the highest interest compatibility with the user.
    Falls back to the first open pod if the user has no interests set.
    Returns None if no open pods exist.
    """
    open_pods = [
        p for p in list_event_pods(event_id)
        if p.get('status') == 'open'
        and len(p.get('member_ids') or []) < max_pod_size
    ]
    if not open_pods:
        return None
    if not user_interests:
        return open_pods[0]

    best_pod, best_score = open_pods[0], -1.0
    for pod in open_pods:
        members = [
            {'interests': (get_profile(mid) or {}).get('interests') or []}
            for mid in (pod.get('member_ids') or [])
        ]
        score = _compute_pod_compatibility(user_interests, members)
        if score > best_score:
            best_score, best_pod = score, pod
    return best_pod


def join_event(event_id, user_id):
    """
    Assign a user to the next open pod for an event.
    Creates a new pod if none are open.
    Uses a Datastore transaction to prevent race conditions.
    Returns (pod_dict, error_string).
    """
    event = get_event(event_id)
    if not event:
        return None, "Event not found"
    if event.get('status') != 'open':
        return None, "This event is no longer accepting new members"

    # Check if user is already in a pod for this event
    existing = get_user_pod_for_event(event_id, user_id)
    if existing:
        return existing, None

    max_pod_size = event.get('max_pod_size', 4)

    # Fetch user interests for compatibility-based pod selection
    profile = get_profile(user_id) or {}
    user_interests = set(profile.get('interests') or [])

    # Find the best-fit open pod (most interest overlap), or create a new one
    pod = _find_best_pod_for_user(event_id, user_interests, max_pod_size)
    uid = _safe_int(user_id)
    if uid is None:
        return None, "Invalid user ID"

    if pod:
        def _add_member(entity):
            member_ids = list(entity.get('member_ids') or [])
            if int(user_id) in member_ids:
                return 'already_joined'
            if len(member_ids) >= max_pod_size:
                return 'full'
            member_ids.append(int(user_id))
            entity['member_ids'] = member_ids
            entity['status'] = 'full' if len(member_ids) >= max_pod_size else 'open'
            return 'joined'

        result, pod = transactional_pod_update(pod['id'], _add_member)
        if result == 'full':
            # Pod filled between our check and the transaction; create a new one
            pod = create_event_pod(event_id, max_size=max_pod_size, first_member_id=user_id)
    else:
        pod = create_event_pod(event_id, max_size=max_pod_size, first_member_id=user_id)

    record_event_action(user_id, event_id, 'joined', pod_id=pod['id'],
                        tags_snapshot=event.get('tags') or [])
    return pod, None


def leave_event(event_id, user_id):
    """
    Remove a user from their pod for an event.
    Uses a Datastore transaction to prevent race conditions.
    Returns (True, None) or (False, error_string).
    """
    uid = _safe_int(user_id)
    if uid is None:
        return False, "Invalid user ID"

    pod = get_user_pod_for_event(event_id, user_id)
    if not pod:
        return False, "You are not in a pod for this event"

    def _remove_member(entity):
        member_ids = [m for m in (entity.get('member_ids') or []) if m != int(user_id)]
        entity['member_ids'] = member_ids
        entity['status'] = 'open' if len(member_ids) < entity.get('max_size', 4) else entity.get('status', 'open')

    transactional_pod_update(pod['id'], _remove_member)
    return True, None


def get_pod_with_members(pod_id, requesting_user_id):
    """
    Returns pod dict enriched with member profile stubs.
    Only accessible to pod members.
    Returns (pod, error_message, status_code).
    """
    uid = _safe_int(requesting_user_id)
    if uid is None:
        return None, "Invalid user ID", 400

    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found", 404

    member_ids = pod.get('member_ids') or []
    if uid not in member_ids:
        return None, "You are not a member of this pod", 403

    members = []
    for member_uid in member_ids:
        profile = get_profile(member_uid) or {}
        members.append({
            'user_id': member_uid,
            'name': profile.get('name', ''),
            'college_year': profile.get('college_year', ''),
            'interests': profile.get('interests', []),
            'photo': profile.get('photo'),
        })

    return {**pod, 'members': members}, None, None


def vote_to_kick(pod_id, kicker_user_id, target_user_id):
    """
    Record a kick vote. If majority of non-target members vote kick,
    remove the target and open the pod for a replacement.
    Uses a Datastore transaction for atomicity.
    Returns (pod, kicked, error_message, status_code).
    """
    kicker_uid = _safe_int(kicker_user_id)
    target_uid = _safe_int(target_user_id)
    if kicker_uid is None or target_uid is None:
        return None, False, "Invalid user ID", 400

    pod = get_event_pod(pod_id)
    if not pod:
        return None, False, "Pod not found", 404

    member_ids = list(pod.get('member_ids') or [])
    if kicker_uid not in member_ids:
        return None, False, "You are not a member of this pod", 403
    if target_uid not in member_ids:
        return None, False, "Target user is not in this pod", 400
    if kicker_uid == target_uid:
        return None, False, "You cannot kick yourself", 400

    kick_result = {'kicked': False, 'replacement': None, 'event_id': None}

    def _apply_kick_vote(entity):
        m_ids = list(entity.get('member_ids') or [])
        kick_votes = dict(entity.get('kick_votes') or {})
        target_key = str(target_user_id)
        voters = list(kick_votes.get(target_key, []))
        if int(kicker_user_id) not in voters:
            voters.append(int(kicker_user_id))
        kick_votes[target_key] = voters

        eligible_voters = [m for m in m_ids if m != int(target_user_id)]
        majority_needed = len(eligible_voters) * KICK_MAJORITY_THRESHOLD

        if len(voters) > majority_needed:
            m_ids.remove(int(target_user_id))
            del kick_votes[target_key]
            kick_result['kicked'] = True
            kick_result['event_id'] = entity.get('event_id')
            entity['member_ids'] = m_ids
            entity['status'] = 'full' if len(m_ids) >= entity.get('max_size', 4) else 'open'

        entity['kick_votes'] = kick_votes

    _, pod = transactional_pod_update(pod_id, _apply_kick_vote)

    if kick_result['kicked'] and kick_result['event_id']:
        replacement = _find_replacement(kick_result['event_id'], pod_id, pod.get('member_ids', []))
        if replacement:
            def _add_replacement(entity):
                m_ids = list(entity.get('member_ids') or [])
                m_ids.append(replacement)
                entity['member_ids'] = m_ids
                entity['status'] = 'full' if len(m_ids) >= entity.get('max_size', 4) else 'open'
            _, pod = transactional_pod_update(pod_id, _add_replacement)
            record_event_action(replacement, kick_result['event_id'], 'joined', pod_id=pod_id)

    return pod, kick_result['kicked'], None, None


def _find_replacement(event_id, pod_id, current_members):
    """
    Find the first user who has joined the event but is not yet in any pod.
    This is a simple FIFO replacement — no matching logic needed at this edge case.
    Returns user_id of replacement or None if no suitable candidate found.
    """
    from OrbitServer.models.models import list_event_pods
    from google.cloud import datastore

    # Get all members across all pods for this event
    occupied = set()
    for pod in list_event_pods(event_id):
        occupied.update(pod.get('member_ids') or [])
    occupied.update(current_members)

    # Query UserEventHistory for users who joined this event but aren't in any pod
    client = datastore.Client()
    query = client.query(kind='UserEventHistory')
    query.add_filter('event_id', '=', int(event_id))
    query.add_filter('action', '=', 'joined')
    query.order = ['created_at']  # FIFO: earliest joiner gets priority

    for record in query.fetch(limit=50):
        user_id = record.get('user_id')
        if user_id and user_id not in occupied:
            return user_id

    return None


def confirm_attendance(pod_id, user_id):
    """
    Record that a user attended the event.
    Uses a Datastore transaction for atomicity.
    Awards trust points. Returns (pod, error_message, status_code).
    """
    uid = _safe_int(user_id)
    if uid is None:
        return None, "Invalid user ID", 400

    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found", 404

    member_ids = pod.get('member_ids') or []
    if uid not in member_ids:
        return None, "You are not a member of this pod", 403

    def _confirm(entity):
        m_ids = entity.get('member_ids') or []
        confirmed = list(entity.get('confirmed_attendees') or [])
        if int(user_id) not in confirmed:
            confirmed.append(int(user_id))
        entity['confirmed_attendees'] = confirmed
        if len(confirmed) >= len(m_ids) * 0.5:
            entity['status'] = 'completed'

    _, pod = transactional_pod_update(pod_id, _confirm)

    # Award trust points (adjust_trust_score already uses its own transaction)
    adjust_trust_score(user_id, ATTENDANCE_CONFIRM_POINTS / 100)
    return pod, None, None


def apply_no_show_penalties(pod_id):
    """
    Called by a cron job 24h after scheduled_time.
    Penalizes members who didn't confirm attendance.
    """
    pod = get_event_pod(pod_id)
    if not pod or pod.get('status') == 'completed':
        return

    scheduled = pod.get('scheduled_time')
    if not scheduled:
        return

    confirmed = set(pod.get('confirmed_attendees') or [])
    for uid in (pod.get('member_ids') or []):
        if uid not in confirmed:
            adjust_trust_score(uid, NO_SHOW_PENALTY / 100)
