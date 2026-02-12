import math

# Weights (must sum to 1.0)
W_INTEREST = 0.30
W_PERSONALITY = 0.30
W_SOCIAL = 0.20
W_GOALS = 0.20

# Defaults (mirror DEFAULT_PROFILE in matching_service.py)
DEFAULT_PERSONALITY = {
    "introvert_extrovert": 0.5,
    "spontaneous_planner": 0.5,
    "active_relaxed": 0.5,
}
DEFAULT_SOCIAL = {
    "group_size": "Small groups (3-5)",
    "meeting_frequency": "Weekly",
    "preferred_times": [],
}


# Interest scoring (Jaccard similarity)
def interest_score(interests_a, interests_b):
    set_a = set(interests_a)
    set_b = set(interests_b)
    union = set_a | set_b
    if not union:
        return 0.0
    return len(set_a & set_b) / len(union)


# ── Personality scoring (1 - normalized Euclidean distance) ────
# Each trait is 0-1, so max distance = sqrt(3). We invert so
# closer personalities yield a higher score.
_MAX_PERSONALITY_DIST = math.sqrt(3)

def personality_score(personality_a, personality_b):
    a = personality_a or DEFAULT_PERSONALITY
    b = personality_b or DEFAULT_PERSONALITY
    keys = ("introvert_extrovert", "spontaneous_planner", "active_relaxed")
    sq_sum = sum((a.get(k, 0.5) - b.get(k, 0.5)) ** 2 for k in keys)
    dist = math.sqrt(sq_sum)
    return 1.0 - (dist / _MAX_PERSONALITY_DIST)


# Social preference scoring
_GROUP_SIZES = [
    "One-on-one",
    "Small groups (3-5)",
    "Large groups (6+)",
]

_FREQUENCIES = [
    "Rarely",
    "Monthly",
    "Bi-weekly",
    "Weekly",
    "Multiple times a week",
]

def _ordinal_similarity(value_a, value_b, scale):
    """Return 0-1 similarity for two ordinal values on a known scale."""
    try:
        idx_a = scale.index(value_a)
        idx_b = scale.index(value_b)
    except ValueError:
        return 0.5  # unknown value — assume neutral
    max_gap = len(scale) - 1
    if max_gap == 0:
        return 1.0
    return 1.0 - abs(idx_a - idx_b) / max_gap

def social_score(social_a, social_b):
    a = social_a or DEFAULT_SOCIAL
    b = social_b or DEFAULT_SOCIAL

    group_sim = _ordinal_similarity(
        a.get("group_size", ""), b.get("group_size", ""), _GROUP_SIZES
    )
    freq_sim = _ordinal_similarity(
        a.get("meeting_frequency", ""), b.get("meeting_frequency", ""), _FREQUENCIES
    )
    # Preferred times — Jaccard overlap
    times_a = set(a.get("preferred_times", []))
    times_b = set(b.get("preferred_times", []))
    times_union = times_a | times_b
    times_sim = len(times_a & times_b) / len(times_union) if times_union else 1.0

    return (group_sim + freq_sim + times_sim) / 3.0


# Friendship goals scoring (Jaccard similarity)
def goals_score(goals_a, goals_b):
    set_a = set(goals_a or [])
    set_b = set(goals_b or [])
    union = set_a | set_b
    if not union:
        return 1.0  # both empty — no conflict
    return len(set_a & set_b) / len(union)


# Overall compatibility
def compatibility(profile_a, profile_b):
    """Return a 0-1 compatibility score between two profile dicts."""
    i = interest_score(
        profile_a.get("interests", []),
        profile_b.get("interests", []),
    )
    p = personality_score(
        profile_a.get("personality"),
        profile_b.get("personality"),
    )
    s = social_score(
        profile_a.get("social_preferences"),
        profile_b.get("social_preferences"),
    )
    g = goals_score(
        profile_a.get("friendship_goals", []),
        profile_b.get("friendship_goals", []),
    )
    return (W_INTEREST * i) + (W_PERSONALITY * p) + (W_SOCIAL * s) + (W_GOALS * g)
