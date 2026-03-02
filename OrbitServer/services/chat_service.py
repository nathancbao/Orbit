import datetime

from OrbitServer.models.models import (
    get_event_pod, create_chat_message, list_chat_messages,
    create_vote, get_vote, update_vote, list_votes_for_pod,
    update_event_pod, transactional_vote_update,
)
from OrbitServer.utils.profanity import filter_message


def get_messages(pod_id, requesting_user_id):
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(requesting_user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"
    messages = list_chat_messages(pod_id)
    return messages, None


def send_message(pod_id, user_id, content):
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"

    is_clean, reason = filter_message(content)
    if not is_clean:
        return None, reason

    msg = create_chat_message(pod_id, user_id, content.strip(), message_type='text')

    from OrbitServer.services.notification_service import notify_chat_message
    notify_chat_message(pod_id, user_id, content[:100])

    return msg, None


def create_poll(pod_id, user_id, vote_type, options):
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    member_ids = pod.get('member_ids') or []
    if int(user_id) not in member_ids:
        return None, "You are not a member of this pod"

    # Only one open vote of each type at a time
    existing_votes = list_votes_for_pod(pod_id)
    for v in existing_votes:
        if v['vote_type'] == vote_type and v['status'] == 'open':
            return None, f"There is already an open {vote_type} vote for this pod"

    # Store expected voter count at creation time to avoid race conditions
    vote = create_vote(pod_id, user_id, vote_type, options, expected_voters=len(member_ids))

    # Post a system message announcing the vote
    create_chat_message(
        pod_id, user_id,
        f"📊 New vote: pick a {vote_type}! Vote ID: {vote['id']}",
        message_type='vote_created',
    )
    return vote, None


def respond_to_vote(pod_id, vote_id, user_id, option_index):
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    member_ids = pod.get('member_ids') or []
    if int(user_id) not in member_ids:
        return None, "You are not a member of this pod"

    vote = get_vote(vote_id)
    if not vote or vote['pod_id'] != str(pod_id):
        return None, "Vote not found"
    if vote['status'] == 'closed':
        return None, "This vote is already closed"

    options = vote.get('options') or []
    if not isinstance(option_index, int) or option_index < 0 or option_index >= len(options):
        return None, "Invalid option index"

    # Use a transaction to prevent concurrent vote overwrites
    close_result = {'should_close': False, 'winner': None, 'vote_type': vote.get('vote_type')}

    def _apply_vote(entity):
        votes_map = dict(entity.get('votes') or {})
        votes_map[str(user_id)] = option_index
        entity['votes'] = votes_map

        # Auto-close when all expected voters have voted
        # Use expected_voters from vote creation time to avoid race conditions
        expected_voters = entity.get('expected_voters') or len(member_ids)
        if len(votes_map) >= expected_voters:
            opts = entity.get('options') or []
            winner, _ = _tally_votes(votes_map, opts)
            entity['status'] = 'closed'
            entity['result'] = winner
            entity['closed_at'] = datetime.datetime.utcnow()
            close_result['should_close'] = True
            close_result['winner'] = winner

    _, vote = transactional_vote_update(vote_id, _apply_vote)

    if close_result['should_close']:
        pod_field = 'scheduled_time' if close_result['vote_type'] == 'time' else 'scheduled_place'
        update_event_pod(pod_id, {pod_field: close_result['winner']})
        create_chat_message(
            pod_id, user_id,
            f"Vote closed! {close_result['vote_type'].capitalize()} set to: {close_result['winner']}",
            message_type='vote_result',
        )

    return vote, None


def _tally_votes(votes_map, options):
    """Return (winning_option_string, winning_index) by plurality.
    Returns (None, -1) if no valid votes or empty options.
    """
    if not options:
        return None, -1
    counts = [0] * len(options)
    for option_index in votes_map.values():
        if 0 <= option_index < len(options):
            counts[option_index] += 1
    max_count = max(counts)
    if max_count == 0:
        # No valid votes - default to first option
        return options[0], 0
    winning_index = counts.index(max_count)
    return options[winning_index], winning_index


def get_votes_for_pod(pod_id, requesting_user_id):
    pod = get_event_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(requesting_user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"
    return list_votes_for_pod(pod_id), None
