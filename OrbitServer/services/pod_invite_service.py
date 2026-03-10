from OrbitServer.models.models import (
    get_pod, get_user, update_pod,
    create_pod_invite, get_pod_invite, update_pod_invite_status,
    list_incoming_pod_invites, find_pending_pod_invite,
    find_friendship, transactional_pod_update, record_action,
)


def send_pod_invite(pod_id, from_user_id, to_user_id):
    """Invite a friend to a pod. Validates membership, friendship, capacity."""
    pod = get_pod(pod_id)
    if not pod:
        return None, "Pod not found", 404

    member_ids = pod.get('member_ids') or []
    if int(from_user_id) not in member_ids:
        return None, "You are not a member of this pod", 403

    if int(to_user_id) in member_ids:
        return None, "User is already in this pod", 409

    if not find_friendship(from_user_id, to_user_id):
        return None, "You can only invite friends", 403

    if len(member_ids) >= pod.get('max_size', 4):
        return None, "Pod is full", 409

    if find_pending_pod_invite(pod_id, from_user_id, to_user_id):
        return None, "Invite already sent", 409

    invite = create_pod_invite(pod_id, from_user_id, to_user_id)
    # Enrich with from_user info
    from_user = get_user(int(from_user_id))
    invite['from_user'] = {
        'name': from_user.get('name', '') if from_user else '',
        'photo': from_user.get('photo') if from_user else None,
    }
    return invite, None, None


def accept_pod_invite(invite_id, user_id):
    """Accept a pod invite — adds user to pod transactionally."""
    invite = get_pod_invite(invite_id)
    if not invite:
        return None, "Invite not found", 404
    if int(invite['to_user_id']) != int(user_id):
        return None, "Not your invite", 403
    if invite['status'] != 'pending':
        return None, "Invite is no longer pending", 409

    pod_id = invite['pod_id']

    def _add_member(entity):
        member_ids = list(entity.get('member_ids') or [])
        uid = int(user_id)
        if uid in member_ids:
            return 'already_member'
        if len(member_ids) >= entity.get('max_size', 4):
            return 'full'
        member_ids.append(uid)
        entity['member_ids'] = member_ids
        if len(member_ids) >= entity.get('max_size', 4):
            entity['status'] = 'full'
        return 'added'

    result, pod = transactional_pod_update(pod_id, _add_member)
    if result is None:
        return None, "Pod not found", 404
    if result == 'already_member':
        update_pod_invite_status(invite_id, 'accepted')
        return pod, None, None
    if result == 'full':
        return None, "Pod is full", 409

    update_pod_invite_status(invite_id, 'accepted')

    # Record the join action so the mission shows in user's history
    mission_id = pod.get('mission_id') or pod.get('signal_id')
    if mission_id:
        record_action(user_id, mission_id, 'joined',
                      pod_id=pod['id'],
                      tags_snapshot=pod.get('tags') or [])

    return pod, None, None


def decline_pod_invite(invite_id, user_id):
    """Decline a pod invite."""
    invite = get_pod_invite(invite_id)
    if not invite:
        return None, "Invite not found", 404
    if int(invite['to_user_id']) != int(user_id):
        return None, "Not your invite", 403
    if invite['status'] != 'pending':
        return None, "Invite is no longer pending", 409

    update_pod_invite_status(invite_id, 'declined')
    return {}, None, None


def get_incoming_invites(user_id):
    """Return pending pod invites for this user, enriched with from_user + pod info."""
    invites = list_incoming_pod_invites(user_id)
    for inv in invites:
        from_user = get_user(int(inv['from_user_id']))
        inv['from_user'] = {
            'name': from_user.get('name', '') if from_user else '',
            'photo': from_user.get('photo') if from_user else None,
        }
        pod = get_pod(inv['pod_id'])
        inv['pod_name'] = pod.get('name') or '' if pod else ''
        inv['mission_title'] = pod.get('mission_title') or '' if pod else ''
        # Try to get the mission title if pod doesn't have it
        if pod and not inv['mission_title']:
            mission_id = pod.get('mission_id')
            if mission_id is not None:
                from OrbitServer.models.models import get_mission
                mission = get_mission(int(mission_id))
                inv['mission_title'] = mission.get('title', '') if mission else ''
    return invites, None
