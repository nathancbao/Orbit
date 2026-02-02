from models.models import get_profile, upsert_profile, get_user
from services.storage_service import upload_file


def get_user_profile(user_id):
    profile = get_profile(user_id)
    if not profile:
        user = get_user(user_id)
        if not user:
            return None, "User not found"
        return {
            'user_id': int(user_id),
            'email': user.get('email'),
            'display_name': None,
            'bio': None,
            'major': None,
            'graduation_year': None,
            'interests': [],
            'photo_url': None,
        }, None

    return profile, None


def update_user_profile(user_id, data):
    profile = upsert_profile(user_id, data)
    return profile, None


def upload_photo(user_id, file):
    url = upload_file(file, folder='profile_photos')
    profile = upsert_profile(user_id, {'photo_url': url})
    return profile, None
