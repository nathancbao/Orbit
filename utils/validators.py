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
        'name', 'age', 'location', 'bio', 'photos', 'interests',
        'personality', 'social_preferences', 'friendship_goals',
    }

    for key in data:
        if key not in allowed_fields:
            errors.append(f"Unknown field: {key}")

    if 'name' in data:
        name = data['name']
        if not isinstance(name, str) or len(name.strip()) < 1:
            errors.append("name must be a non-empty string")
        elif len(name) > 100:
            errors.append("name must be 100 characters or fewer")

    if 'age' in data:
        age = data['age']
        if not isinstance(age, (int, float)) or int(age) < 18 or int(age) > 100:
            errors.append("age must be a number between 18 and 100")

    if 'bio' in data:
        if not isinstance(data['bio'], str):
            errors.append("bio must be a string")
        elif len(data['bio']) > 500:
            errors.append("bio must be 500 characters or fewer")

    if 'interests' in data:
        if not isinstance(data['interests'], list):
            errors.append("interests must be a list")
        elif len(data['interests']) > 10:
            errors.append("Maximum 10 interests allowed")

    if 'photos' in data:
        if not isinstance(data['photos'], list):
            errors.append("photos must be a list")
        elif len(data['photos']) > 6:
            errors.append("Maximum 6 photos allowed")

    if 'location' in data:
        if not isinstance(data['location'], dict):
            errors.append("location must be an object")

    if 'personality' in data:
        if not isinstance(data['personality'], dict):
            errors.append("personality must be an object")

    if 'social_preferences' in data:
        if not isinstance(data['social_preferences'], dict):
            errors.append("social_preferences must be an object")

    if 'friendship_goals' in data:
        if not isinstance(data['friendship_goals'], list):
            errors.append("friendship_goals must be a list")

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
