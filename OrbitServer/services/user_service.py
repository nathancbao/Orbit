from OrbitServer.models.models import get_user, update_user, COLLEGE_YEARS
from OrbitServer.services.storage_service import upload_file


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
