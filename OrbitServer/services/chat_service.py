import datetime

from OrbitServer.models.models import (
    get_pod, create_chat_message, list_chat_messages,
    get_chat_message, transactional_message_update, delete_chat_message,
    REACTION_TYPES,
    create_vote, get_vote, update_vote, list_votes_for_pod,
    update_pod, transactional_vote_update,
    dm_conversation_id, list_dm_conversations, get_user,
    get_user_pods,
)
from OrbitServer.models.models import find_friendship
from OrbitServer.utils.profanity import filter_message


def _parse_since(raw):
    """Parse an ISO-8601 'since' cursor (as emitted in created_at, e.g.
    '2026-05-26T12:34:56.789012Z') into a naive UTC datetime, or None if absent
    or malformed. Malformed values fall back to a full fetch rather than erroring.
    """
    if not raw:
        return None
    s = raw.strip()
    if s.endswith('Z'):
        s = s[:-1]
    try:
        dt = datetime.datetime.fromisoformat(s)
    except ValueError:
        return None
    # Match the naive-UTC form created_at is stored in.
    return dt.replace(tzinfo=None)


def get_messages(pod_id, requesting_user_id, since=None):
    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(requesting_user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"
    messages = list_chat_messages(pod_id, since=_parse_since(since))
    return messages, None


def send_message(pod_id, user_id, content):
    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"

    is_clean, reason = filter_message(content)
    if not is_clean:
        return None, reason

    msg = create_chat_message(pod_id, user_id, content.strip(), message_type='text')
    return msg, None


def _pod_leader_id(pod):
    """The pod leader is the first member in join order."""
    member_ids = pod.get('member_ids') or []
    return int(member_ids[0]) if member_ids else None


def _get_pod_message(pod_id, message_id, user_id):
    """Shared lookup: pod exists, requester is a member, message belongs to pod.
    Returns (pod, message, error_string)."""
    pod = get_pod(pod_id)
    if not pod:
        return None, None, "Pod not found"
    if int(user_id) not in (pod.get('member_ids') or []):
        return None, None, "You are not a member of this pod"
    msg = get_chat_message(message_id)
    if not msg or msg.get('pod_id') != str(pod_id):
        return None, None, "Message not found"
    return pod, msg, None


def react_to_message(pod_id, message_id, user_id, reaction):
    """Toggle a reaction (thumbs_up | thumbs_down | heart) on a message."""
    if reaction not in REACTION_TYPES:
        return None, f"reaction must be one of: {', '.join(REACTION_TYPES)}"

    _, msg, err = _get_pod_message(pod_id, message_id, user_id)
    if err:
        return None, err

    uid = int(user_id)

    def _toggle(entity):
        reactions = {r: [int(u) for u in (entity.get('reactions') or {}).get(r, [])]
                     for r in REACTION_TYPES}
        if uid in reactions[reaction]:
            reactions[reaction].remove(uid)
        else:
            reactions[reaction].append(uid)
        entity['reactions'] = reactions

    _, msg = transactional_message_update(message_id, _toggle)
    if msg is None:
        return None, "Message not found"
    return msg, None


def set_message_pinned(pod_id, message_id, user_id, pinned):
    """Pin or unpin a message. Only the pod leader may pin."""
    pod, msg, err = _get_pod_message(pod_id, message_id, user_id)
    if err:
        return None, err
    if _pod_leader_id(pod) != int(user_id):
        return None, "Only the pod leader can pin messages"

    def _set(entity):
        entity['pinned'] = bool(pinned)

    _, msg = transactional_message_update(message_id, _set)
    if msg is None:
        return None, "Message not found"
    return msg, None


def delete_message(pod_id, message_id, user_id):
    """Delete a message. Users can only delete their own messages."""
    _, msg, err = _get_pod_message(pod_id, message_id, user_id)
    if err:
        return False, err
    if int(msg.get('user_id', -1)) != int(user_id):
        return False, "You can only delete your own messages"
    delete_chat_message(message_id)
    return True, None


def create_poll(pod_id, user_id, vote_type, options):
    pod = get_pod(pod_id)
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
        f"\U0001f4ca New vote: pick a {vote_type}! Vote ID: {vote['id']}",
        message_type='vote_created',
    )
    return vote, None


def respond_to_vote(pod_id, vote_id, user_id, option_index):
    pod = get_pod(pod_id)
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
        update_pod(pod_id, {pod_field: close_result['winner']})
        create_chat_message(
            pod_id, user_id,
            f"Vote closed! {close_result['vote_type'].capitalize()} set to: {close_result['winner']}",
            message_type='vote_result',
        )

    return vote, None


def remove_vote(pod_id, vote_id, user_id):
    pod = get_pod(pod_id)
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

    uid_key = str(user_id)
    if uid_key not in (vote.get('votes') or {}):
        return None, "You have not voted yet"

    def _remove(entity):
        votes_map = dict(entity.get('votes') or {})
        votes_map.pop(uid_key, None)
        entity['votes'] = votes_map

    _, vote = transactional_vote_update(vote_id, _remove)
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
    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found"
    if int(requesting_user_id) not in (pod.get('member_ids') or []):
        return None, "You are not a member of this pod"
    return list_votes_for_pod(pod_id), None


# ── DM Functions ─────────────────────────────────────────────────────────────

def get_dm_messages(current_user_id, friend_id, since=None):
    """Return messages in a DM conversation. Both users must be friends."""
    if not find_friendship(current_user_id, friend_id):
        return None, "You are not friends with this user"
    conv_id = dm_conversation_id(current_user_id, friend_id)
    messages = list_chat_messages(conv_id, since=_parse_since(since))
    return messages, None


def send_dm_message(current_user_id, friend_id, content):
    """Send a DM to a friend."""
    if not find_friendship(current_user_id, friend_id):
        return None, "You are not friends with this user"

    is_clean, reason = filter_message(content)
    if not is_clean:
        return None, reason

    conv_id = dm_conversation_id(current_user_id, friend_id)
    msg = create_chat_message(conv_id, current_user_id, content.strip(), message_type='text')
    return msg, None


def get_dm_conversations(user_id):
    """Return list of DM conversations for this user, with last message and friend profile."""
    last_messages = list_dm_conversations(user_id)
    uid = int(user_id)
    result = []
    for msg in last_messages:
        conv_id = msg.get('pod_id', '')
        parts = conv_id.split('_')
        if len(parts) != 3:
            continue
        friend_id = int(parts[1]) if int(parts[2]) == uid else int(parts[2])
        friend = get_user(friend_id)
        result.append({
            'conversation_id': conv_id,
            'friend_id': friend_id,
            'friend_name': friend.get('name', '') if friend else '',
            'friend_photo': friend.get('photo') if friend else None,
            'last_message': msg.get('content', ''),
            'last_message_at': msg.get('created_at', ''),
            'last_message_user_id': msg.get('user_id'),
        })
    # Sort by most recent message first
    result.sort(key=lambda x: x['last_message_at'], reverse=True)
    return result, None


def get_pod_conversations(user_id):
    """Return a summary of each pod the user belongs to, with last message info."""
    pods = get_user_pods(user_id)
    result = []
    for pod in pods:
        pod_id = pod.get('id', '')
        all_msgs = list_chat_messages(pod_id, limit=200)
        last_msg = all_msgs[-1] if all_msgs else None
        result.append({
            'pod_id': pod_id,
            'pod_name': pod.get('name') or pod.get('mission_title') or '',
            'last_message': last_msg.get('content', '') if last_msg else '',
            'last_message_at': last_msg.get('created_at', '') if last_msg else '',
            'last_message_user_id': last_msg.get('user_id') if last_msg else None,
        })
    result.sort(key=lambda x: x['last_message_at'], reverse=True)
    return result, None
