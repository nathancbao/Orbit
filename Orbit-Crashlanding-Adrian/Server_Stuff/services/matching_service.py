from models.models import get_profile, list_crews, list_missions


def suggested_users(user_id):
    profile = get_profile(user_id)
    user_interests = set(profile.get('interests', [])) if profile else set()

    from google.cloud import datastore
    client = datastore.Client()
    query = client.query(kind='Profile')
    all_profiles = list(query.fetch(limit=50))

    suggestions = []
    for p in all_profiles:
        p_dict = dict(p)
        p_dict['id'] = p.key.id_or_name
        if p_dict.get('user_id') == int(user_id):
            continue
        other_interests = set(p_dict.get('interests', []))
        overlap = len(user_interests & other_interests)
        p_dict['match_score'] = overlap
        suggestions.append(p_dict)

    suggestions.sort(key=lambda x: x['match_score'], reverse=True)
    return suggestions[:20]


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
