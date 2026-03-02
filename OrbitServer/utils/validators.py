import re
import datetime

from OrbitServer.models.models import COLLEGE_YEARS


def validate_edu_email(email):
    if not email or not isinstance(email, str):
        return False, "Email is required"
    email = email.strip().lower()
    # Check max length (RFC 5321)
    if len(email) > 254:
        return False, "Email address too long"
    if not re.match(r'^[a-zA-Z0-9]([a-zA-Z0-9._%+-]*[a-zA-Z0-9])?@[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$', email):
        return False, "Invalid email format"
    # Reject consecutive dots
    if '..' in email:
        return False, "Invalid email format"
    if not email.endswith('.edu'):
        return False, "Only .edu email addresses are allowed"
    return True, email


def validate_profile_data(data):
    errors = []
    allowed_fields = {'name', 'college_year', 'interests', 'photo'}

    for key in data:
        if key not in allowed_fields:
            errors.append(f"Unknown field: {key}")

    if 'name' in data:
        name = data['name']
        if not isinstance(name, str) or len(name.strip()) < 1:
            errors.append("name must be a non-empty string")
        elif len(name) > 100:
            errors.append("name must be 100 characters or fewer")

    if 'college_year' in data:
        year = data['college_year']
        if year not in COLLEGE_YEARS:
            errors.append(f"college_year must be one of: {', '.join(sorted(COLLEGE_YEARS))}")

    if 'interests' in data:
        if not isinstance(data['interests'], list):
            errors.append("interests must be a list")
        elif len(data['interests']) < 3:
            errors.append("At least 3 interests are required")
        elif len(data['interests']) > 10:
            errors.append("Maximum 10 interests allowed")

    if 'photo' in data:
        if data['photo'] is not None and not isinstance(data['photo'], str):
            errors.append("photo must be a URL string or null")

    if errors:
        return False, errors
    return True, None


def validate_mission_data(data, is_update=False):
    errors = []

    if not is_update:
        required = ['title', 'description']
        for field in required:
            if field not in data or not data[field]:
                errors.append(f"{field} is required")

    if 'title' in data and isinstance(data['title'], str):
        if len(data['title']) > 200:
            errors.append("title must be 200 characters or fewer")

    if 'description' in data and isinstance(data['description'], str):
        if len(data['description']) > 2000:
            errors.append("description must be 2000 characters or fewer")

    if 'tags' in data:
        if not isinstance(data['tags'], list):
            errors.append("tags must be a list")
        elif len(data['tags']) > 10:
            errors.append("Maximum 10 tags allowed")

    if 'max_pod_size' in data:
        try:
            size = int(data['max_pod_size'])
            if size < 2 or size > 10:
                errors.append("max_pod_size must be between 2 and 10")
        except (TypeError, ValueError):
            errors.append("max_pod_size must be an integer")

    if 'date' in data and data.get('date'):
        try:
            datetime.date.fromisoformat(data['date'])
        except ValueError:
            errors.append("date must be a valid date in YYYY-MM-DD format")

    if errors:
        return False, errors
    return True, None


# ── Signal validation ────────────────────────────────────────────────────────
# Must match Swift ActivityCategory raw values exactly:
#   case sports  = "Sports"
#   case food    = "Food"
#   case movies  = "Movies"
#   case hangout = "Hangout"
#   case study   = "Study"
#   case custom  = "Custom"

_ACTIVITY_CATEGORIES = {
    'Sports', 'Food', 'Movies', 'Hangout', 'Study', 'Custom',
}

_TIME_BLOCKS = {'morning', 'afternoon', 'evening'}


def validate_signal_data(data):
    errors = []

    category = data.get('activity_category')
    if not category or category not in _ACTIVITY_CATEGORIES:
        errors.append(f"activity_category must be one of: {', '.join(sorted(_ACTIVITY_CATEGORIES))}")

    if category == 'Custom':
        name = data.get('custom_activity_name', '')
        if not name or not isinstance(name, str) or not name.strip():
            errors.append("custom_activity_name is required for Custom activities")
        elif len(name) > 100:
            errors.append("custom_activity_name must be 100 characters or fewer")

    desc = data.get('description', '')
    if isinstance(desc, str) and desc.strip():
        word_count = len(desc.split())
        if word_count > 250:
            errors.append("description must be 250 words or fewer")

    links = data.get('links')
    if links is not None:
        if not isinstance(links, list):
            errors.append("links must be a list of URL strings")
        elif len(links) > 2:
            errors.append("Maximum 2 links allowed")
        else:
            for link in links:
                if not isinstance(link, str):
                    errors.append("Each link must be a string")
                    break
                if len(link) > 500:
                    errors.append("Each link must be 500 characters or fewer")
                    break

    try:
        min_gs = int(data['min_group_size'])
        max_gs = int(data['max_group_size'])
        if min_gs < 3:
            errors.append("min_group_size must be at least 3")
        if max_gs > 8:
            errors.append("max_group_size must be at most 8")
        if min_gs > max_gs:
            errors.append("min_group_size cannot exceed max_group_size")
    except (KeyError, TypeError, ValueError):
        errors.append("min_group_size and max_group_size must be integers")

    availability = data.get('availability')
    if not isinstance(availability, list) or len(availability) == 0:
        errors.append("availability must be a non-empty list of {date, time_blocks} slots")
    else:
        for slot in availability:
            if not isinstance(slot, dict):
                errors.append("Each availability slot must be an object with 'date' and 'time_blocks'")
                break
            if not slot.get('date'):
                errors.append("Each availability slot must have a 'date' field (ISO 8601 string)")
                break
            tbs = slot.get('time_blocks', [])
            if not isinstance(tbs, list) or len(tbs) == 0:
                errors.append("Each availability slot must have at least one time_block")
                break
            invalid = [tb for tb in tbs if tb not in _TIME_BLOCKS]
            if invalid:
                errors.append(f"Invalid time_block(s): {invalid}. Must be morning, afternoon, or evening")
                break

    if errors:
        return False, errors
    return True, None


def validate_message_data(data):
    errors = []
    content = data.get('content', '')
    if not content or not isinstance(content, str):
        errors.append("content is required")
    elif len(content.strip()) == 0:
        errors.append("content cannot be empty")
    elif len(content) > 1000:
        errors.append("content must be 1000 characters or fewer")
    if errors:
        return False, errors
    return True, None


def validate_vote_data(data):
    errors = []
    if 'vote_type' not in data or data['vote_type'] not in ('time', 'place'):
        errors.append("vote_type must be 'time' or 'place'")
    options = data.get('options', [])
    if not isinstance(options, list) or len(options) < 2:
        errors.append("options must be a list with at least 2 items")
    elif len(options) > 4:
        errors.append("Maximum 4 options allowed")
    if errors:
        return False, errors
    return True, None
