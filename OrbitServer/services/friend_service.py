from OrbitServer.models.models import (
    get_user, search_users,
    create_friend_request, get_friend_request, update_friend_request_status,
    list_incoming_friend_requests, list_outgoing_friend_requests,
    find_pending_request,
    create_friendship, get_friendship, list_friendships,
    find_friendship, delete_friendship,
)


def _friend_profile(user):
    """Extract the lightweight profile shape used in friend responses."""
    if not user:
        return None
    return {
        'user_id': user.get('id'),
        'name': user.get('name', ''),
        'college_year': user.get('college_year', ''),
        'interests': user.get('interests', []),
        'photo': user.get('photo'),
        'bio': user.get('bio', ''),
    }


# ── GET /friends/search ───────────────────────────────────────────────────────

def search_friends(query_str, current_user_id):
    """Search for users by email or name, excluding the authenticated user."""
    if not query_str or len(query_str) < 3:
        return None, "Query must be at least 3 characters"

    users = search_users(query_str, exclude_user_id=current_user_id, limit=20)
    return [_friend_profile(u) for u in users], None


# ── GET /friends ──────────────────────────────────────────────────────────────

def get_friends(user_id):
    """Return all accepted friends with enriched profiles."""
    friendships = list_friendships(user_id)
    for f in friendships:
        friend = get_user(int(f['friend_id']))
        f['friend'] = _friend_profile(friend)
    return friendships, None


# ── POST /friends/requests ────────────────────────────────────────────────────

def send_friend_request(from_user_id, to_user_id):
    if int(from_user_id) == int(to_user_id):
        return None, "Cannot send a friend request to yourself"

    # Already friends?
    if find_friendship(from_user_id, to_user_id):
        return None, "You are already friends with this user"

    # Pending request in either direction?
    if find_pending_request(from_user_id, to_user_id):
        return None, "A pending friend request already exists"
    if find_pending_request(to_user_id, from_user_id):
        return None, "This user has already sent you a friend request"

    # Validate target exists
    target = get_user(int(to_user_id))
    if not target:
        return None, "User not found"

    req = create_friend_request(from_user_id, to_user_id)
    req['from_user'] = _friend_profile(get_user(int(from_user_id)))
    req['to_user'] = _friend_profile(target)
    return req, None


# ── GET /friends/requests/incoming ────────────────────────────────────────────

def get_incoming_requests(user_id):
    requests = list_incoming_friend_requests(user_id)
    for r in requests:
        r['from_user'] = _friend_profile(get_user(int(r['from_user_id'])))
    return requests, None


# ── GET /friends/requests/outgoing ────────────────────────────────────────────

def get_outgoing_requests(user_id):
    requests = list_outgoing_friend_requests(user_id)
    for r in requests:
        r['to_user'] = _friend_profile(get_user(int(r['to_user_id'])))
    return requests, None


# ── POST /friends/requests/<id>/accept ────────────────────────────────────────

def accept_friend_request(request_id, user_id):
    req = get_friend_request(request_id)
    if not req:
        return None, "Friend request not found", 404
    if int(req['to_user_id']) != int(user_id):
        return None, "Not your friend request", 403
    if req['status'] != 'pending':
        return None, "Request is no longer pending", 409

    update_friend_request_status(request_id, 'accepted')

    # Create bidirectional friendships
    friendship = create_friendship(req['from_user_id'], req['to_user_id'])
    create_friendship(req['to_user_id'], req['from_user_id'])

    friend = get_user(int(req['from_user_id']))
    friendship['friend'] = _friend_profile(friend)
    return friendship, None, None


# ── POST /friends/requests/<id>/decline ───────────────────────────────────────

def decline_friend_request(request_id, user_id):
    req = get_friend_request(request_id)
    if not req:
        return None, "Friend request not found", 404
    if int(req['to_user_id']) != int(user_id):
        return None, "Not your friend request", 403
    if req['status'] != 'pending':
        return None, "Request is no longer pending", 409

    update_friend_request_status(request_id, 'declined')
    return {}, None, None


# ── DELETE /friends/<id> ──────────────────────────────────────────────────────

def remove_friend(friendship_id, user_id):
    friendship = get_friendship(friendship_id)
    if not friendship:
        return None, "Friendship not found", 404
    if int(friendship['user_id']) != int(user_id):
        return None, "Not your friendship", 403

    # Delete both directions
    reverse = find_friendship(friendship['friend_id'], friendship['user_id'])
    delete_friendship(friendship_id)
    if reverse:
        delete_friendship(int(reverse['id']))

    return {}, None, None


# ── GET /friends/status/<user_id> ─────────────────────────────────────────────

def get_friendship_status(current_user_id, target_user_id):
    # Already friends?
    if find_friendship(current_user_id, target_user_id):
        return {'status': 'friends', 'request_id': None}, None

    # Current user sent a request?
    sent = find_pending_request(current_user_id, target_user_id)
    if sent:
        return {'status': 'pending_sent', 'request_id': sent['id']}, None

    # Target user sent a request?
    received = find_pending_request(target_user_id, current_user_id)
    if received:
        return {'status': 'pending_received', 'request_id': received['id']}, None

    return {'status': 'none', 'request_id': None}, None
