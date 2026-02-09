from OrbitServer.models.models import get_profile, _entity_to_dict, list_crews, list_missions


# Fields that match the Swift Profile struct
PROFILE_FIELDS = [
    'name', 'age', 'location', 'bio', 'photos', 'interests',
    'personality', 'social_preferences', 'friendship_goals',
]

DEFAULT_PROFILE = {
    'name': '',
    'age': 18,
    'location': {'city': '', 'state': '', 'coordinates': None},
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


def suggested_users(user_id):
    profile = get_profile(user_id)
    user_interests = set(profile.get('interests', [])) if profile else set()

    from google.cloud import datastore
    client = datastore.Client()
    query = client.query(kind='Profile')
    all_profiles = list(query.fetch(limit=50))

    suggestions = []
    for p in all_profiles:
        p_dict = _entity_to_dict(p)
        if p_dict.get('user_id') == int(user_id):
            continue
        # Only include profiles that have a name set
        if not p_dict.get('name'):
            continue
        other_interests = set(p_dict.get('interests', []))
        # Jaccard similarity: |A ∩ B| / |A ∪ B|
        union = user_interests | other_interests
        score = len(user_interests & other_interests) / len(union) if union else 0.0
        formatted = _format_profile(p_dict)
        formatted['match_score'] = round(score, 4)
        suggestions.append((score, formatted))

    suggestions.sort(key=lambda x: x[0], reverse=True)
    return [s[1] for s in suggestions[:20]]


def suggested_crews(user_id):
    profile = get_profile(user_id)
    user_interests = set(profile.get('interests', [])) if profile else set()

    crews = list_crews()

    suggestions = []
    for crew in crews:
        crew_tags = set(crew.get('tags', []))
        overlap = len(user_interests & crew_tags)
        crew['match_score'] = overlap
        suggestions.append(crew)

    suggestions.sort(key=lambda x: x['match_score'], reverse=True)
    return suggestions[:20]


def suggested_missions(user_id):
    profile = get_profile(user_id)
    user_interests = set(profile.get('interests', [])) if profile else set()

    missions = list_missions()

    suggestions = []
    for mission in missions:
        mission_tags = set(mission.get('tags', []))
        overlap = len(user_interests & mission_tags)
        mission['match_score'] = overlap
        suggestions.append(mission)

    suggestions.sort(key=lambda x: x['match_score'], reverse=True)
    return suggestions[:20]
