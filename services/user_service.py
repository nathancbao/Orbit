from models.models import get_profile, upsert_profile, get_user
from services.storage_service import upload_file


# Fields that match the Swift Profile struct
PROFILE_FIELDS = [
    'name', 'age', 'location', 'bio', 'photos', 'interests',
    'personality', 'social_preferences', 'friendship_goals',
]

# Default empty profile matching Swift's Profile struct
DEFAULT_PROFILE = {
    'name': '',
    'age': 18,
    'location': {
        'city': '',
        'state': '',
        'coordinates': None,
    },
    'bio': '',
    'photos': [],
    'interests': [],
    'personality': {
        'introvert_extrovert': 0.5,
        'spontaneous_planner': 0.5,
        'active_relaxed': 0.5,
    },
    'social_preferences': {
        'group_size': 'Small groups (3-5)',
        'meeting_frequency': 'Weekly',
        'preferred_times': [],
    },
    'friendship_goals': [],
}


def _format_profile(raw):
    """Extract only the Swift Profile fields from a raw Datastore profile dict."""
    profile = {}
    for field in PROFILE_FIELDS:
        if field in raw:
            profile[field] = raw[field]
        else:
            profile[field] = DEFAULT_PROFILE.get(field)
    return profile


def _is_profile_complete(profile):
    """Check if a profile has the minimum required fields filled in."""
    name = profile.get('name', '')
    interests = profile.get('interests', [])
    social_prefs = profile.get('social_preferences', {})
    preferred_times = (
        social_prefs.get('preferred_times', [])
        if isinstance(social_prefs, dict) else []
    )
    return (
        bool(name and isinstance(name, str) and name.strip()) and
        len(interests) >= 3 and
        bool(preferred_times)
    )


def get_user_profile(user_id):
    profile_data = get_profile(user_id)
    if not profile_data:
        user = get_user(user_id)
        if not user:
            return None, "User not found"
        # No profile saved yet -- return 404 so the Swift client's
        # loadExistingProfile() catch block routes to .profileSetup
        return None, "Profile not found"

    profile = _format_profile(profile_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None


def update_user_profile(user_id, data):
    # Attach the user's email to the Profile entity in Datastore
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
    # Get existing profile, add photo URL to photos list
    existing = get_profile(user_id)
    photos = existing.get('photos', []) if existing else []
    photos.append(url)
    profile_data = upsert_profile(user_id, {'photos': photos})
    profile = _format_profile(profile_data)
    return {
        'profile': profile,
        'profile_complete': _is_profile_complete(profile),
    }, None
