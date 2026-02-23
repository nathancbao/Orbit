import datetime

from OrbitServer.models.models import (
    get_event, get_event_pod, update_event_pod, create_event_pod,
    find_open_pod_for_event, get_user_pod_for_event,
    list_event_pods, get_profile, record_event_action,
    adjust_trust_score,
)

ATTENDANCE_CONFIRM_POINTS = 50
NO_SHOW_PENALTY = -20
KICK_MAJORITY_THRESHOLD = 0.5  # >50% of other members


def join_event(event_id, user_id):
    """
    Assign a user to the next open pod for an event.
    Creates a new pod if none are open.
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

    # Find an open pod with room
    pod = find_open_pod_for_event(event_id)
    if pod:
        member_ids = list(pod.get('member_ids') or [])
        member_ids.append(int(user_id))
        new_status = 'full' if len(member_ids) >= max_pod_size else 'open'
        pod = update_event_pod(pod['id'], {'member_ids': member_ids, 'status': new_status})
    else:
        pod = create_event_pod(event_id, max_size=max_pod_size, first_member_id=user_id)

    record_event_action(user_id, event_id, 'joined', pod_id=pod['id'])
    return pod, None


def leave_event(event_id, user_id):
    """
    Remove a user from their pod for an event.
    Returns (True, None) or (False, error_string).
    """
    pod = get_user_pod_for_event(event_id, user_id)
    if not pod:
        return False, "You are not in a pod for this event"

    member_ids = [m for m in (pod.get('member_ids') or []) if m != int(user_id)]
    new_status = 'open' if len(member_ids) < pod.get('max_size', 4) else pod['status']
    update_event_pod(pod['id'], {'member_ids': member_ids, 'status': new_status})
    return True, None


def get_pod_with_members(pod_id, requesting_user_id):
    """
    Returns pod dict enriched with member profile stubs.
    Only accessible to pod members.
    """
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"

    member_ids = pod.get('member_ids') or []
    if int(requesting_user_id) not in member_ids:
        return None, "You are not a member of this pod"

    members = []
    for uid in member_ids:
        profile = get_profile(uid) or {}
        members.append({
            'user_id': uid,
            'name': profile.get('name', ''),
            'college_year': profile.get('college_year', ''),
            'interests': profile.get('interests', []),
            'photo': profile.get('photo'),
        })

    return {**pod, 'members': members}, None


def vote_to_kick(pod_id, kicker_user_id, target_user_id):
    """
    Record a kick vote. If majority of non-target members vote kick,
    remove the target and open the pod for a replacement.
    Returns (pod, kicked, error).
    """
    pod = get_event_pod(pod_id)
    if not pod:
        return None, False, "Pod not found"

    member_ids = list(pod.get('member_ids') or [])
    if int(kicker_user_id) not in member_ids:
        return None, False, "You are not a member of this pod"
    if int(target_user_id) not in member_ids:
        return None, False, "Target user is not in this pod"
    if int(kicker_user_id) == int(target_user_id):
        return None, False, "You cannot kick yourself"

    kick_votes = dict(pod.get('kick_votes') or {})
    target_key = str(target_user_id)
    voters = kick_votes.get(target_key, [])
    if int(kicker_user_id) not in voters:
        voters.append(int(kicker_user_id))
    kick_votes[target_key] = voters

    # Count non-target members eligible to vote
    eligible_voters = [m for m in member_ids if m != int(target_user_id)]
    majority_needed = len(eligible_voters) * KICK_MAJORITY_THRESHOLD

    kicked = False
    if len(voters) > majority_needed:
        # Execute kick
        member_ids.remove(int(target_user_id))
        del kick_votes[target_key]
        kicked = True
        # Try to find a replacement from event's open waiting list
        event_id = pod.get('event_id')
        replacement = _find_replacement(event_id, pod_id, member_ids)
        if replacement:
            member_ids.append(replacement)
            record_event_action(replacement, event_id, 'joined', pod_id=pod_id)

        new_status = 'full' if len(member_ids) >= pod.get('max_size', 4) else 'open'
        pod = update_event_pod(pod_id, {
            'member_ids': member_ids,
            'status': new_status,
            'kick_votes': kick_votes,
        })
    else:
        pod = update_event_pod(pod_id, {'kick_votes': kick_votes})

    return pod, kicked, None


def _find_replacement(event_id, pod_id, current_members):
    """
    Find the first user who has joined the event but is not yet in any pod.
    This is a simple FIFO replacement — no matching logic needed at this edge case.
    """
    from OrbitServer.models.models import get_user_event_history, list_event_pods
    import datetime

    # Get all members across all pods for this event
    occupied = set()
    for pod in list_event_pods(event_id):
        if pod['id'] != pod_id:
            occupied.update(pod.get('member_ids') or [])
    occupied.update(current_members)

    # Check event history for users who joined but aren't placed
    # (In practice, all joiners go into a pod immediately, so this
    #  mainly catches users who were in a different pod that freed up a seat.)
    return None  # Placeholder: could query a waiting list in a future iteration


def confirm_attendance(pod_id, user_id):
    """
    Record that a user attended the event.
    Awards trust points. Returns (pod, error).
    """
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"

    member_ids = pod.get('member_ids') or []
    if int(user_id) not in member_ids:
        return None, "You are not a member of this pod"

    confirmed = list(pod.get('confirmed_attendees') or [])
    if int(user_id) not in confirmed:
        confirmed.append(int(user_id))

    updates = {'confirmed_attendees': confirmed}

    # If majority confirmed, mark pod as completed
    if len(confirmed) >= len(member_ids) * 0.5:
        updates['status'] = 'completed'

    pod = update_event_pod(pod_id, updates)

    # Award trust points
    adjust_trust_score(user_id, ATTENDANCE_CONFIRM_POINTS / 100)  # scale to 0–5 range
    return pod, None


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
