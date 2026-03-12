import datetime

from OrbitServer.models.models import (
    get_mission, get_pod, update_pod, create_pod,
    find_open_pod_for_mission, get_user_pod_for_mission,
    list_pods, get_user, record_action,
    adjust_trust_score, transactional_pod_update, delete_pod,
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


def _find_best_pod_for_user(mission_id: int, user_interests: set, max_pod_size: int):
    """
    Return the open pod with the highest interest compatibility with the user.
    Falls back to the first open pod if the user has no interests set.
    Returns None if no open pods exist.
    """
    open_pods = [
        p for p in list_pods(mission_id)
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
            {'interests': (get_user(mid) or {}).get('interests') or []}
            for mid in (pod.get('member_ids') or [])
        ]
        score = _compute_pod_compatibility(user_interests, members)
        if score > best_score:
            best_score, best_pod = score, pod
    return best_pod


def _parse_time_of_day(time_str):
    """Parse an 'HH:mm' string into (hour, minute). Returns None on failure."""
    if not time_str:
        return None
    try:
        parts = time_str.split(':')
        return int(parts[0]), int(parts[1]) if len(parts) > 1 else 0
    except (ValueError, IndexError):
        return None


def _format_display_time(hour, minute):
    """Format hour/minute into '3:00 PM' style string."""
    am_pm = 'AM' if hour < 12 else 'PM'
    display_hour = hour if hour <= 12 else hour - 12
    if display_hour == 0:
        display_hour = 12
    return f'{display_hour}:{minute:02d} {am_pm}'


def _set_mission_time_info(mission):
    """Extract scheduling info from a set mission.

    Returns dict with:
      - scheduled_time: display string like "Mon, Mar 9 · 3:00 PM"
      - scheduled_end_time: ISO string of end datetime in UTC (or None)
      - expires_at: end datetime in UTC + 2 hours (or None)
    Returns None if the mission lacks a date.
    """
    date_str = mission.get('date', '')
    if not date_str:
        return None
    try:
        dt = datetime.datetime.strptime(date_str, '%Y-%m-%d')
    except (ValueError, TypeError):
        return None

    # utc_offset is seconds east of UTC (e.g. -25200 for US Pacific = UTC-7)
    utc_offset_secs = int(mission.get('utc_offset') or 0)
    offset_delta = datetime.timedelta(seconds=utc_offset_secs)

    result = {}

    # Parse start and end times
    parsed_start = _parse_time_of_day(mission.get('start_time', ''))
    parsed_end = _parse_time_of_day(mission.get('end_time', ''))

    # Build display string (stays in local time for display)
    if parsed_start and parsed_end:
        sh, sm = parsed_start
        eh, em = parsed_end
        time_part = f' · {_format_display_time(sh, sm)} – {_format_display_time(eh, em)}'
    elif parsed_start:
        sh, sm = parsed_start
        time_part = f' · {_format_display_time(sh, sm)}'
    else:
        time_part = ''
    result['scheduled_time'] = dt.strftime('%a, %b %-d') + time_part

    # Compute end datetime in UTC and expires_at
    if parsed_end:
        eh, em = parsed_end
        end_dt_utc = dt.replace(hour=eh, minute=em) - offset_delta
        result['scheduled_end_time'] = end_dt_utc.isoformat() + 'Z'
        result['expires_at'] = (end_dt_utc + datetime.timedelta(hours=2)).isoformat() + 'Z'
    elif parsed_start:
        # No explicit end time — default to start + 2 hours
        sh, sm = parsed_start
        default_end_utc = dt.replace(hour=sh, minute=sm) + datetime.timedelta(hours=2) - offset_delta
        result['scheduled_end_time'] = default_end_utc.isoformat() + 'Z'
        result['expires_at'] = (default_end_utc + datetime.timedelta(hours=2)).isoformat() + 'Z'
    else:
        # Date only, no times — expire at end of day + 2 hours
        end_of_day_utc = dt.replace(hour=23, minute=59) - offset_delta
        result['scheduled_end_time'] = end_of_day_utc.isoformat() + 'Z'
        result['expires_at'] = (end_of_day_utc + datetime.timedelta(hours=2)).isoformat() + 'Z'

    return result


def join_mission(mission_id, user_id):
    """
    Assign a user to the next open pod for a mission.
    Creates a new pod if none are open.
    Uses a Datastore transaction to prevent race conditions.
    Returns (pod_dict, error_string).
    """
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"
    if mission.get('status') != 'open':
        return None, "This mission is no longer accepting new members"

    # Check if user is already in a pod for this mission
    existing = get_user_pod_for_mission(mission_id, user_id)
    if existing:
        return existing, None

    max_pod_size = mission.get('max_pod_size', 4)

    # Fetch user interests for compatibility-based pod selection
    user = get_user(user_id) or {}
    user_interests = set(user.get('interests') or [])

    # Find the best-fit open pod (most interest overlap), or create a new one
    pod = _find_best_pod_for_user(mission_id, user_interests, max_pod_size)
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
            pod = create_pod(mission_id, max_size=max_pod_size, first_member_id=user_id)
    else:
        pod = create_pod(mission_id, max_size=max_pod_size, first_member_id=user_id)

    # For set missions, auto-set the pod's scheduled_time, end time, and expiry
    if mission.get('mode') != 'flex' and not pod.get('scheduled_time'):
        info = _set_mission_time_info(mission)
        if info:
            location = mission.get('location') or None
            sched = info['scheduled_time']
            end_time = info.get('scheduled_end_time')
            exp = info.get('expires_at')

            def _set_time(entity):
                entity['scheduled_time'] = sched
                entity['scheduled_place'] = location
                entity['status'] = 'meeting_confirmed'
                if end_time:
                    entity['scheduled_end_time'] = end_time
                if exp:
                    entity['expires_at'] = exp

            transactional_pod_update(pod['id'], _set_time)
            pod['scheduled_time'] = sched
            pod['scheduled_place'] = location
            pod['status'] = 'meeting_confirmed'
            if end_time:
                pod['scheduled_end_time'] = end_time
            if exp:
                pod['expires_at'] = exp

    record_action(user_id, mission_id, 'joined', pod_id=pod['id'],
                   tags_snapshot=mission.get('tags') or [])
    return pod, None


def leave_mission(mission_id, user_id):
    """
    Remove a user from their pod for a mission.
    Uses a Datastore transaction to prevent race conditions.
    Returns (True, None) or (False, error_string).
    """
    uid = _safe_int(user_id)
    if uid is None:
        return False, "Invalid user ID"

    pod = get_user_pod_for_mission(mission_id, user_id)
    if not pod:
        return False, "You are not in a pod for this mission"

    def _remove_member(entity):
        member_ids = [m for m in (entity.get('member_ids') or []) if m != int(user_id)]
        entity['member_ids'] = member_ids
        entity['status'] = 'open' if len(member_ids) < entity.get('max_size', 4) else entity.get('status', 'open')

    transactional_pod_update(pod['id'], _remove_member)
    return True, None


def leave_pod(pod_id, user_id):
    """
    Remove a user from a pod. Deletes the pod entirely if no members remain.
    For signal pods, also removes the user from the signal's rsvps list.
    Returns (True, None) on success or (False, (error_msg, status_code)) on failure.
    """
    from OrbitServer.models.models import remove_signal_rsvp

    uid = _safe_int(user_id)
    if uid is None:
        return False, ("Invalid user ID", 400)

    pod = get_pod(pod_id)
    if not pod:
        return False, ("Pod not found", 404)

    # Normalise member_ids to ints so mixed-type lists (e.g. ["42"] vs [42])
    # don't cause false "not a member" results.
    member_ids = [_safe_int(m) for m in (pod.get('member_ids') or []) if _safe_int(m) is not None]
    if uid not in member_ids:
        # Truly not present — nothing to remove, but treat as success so the
        # client can clean up stale pod references from its list.
        return True, None

    def _remove(entity):
        m_ids = [m for m in (entity.get('member_ids') or []) if _safe_int(m) != uid]
        confirmed = [c for c in (entity.get('confirmed_attendees') or []) if _safe_int(c) != uid]
        entity['member_ids'] = m_ids
        entity['confirmed_attendees'] = confirmed
        entity['status'] = 'open' if len(m_ids) < entity.get('max_size', 4) else entity.get('status', 'open')
        return len(m_ids)

    remaining, _ = transactional_pod_update(pod_id, _remove)

    if remaining == 0:
        delete_pod(pod_id)

    # For signal pods, also remove user from the signal's rsvps so it
    # no longer appears on their Pods tab.
    signal_id = pod.get('signal_id')
    if signal_id:
        try:
            remove_signal_rsvp(signal_id, user_id)
        except Exception:
            logger.exception("Failed to remove RSVP for signal %s", signal_id)

    return True, None


def get_pod_with_members(pod_id, requesting_user_id):
    """
    Returns pod dict enriched with member profile stubs.
    Only accessible to pod members.
    Auto-deletes expired pods (past expires_at).
    Returns (pod, error_message, status_code).
    """
    uid = _safe_int(requesting_user_id)
    if uid is None:
        return None, "Invalid user ID", 400

    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found", 404

    # Check if pod has expired (2 hours after scheduled_end_time)
    now = datetime.datetime.utcnow()
    end_time_raw = pod.get('scheduled_end_time')
    if end_time_raw:
        end_dt = None
        if isinstance(end_time_raw, str):
            try:
                end_dt = datetime.datetime.fromisoformat(
                    end_time_raw.replace('Z', '+00:00')
                ).replace(tzinfo=None)
            except (ValueError, TypeError):
                end_dt = None
        elif isinstance(end_time_raw, datetime.datetime):
            end_dt = end_time_raw
        if end_dt and now > end_dt + datetime.timedelta(hours=2):
            delete_pod(pod_id)
            return None, "This pod has expired and been removed", 410

    # Normalise member_ids to ints so mixed-type lists don't cause false 403s.
    member_ids = [_safe_int(m) for m in (pod.get('member_ids') or [])]
    member_ids = [m for m in member_ids if m is not None]
    if uid not in member_ids:
        return None, "You are not a member of this pod", 403

    members = []
    for member_uid in member_ids:
        user = get_user(member_uid) or {}
        members.append({
            'user_id': member_uid,
            'name': user.get('name', ''),
            'college_year': user.get('college_year', ''),
            'interests': user.get('interests', []),
            'photo': user.get('photo'),
        })

    # Enrich with mission title/tags and survey eligibility
    mission_id = pod.get('mission_id')
    if mission_id is not None:
        from OrbitServer.models.models import get_mission
        mission = get_mission(int(mission_id))
        pod['mission_title'] = mission.get('title', 'Untitled') if mission else 'Untitled'
        pod['mission_tags'] = mission.get('tags', []) if mission else []
    else:
        pod['mission_title'] = 'Untitled'
        pod['mission_tags'] = []

    survey_completed_by = pod.get('survey_completed_by') or []
    completed_at_raw = pod.get('completed_at')
    if completed_at_raw and isinstance(completed_at_raw, str):
        try:
            completed_at = datetime.datetime.fromisoformat(completed_at_raw.replace('Z', '+00:00')).replace(tzinfo=None)
        except ValueError:
            completed_at = None
    else:
        completed_at = completed_at_raw if isinstance(completed_at_raw, datetime.datetime) else None

    survey_window = datetime.timedelta(days=7)
    pod['has_pending_survey'] = (
        pod.get('status') == 'completed'
        and uid not in survey_completed_by
        and (completed_at is None or (now - completed_at) < survey_window)
    )

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

    pod = get_pod(pod_id)
    if not pod:
        return None, False, "Pod not found", 404

    member_ids = [_safe_int(m) for m in (pod.get('member_ids') or []) if _safe_int(m) is not None]
    if kicker_uid not in member_ids:
        return None, False, "You are not a member of this pod", 403
    if target_uid not in member_ids:
        return None, False, "Target user is not in this pod", 400
    if kicker_uid == target_uid:
        return None, False, "You cannot kick yourself", 400

    kick_result = {'kicked': False, 'replacement': None, 'mission_id': None}

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
            kick_result['mission_id'] = entity.get('mission_id')
            entity['member_ids'] = m_ids
            entity['status'] = 'full' if len(m_ids) >= entity.get('max_size', 4) else 'open'

        entity['kick_votes'] = kick_votes

    _, pod = transactional_pod_update(pod_id, _apply_kick_vote)

    if kick_result['kicked'] and kick_result['mission_id']:
        replacement = _find_replacement(kick_result['mission_id'], pod_id, pod.get('member_ids', []))
        if replacement:
            def _add_replacement(entity):
                m_ids = list(entity.get('member_ids') or [])
                m_ids.append(replacement)
                entity['member_ids'] = m_ids
                entity['status'] = 'full' if len(m_ids) >= entity.get('max_size', 4) else 'open'
            _, pod = transactional_pod_update(pod_id, _add_replacement)
            record_action(replacement, kick_result['mission_id'], 'joined', pod_id=pod_id)

    return pod, kick_result['kicked'], None, None


def _find_replacement(mission_id, pod_id, current_members):
    """
    Find the first user who has joined the mission but is not yet in any pod.
    This is a simple FIFO replacement.
    Returns user_id of replacement or None if no suitable candidate found.
    """
    from OrbitServer.models.models import list_pods
    from google.cloud import datastore
    from google.cloud.datastore.query import PropertyFilter

    # Get all members across all pods for this mission
    occupied = set()
    for pod in list_pods(mission_id):
        occupied.update(pod.get('member_ids') or [])
    occupied.update(current_members)

    # Query UserHistory for users who joined this mission but aren't in any pod
    client = datastore.Client()
    query = client.query(kind='UserHistory')
    query.add_filter(filter=PropertyFilter('mission_id', '=', int(mission_id)))
    query.add_filter(filter=PropertyFilter('action', '=', 'joined'))
    query.order = ['created_at']  # FIFO: earliest joiner gets priority

    for record in query.fetch(limit=50):
        user_id = record.get('user_id')
        if user_id and user_id not in occupied:
            return user_id

    return None


def confirm_attendance(pod_id, user_id):
    """
    Record that a user attended the mission.
    Uses a Datastore transaction for atomicity.
    Awards trust points. Returns (pod, error_message, status_code).
    """
    uid = _safe_int(user_id)
    if uid is None:
        return None, "Invalid user ID", 400

    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found", 404

    member_ids = [_safe_int(m) for m in (pod.get('member_ids') or []) if _safe_int(m) is not None]
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
            entity['completed_at'] = datetime.datetime.utcnow()

    _, pod = transactional_pod_update(pod_id, _confirm)

    # Award trust points (adjust_trust_score already uses its own transaction)
    adjust_trust_score(user_id, ATTENDANCE_CONFIRM_POINTS / 100)
    return pod, None, None


def apply_no_show_penalties(pod_id):
    """
    Called by a cron job 24h after scheduled_time.
    Penalizes members who didn't confirm attendance.
    """
    pod = get_pod(pod_id)
    if not pod or pod.get('status') == 'completed':
        return

    scheduled = pod.get('scheduled_time')
    if not scheduled:
        return

    confirmed = set(pod.get('confirmed_attendees') or [])
    for uid in (pod.get('member_ids') or []):
        if uid not in confirmed:
            adjust_trust_score(uid, NO_SHOW_PENALTY / 100)
