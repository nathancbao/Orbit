from models.models import get_profile, upsert_profile, get_user
from services.storage_service import upload_file


def _default_profile(user_id):
    """Return empty profile structure matching iOS client expectations"""
    return {
        'name': '',
        'age': 18,
        'location': {
            'city': '',
            'state': '',
            'coordinates': None
        },
        'bio': '',
        'photos': [],
        'interests': [],
        'personality': {
            'introvert_extrovert': 0.5,
            'spontaneous_planner': 0.5,
            'active_relaxed': 0.5
        },
        'social_preferences': {
            'group_size': 'Small groups (3-5)',
            'meeting_frequency': 'Weekly',
            'preferred_times': []
        },
        'friendship_goals': []
    }


def _is_profile_complete(profile):
    """Check if profile has required fields filled out"""
    if not profile:
        return False
    return bool(
        profile.get('name') and
        profile.get('age') and
        profile.get('location', {}).get('city') and
        profile.get('location', {}).get('state') and
        len(profile.get('interests', [])) >= 3
    )


def get_user_profile(user_id):
    user = get_user(user_id)
    if not user:
        return None, "User not found"

    profile = get_profile(user_id)
    if not profile:
        profile = _default_profile(user_id)

    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile)
    }, None


def update_user_profile(user_id, data):
    profile = upsert_profile(user_id, data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile)
    }, None


def upload_photo(user_id, file):
    url = upload_file(file, folder='profile_photos')
    # Get current profile and add photo to photos array
    profile = get_profile(user_id) or _default_profile(user_id)
    photos = profile.get('photos', [])
    photos.append(url)
    profile = upsert_profile(user_id, {'photos': photos})
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile)
    }, None
