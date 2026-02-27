from OrbitServer.models.models import get_profile, upsert_profile, get_user, COLLEGE_YEARS
from OrbitServer.services.storage_service import upload_file


PROFILE_FIELDS = ['name', 'college_year', 'interests', 'photo', 'trust_score', 'email']

DEFAULT_PROFILE = {
    'name': '',
    'college_year': '',
    'interests': [],
    'photo': None,
    'trust_score': 0.0,
    'email': '',
}


def _format_profile(raw):
    """Extract only the app Profile fields from a raw Datastore profile dict."""
    profile = {}
    for field in PROFILE_FIELDS:
        if field in raw:
            profile[field] = raw[field]
        else:
            profile[field] = DEFAULT_PROFILE.get(field)
    return profile


def _is_profile_complete(profile):
    """A profile is complete when it has a name, valid college_year, and ≥3 interests."""
    name = profile.get('name', '')
    college_year = profile.get('college_year', '')
    interests = profile.get('interests', [])
    return (
        bool(name and isinstance(name, str) and name.strip()) and
        bool(college_year and college_year in COLLEGE_YEARS) and
        len(interests) >= 3
    )


def get_user_profile(user_id):
    profile_data = get_profile(user_id)
    if not profile_data:
        user = get_user(user_id)
        if not user:
            return None, "User not found"
        return None, "Profile not found"

    profile = _format_profile(profile_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def update_user_profile(user_id, data):
    user = get_user(user_id)
    if user and user.get('email'):
        data['email'] = user['email']

    profile_data = upsert_profile(user_id, data)
    profile = _format_profile(profile_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def upload_photo(user_id, file):
    url = upload_file(file, folder='profile_photos')
    profile_data = upsert_profile(user_id, {'photo': url})
    profile = _format_profile(profile_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None
