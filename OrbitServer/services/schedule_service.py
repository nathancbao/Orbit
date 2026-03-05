import datetime

from OrbitServer.models.models import (
    get_pod, transactional_pod_update, create_chat_message,
)
from OrbitServer.utils.helpers import safe_int


def submit_availability(pod_id, user_id, name, join_index, slots):
    """
    Atomically update pod.schedule_data.entries[str(user_id)].
    slots: [{'date': 'YYYY-MM-DD', 'hour': int}]
    Returns (updated_pod_dict, error_string).
    """
    uid = safe_int(user_id)
    if uid is None:
        return None, "Invalid user ID"

    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"

    member_ids = pod.get('member_ids') or []
    if uid not in member_ids:
        return None, "You are not a member of this pod"

    def _update(entity):
        schedule_data = dict(entity.get('schedule_data') or {'entries': {}})
        entries = dict(schedule_data.get('entries') or {})
        entries[str(user_id)] = {
            'slots': [{'date': s['date'], 'hour': int(s['hour'])} for s in slots],
            'name': str(name),
            'join_index': int(join_index),
            'updated_at': datetime.datetime.utcnow().isoformat() + 'Z',
        }
        schedule_data['entries'] = entries
        entity['schedule_data'] = schedule_data

    _, updated = transactional_pod_update(pod_id, _update)
    return updated, None


def confirm_slot(pod_id, user_id, date_str, hour):
    """
    Set pod.scheduled_time, post system message, set status to meeting_confirmed.
    Returns (updated_pod_dict, error_string).
    """
    uid = safe_int(user_id)
    if uid is None:
        return None, "Invalid user ID"

    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"

    member_ids = pod.get('member_ids') or []
    if uid not in member_ids:
        return None, "You are not a member of this pod"

    try:
        dt = datetime.datetime.strptime(date_str, '%Y-%m-%d')
        hour_int = int(hour)
        if hour_int < 0 or hour_int > 23:
            return None, "hour must be 0-23"
        am_pm = 'AM' if hour_int < 12 else 'PM'
        display_hour = hour_int if hour_int <= 12 else hour_int - 12
        if display_hour == 0:
            display_hour = 12
        # e.g. "Mon, Mar 9 · 3:00 PM"
        time_str = dt.strftime('%a, %b %-d') + f' \u00b7 {display_hour}:00 {am_pm}'
    except (ValueError, TypeError):
        return None, "Invalid date or hour"

    def _confirm(entity):
        entity['scheduled_time'] = time_str
        entity['status'] = 'meeting_confirmed'

    _, updated = transactional_pod_update(pod_id, _confirm)

    # Post system chat message
    create_chat_message(
        pod_id, user_id,
        f'\U0001f4c5 Time confirmed: {time_str}',
        message_type='system',
    )

    return updated, None
