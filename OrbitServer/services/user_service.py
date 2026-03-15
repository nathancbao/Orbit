import logging

from OrbitServer.models.models import get_user, update_user, delete_user, COLLEGE_YEARS
from OrbitServer.services.storage_service import upload_file

logger = logging.getLogger(__name__)


PROFILE_FIELDS = [
    'name', 'college_year', 'interests', 'photo', 'trust_score', 'email',
    'gallery_photos', 'bio', 'links', 'gender', 'mbti',
]

DEFAULT_PROFILE = {
    'name': '',
    'college_year': '',
    'interests': [],
    'photo': None,
    'trust_score': 0.0,
    'email': '',
    'gallery_photos': [],
    'bio': '',
    'links': [],
    'gender': '',
    'mbti': '',
}


def _format_profile(raw):
    """Extract only the app-relevant profile fields from a raw User dict."""
    profile = {}
    for field in PROFILE_FIELDS:
        if field in raw:
            profile[field] = raw[field]
        else:
            profile[field] = DEFAULT_PROFILE.get(field)
    return profile


def _is_profile_complete(profile):
    """A profile is complete when it has a name, valid college_year, and >=3 interests."""
    name = profile.get('name', '')
    college_year = profile.get('college_year', '')
    interests = profile.get('interests', [])
    return (
        bool(name and isinstance(name, str) and name.strip()) and
        bool(college_year and college_year in COLLEGE_YEARS) and
        len(interests) >= 3
    )


def get_user_profile(user_id):
    user_data = get_user(user_id)
    if not user_data:
        return None, "User not found"

    profile = _format_profile(user_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def update_user_profile(user_id, data):
    user = get_user(user_id)
    if user and user.get('email'):
        data['email'] = user['email']

    user_data = update_user(user_id, data)
    profile = _format_profile(user_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def upload_photo(user_id, file):
    try:
        url = upload_file(file, folder='profile_photos')
    except ValueError as e:
        return None, str(e)
    except RuntimeError as e:
        return None, str(e)

    user_data = update_user(user_id, {'photo': url})
    profile = _format_profile(user_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def upload_gallery_photo(user_id, file):
    user = get_user(user_id)
    if not user:
        return None, "User not found"

    gallery = list(user.get('gallery_photos') or [])
    if len(gallery) >= 6:
        return None, "Maximum 6 gallery photos allowed"

    try:
        url = upload_file(file, folder='gallery_photos')
    except ValueError as e:
        return None, str(e)
    except RuntimeError as e:
        return None, str(e)

    gallery.append(url)
    user_data = update_user(user_id, {'gallery_photos': gallery})
    profile = _format_profile(user_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def remove_gallery_photo(user_id, index):
    user = get_user(user_id)
    if not user:
        return None, "User not found"

    gallery = list(user.get('gallery_photos') or [])
    if index < 0 or index >= len(gallery):
        return None, "Invalid photo index"

    gallery.pop(index)
    user_data = update_user(user_id, {'gallery_photos': gallery})
    profile = _format_profile(user_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def delete_user_account(user_id):
    """Permanently delete a user and all associated data."""
    from OrbitServer.models.models import (
        get_user_pods, delete_pod, delete_mission, delete_signal,
        list_friendships, delete_friendship,
        list_incoming_friend_requests, list_outgoing_friend_requests,
        delete_friend_request, list_signals_for_user,
    )
    from OrbitServer.services.pod_service import transactional_pod_update

    user = get_user(user_id)
    if not user:
        return None, "User not found"

    uid = int(user_id)

    # 1. Remove user from all pods they belong to
    try:
        pods = get_user_pods(uid)
        for pod in pods:
            pod_id = pod['id']
            member_ids = pod.get('member_ids') or []
            remaining = [m for m in member_ids if m != uid]
            if not remaining:
                delete_pod(pod_id)
            else:
                def _remove(entity, _uid=uid):
                    entity['member_ids'] = [m for m in (entity.get('member_ids') or []) if m != _uid]
                    if len(entity['member_ids']) < entity.get('max_size', 4):
                        entity['status'] = 'open'
                transactional_pod_update(pod_id, _remove)
    except Exception:
        logger.exception("Error cleaning up pods for user %s", user_id)

    # 2. Delete all friendships (both directions) and friend requests
    try:
        from OrbitServer.models.models import client as ds_client
        from google.cloud.datastore.query import PropertyFilter

        # Delete friendships where user is user_id
        for fs in list_friendships(uid):
            delete_friendship(fs['id'])
        # Delete reverse friendships where user is friend_id
        reverse_query = ds_client.query(kind='Friendship')
        reverse_query.add_filter(filter=PropertyFilter('friend_id', '=', uid))
        for entity in reverse_query.fetch(limit=500):
            ds_client.delete(entity.key)
        # Delete all friend requests involving user
        for req in list_incoming_friend_requests(uid):
            delete_friend_request(req['id'])
        for req in list_outgoing_friend_requests(uid):
            delete_friend_request(req['id'])
    except Exception:
        logger.exception("Error cleaning up friends for user %s", user_id)

    # 3. Delete signals (flex missions) created by this user
    try:
        for signal in list_signals_for_user(uid):
            delete_signal(signal['id'])
    except Exception:
        logger.exception("Error cleaning up signals for user %s", user_id)

    # 4. Delete set missions created by this user
    try:
        from OrbitServer.models.models import client, _entity_to_dict
        from google.cloud.datastore.query import PropertyFilter
        query = client.query(kind='Mission')
        query.add_filter(filter=PropertyFilter('creator_id', '=', uid))
        for entity in query.fetch(limit=500):
            mission = _entity_to_dict(entity)
            if mission:
                delete_mission(mission['id'])
    except Exception:
        logger.exception("Error cleaning up missions for user %s", user_id)

    # 5. Delete the user entity itself
    delete_user(uid)

    return True, None
