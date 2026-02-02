import re


def validate_edu_email(email):
    if not email or not isinstance(email, str):
        return False, "Email is required"
    email = email.strip().lower()
    if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        return False, "Invalid email format"
    if not email.endswith('.edu'):
        return False, "Only .edu email addresses are allowed"
    return True, email


def validate_profile_data(data):
    errors = []
    allowed_fields = {
        'display_name', 'bio', 'major', 'graduation_year',
        'interests', 'photo_url'
    }
    for key in data:
        if key not in allowed_fields:
            errors.append(f"Unknown field: {key}")

    if 'display_name' in data:
        name = data['display_name']
        if not isinstance(name, str) or len(name.strip()) < 1:
            errors.append("display_name must be a non-empty string")
        elif len(name) > 100:
            errors.append("display_name must be 100 characters or fewer")

    if 'bio' in data:
        if not isinstance(data['bio'], str):
            errors.append("bio must be a string")
        elif len(data['bio']) > 500:
            errors.append("bio must be 500 characters or fewer")

    if 'interests' in data:
        if not isinstance(data['interests'], list):
            errors.append("interests must be a list")
        elif len(data['interests']) > 20:
            errors.append("Maximum 20 interests allowed")

    if errors:
        return False, errors
    return True, None


def validate_crew_data(data):
    errors = []
    required = ['name']
    for field in required:
        if field not in data or not data[field]:
            errors.append(f"{field} is required")

    if 'name' in data and isinstance(data['name'], str):
        if len(data['name']) > 100:
            errors.append("name must be 100 characters or fewer")

    if 'description' in data and isinstance(data['description'], str):
        if len(data['description']) > 500:
            errors.append("description must be 500 characters or fewer")

    if errors:
        return False, errors
    return True, None


def validate_mission_data(data):
    errors = []
    required = ['title', 'description']
    for field in required:
        if field not in data or not data[field]:
            errors.append(f"{field} is required")

    if 'title' in data and isinstance(data['title'], str):
        if len(data['title']) > 200:
            errors.append("title must be 200 characters or fewer")

    if errors:
        return False, errors
    return True, None
