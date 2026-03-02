from OrbitServer.models.models import (
    create_mission, get_mission, delete_mission,
    list_missions_for_user, list_all_missions,
    transactional_mission_rsvp, list_rsvped_missions,
    create_signal_pod, get_event_pod, transactional_pod_update,
)


def create_new_mission(data, creator_id):
    """Create and persist an activity-request mission. Returns (mission, None)."""
    mission = create_mission(data, creator_id)
    return mission, None


def get_all_missions(user_id=None):
    """Return all missions, newest first (for discover feed). Returns (list, None)."""
    missions = list_all_missions()
    if user_id is not None:
        _resolve_pod_ids(missions, user_id)
    return missions, None


def get_user_missions(user_id):
    """Return all missions posted by a user, newest first. Returns (list, None)."""
    missions = list_missions_for_user(user_id)
    _resolve_pod_ids(missions, user_id)
    return missions, None


def get_rsvped_missions(user_id):
    """Return all missions the user has RSVP'd to. pod_id always included."""
    missions = list_rsvped_missions(user_id)
    _resolve_pod_ids(missions, user_id)
    return missions, None


def remove_mission(mission_id, user_id):
    """
    Delete a mission if the requesting user owns it.
    Returns (success, error_message, status_code).
    status_code is None on success.
    """
    mission = get_mission(mission_id)
    if not mission:
        return False, "Mission not found", 404
    if mission.get('creator_id') != int(user_id):
        return False, "Only the creator can delete this mission", 403
    delete_mission(mission_id)
    return True, None, None


def rsvp_mission(mission_id, user_id):
    """RSVP to a signal and create/join its pod. Returns (mission_dict, error_string)."""
    mission, err = transactional_mission_rsvp(mission_id, user_id)
    if err:
        return mission, err

    # Determine which pod this user belongs to
    pod_id = _user_pod_id(mission, user_id)
    if pod_id:
        pod = get_event_pod(pod_id)
        if not pod:
            max_size = int(mission.get('max_group_size', 6))
            create_signal_pod(pod_id, mission_id, max_size, user_id)
        else:
            uid = int(user_id)
            if uid not in (pod.get('member_ids') or []):
                _add_member_to_pod(pod_id, user_id, pod.get('max_size', 6))

    # Return pod_id (singular) for frontend convenience
    mission['pod_id'] = pod_id
    return mission, None


def _user_pod_id(mission, user_id):
    """Return the pod_id for the pod the user is assigned to, or None."""
    rsvps = mission.get('rsvps') or []
    pod_ids = mission.get('pod_ids') or []
    uid = int(user_id)
    if uid not in rsvps or not pod_ids:
        return None
    idx = rsvps.index(uid)
    max_gs = int(mission.get('max_group_size', 6))
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


def _resolve_pod_ids(missions, user_id):
    """Replace pod_ids list with a single pod_id for the requesting user's pod.

    If the user is in a pod, sets pod_id to their specific pod.
    Otherwise, removes pod-related fields from the response.
    """
    uid = int(user_id)
    for m in missions:
        user_pod = _user_pod_id(m, user_id)
        # Clean internal pod_ids from response; expose only pod_id
        m.pop('pod_ids', None)
        if user_pod:
            m['pod_id'] = user_pod
        else:
            m.pop('pod_id', None)
