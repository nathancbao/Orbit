import math

# ── Base weights (no vibe-check data — must sum to 1.0) ────────
_W_BASE = {
    "interest": 0.30,
    "personality": 0.30,
    "social": 0.20,
    "goals": 0.20,
}

# ── Boosted weights (both users completed the vibe check) ──────
_W_VIBE = {
    "interest": 0.25,
    "personality": 0.40,
    "social": 0.20,
    "goals": 0.15,
}

# ── Vibe Check 8 dimensions ────────────────────────────────────
_VIBE_CHECK_DIMS = (
    "introvert_extrovert",
    "spontaneous_planner",
    "active_relaxed",
    "adventurous_cautious",
    "expressive_reserved",
    "independent_collaborative",
    "sensing_intuition",
    "thinking_feeling",
)

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


def _conviction(vibe_check):
    """Average deviation from neutral (0.5) across all quiz dimensions.
    Returns 0.0 (all neutral) to 1.0 (all extreme answers)."""
    devs = [abs(vibe_check.get(d, 0.5) - 0.5) for d in _VIBE_CHECK_DIMS]
    return sum(devs) / (len(devs) * 0.5)


def _get_weights(profile_a, profile_b):
    """Dynamically interpolate between base and vibe-check weights.

    When both users have quiz data, personality weight increases in
    proportion to how decisive (far from neutral) their answers are.
    """
    vc_a = profile_a.get("vibe_check")
    vc_b = profile_b.get("vibe_check")

    if not vc_a or not vc_b:
        return _W_BASE

    blend = (_conviction(vc_a) + _conviction(vc_b)) / 2.0
    return {
        k: _W_BASE[k] + blend * (_W_VIBE[k] - _W_BASE[k])
        for k in _W_BASE
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
# Basic: 3 traits (max distance = sqrt(3))
# Vibe-check: 8 traits (max distance = sqrt(8))

def personality_score(personality_a, personality_b,
                      vibe_check_a=None, vibe_check_b=None):
    """Score personality similarity.

    When both vibe-check dicts are present, uses all 8 quiz dimensions.
    Otherwise falls back to the 3 basic personality traits.
    """
    if vibe_check_a and vibe_check_b:
        dims = _VIBE_CHECK_DIMS
        a, b = vibe_check_a, vibe_check_b
    else:
        dims = ("introvert_extrovert", "spontaneous_planner", "active_relaxed")
        a = personality_a or DEFAULT_PERSONALITY
        b = personality_b or DEFAULT_PERSONALITY

    sq_sum = sum((a.get(k, 0.5) - b.get(k, 0.5)) ** 2 for k in dims)
    dist = math.sqrt(sq_sum)
    max_dist = math.sqrt(len(dims))  # each dim is 0-1
    return 1.0 - (dist / max_dist)


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
    """Return a 0-1 compatibility score between two profile dicts.

    Weights adjust dynamically: when both users have completed the
    vibe-check quiz and answered decisively, personality weight
    increases (up to 0.40) and all 8 quiz dimensions are used.
    """
    w = _get_weights(profile_a, profile_b)

    i = interest_score(
        profile_a.get("interests", []),
        profile_b.get("interests", []),
    )
    p = personality_score(
        profile_a.get("personality"),
        profile_b.get("personality"),
        vibe_check_a=profile_a.get("vibe_check"),
        vibe_check_b=profile_b.get("vibe_check"),
    )
    s = social_score(
        profile_a.get("social_preferences"),
        profile_b.get("social_preferences"),
    )
    g = goals_score(
        profile_a.get("friendship_goals", []),
        profile_b.get("friendship_goals", []),
    )
    return (w["interest"] * i) + (w["personality"] * p) + (w["social"] * s) + (w["goals"] * g)
