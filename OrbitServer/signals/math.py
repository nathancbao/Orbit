"""
Phase A — Vibe Match Algorithm

Scoring formula:
    weighted_match_score = 0.40 * interest + 0.60 * vibe + mbti_bonus
    (capped at 1.0)

Interest score  →  Jaccard similarity on interests lists
Vibe score      →  1 - normalised Euclidean distance on personality dimensions
                   Prefers quiz-based vibe_check (8 dims) when available,
                   falls back to slider-based personality (3 dims).
MBTI bonus      →  +0.10 for research-backed best-friend MBTI pairings
"""

import math

# The three personality slider dimensions stored in every profile.
PERSONALITY_KEYS = [
    'introvert_extrovert',
    'spontaneous_planner',
    'active_relaxed',
]

# All 8 quiz-based vibe check dimensions.
VIBE_CHECK_KEYS = [
    'introvert_extrovert',
    'spontaneous_planner',
    'active_relaxed',
    'adventurous_cautious',
    'expressive_reserved',
    'independent_collaborative',
    'sensing_intuition',
    'thinking_feeling',
]

# Max possible Euclidean distance for N unit-range dimensions = sqrt(N).
_MAX_DISTANCE = math.sqrt(len(PERSONALITY_KEYS))
_MAX_DISTANCE_VC = math.sqrt(len(VIBE_CHECK_KEYS))


# ── MBTI Compatibility ──────────────────────────────────────────────────
# Based on Typology Triad research (501 people, 902 best friendships).
# Each type maps to its most common best-friend types.

MBTI_BEST_FRIENDS = {
    'ISTJ': ['ISTJ', 'INTP'],
    'ISFJ': ['ISFJ', 'INFP'],
    'INFJ': ['INFJ', 'ENFP'],
    'INTJ': ['INTJ', 'INTP'],
    'ISTP': ['ISTP', 'ISFP'],
    'ISFP': ['ISFP', 'ISTP'],
    'INFP': ['INFP', 'ISFJ'],
    'INTP': ['INTP', 'ISTJ'],
    'ESTP': ['ESTP', 'ESFP'],
    'ESFP': ['ESFP', 'ESTP'],
    'ENFP': ['ENFP', 'INFJ'],
    'ENTP': ['ENTP', 'INTP'],
    'ESTJ': ['ESTJ', 'ISTJ'],
    'ESFJ': ['ESFJ', 'ISFJ'],
    'ENFJ': ['ENFJ', 'ENFP'],
    'ENTJ': ['ENTJ', 'INTJ'],
}


def interest_score(interests_a, interests_b):
    """Jaccard similarity: |A ∩ B| / |A ∪ B|.  Returns 0.0 when both are empty."""
    set_a = set(interests_a or [])
    set_b = set(interests_b or [])
    union = set_a | set_b
    if not union:
        return 0.0
    return len(set_a & set_b) / len(union)


def vibe_score(personality_a, personality_b):
    """1 - normalised Euclidean distance across personality sliders (3 dims).

    Each slider is in [0, 1].  Closer personalities → higher score.
    Returns 0.0 when personality data is missing.
    """
    if not personality_a or not personality_b:
        return 0.0

    squared_sum = 0.0
    for key in PERSONALITY_KEYS:
        val_a = float(personality_a.get(key, 0.5))
        val_b = float(personality_b.get(key, 0.5))
        squared_sum += (val_a - val_b) ** 2

    distance = math.sqrt(squared_sum)
    return round(1.0 - (distance / _MAX_DISTANCE), 4)


def vibe_check_score(vc_a, vc_b):
    """1 - normalised Euclidean distance across 8 quiz dimensions.

    Uses the richer vibe_check data from the quiz.
    Returns 0.0 when vibe_check data is missing.
    """
    if not vc_a or not vc_b:
        return 0.0

    squared_sum = 0.0
    for key in VIBE_CHECK_KEYS:
        val_a = float(vc_a.get(key, 0.5))
        val_b = float(vc_b.get(key, 0.5))
        squared_sum += (val_a - val_b) ** 2

    distance = math.sqrt(squared_sum)
    return round(1.0 - (distance / _MAX_DISTANCE_VC), 4)


def mbti_compatibility_bonus(mbti_a, mbti_b):
    """Return a bonus score for MBTI compatibility.

    +0.10 if B is in A's best-friend list (or vice versa).
    +0.05 if same type (fallback, usually already covered above).
    +0.00 otherwise.

    This is a soft signal — it nudges the score but doesn't override
    strong vibe/interest matches.
    """
    if not mbti_a or not mbti_b:
        return 0.0

    mbti_a = mbti_a.upper()
    mbti_b = mbti_b.upper()

    # Check if B is in A's best-friend list or vice versa
    a_friends = MBTI_BEST_FRIENDS.get(mbti_a, [])
    b_friends = MBTI_BEST_FRIENDS.get(mbti_b, [])

    if mbti_b in a_friends or mbti_a in b_friends:
        return 0.10

    # Same type fallback
    if mbti_a == mbti_b:
        return 0.05

    return 0.0


def weighted_match_score(profile_a, profile_b):
    """Combined score: 40% Interest + 60% Vibe + MBTI bonus, capped at 1.0.

    Prefers quiz-based vibe_check data (8 dims) when both profiles have it.
    Falls back to slider-based personality (3 dims) otherwise.
    MBTI bonus is additive but total score is capped at 1.0.

    Parameters are full profile dicts as returned by get_profile().
    """
    i_score = interest_score(
        profile_a.get('interests'),
        profile_b.get('interests'),
    )

    # Prefer vibe_check (quiz) data if both profiles have it
    vc_a = profile_a.get('vibe_check')
    vc_b = profile_b.get('vibe_check')

    if vc_a and vc_b:
        v_score = vibe_check_score(vc_a, vc_b)
        # MBTI bonus from quiz-derived types
        bonus = mbti_compatibility_bonus(
            vc_a.get('mbti_type'),
            vc_b.get('mbti_type'),
        )
    else:
        # Fallback to slider-based personality
        v_score = vibe_score(
            profile_a.get('personality'),
            profile_b.get('personality'),
        )
        bonus = 0.0

    raw = 0.40 * i_score + 0.60 * v_score + bonus
    return round(min(1.0, raw), 4)


# ── Signal Cluster Discovery ─────────────────────────────────────────────

def find_signal_cluster(user_id, all_profiles, min_score=0.7, cluster_size=4):
    """Find 3–4 compatible users for a Signal group.

    Algorithm:
    1. Score the requester against every other available profile.
    2. Filter to candidates whose score > min_score.
    3. Greedily build a cluster: start with requester + best match,
       then expand by adding the candidate with the highest average
       score to all current cluster members.
    4. Return a list of user_ids (3–4 members including the requester)
       or an empty list if no viable cluster is found.

    Parameters:
        user_id: the requesting user's ID
        all_profiles: dict of {uid: profile_dict} for all available users
        min_score: minimum weighted_match_score threshold (default 0.7)
        cluster_size: target group size including requester (default 4)

    Returns: list of user_ids (3–cluster_size members) or empty list.
    """
    if user_id not in all_profiles:
        return []

    requester = all_profiles[user_id]

    # Score requester against every other user
    candidates = []
    for uid, profile in all_profiles.items():
        if uid == user_id:
            continue
        score = weighted_match_score(requester, profile)
        if score >= min_score:
            candidates.append((uid, score))

    if not candidates:
        return []

    # Sort by descending score
    candidates.sort(key=lambda x: x[1], reverse=True)

    # Build pairwise score cache for candidate-to-candidate scoring
    candidate_ids = [c[0] for c in candidates]
    all_relevant = [user_id] + candidate_ids
    scores = {}
    for i, uid_a in enumerate(all_relevant):
        for uid_b in all_relevant[i + 1:]:
            s = weighted_match_score(all_profiles[uid_a], all_profiles[uid_b])
            scores[(uid_a, uid_b)] = s
            scores[(uid_b, uid_a)] = s

    # Start cluster with requester + best match
    cluster = [user_id, candidates[0][0]]
    remaining = set(candidate_ids) - {candidates[0][0]}

    # Greedily expand
    while len(cluster) < cluster_size and remaining:
        best_candidate = None
        best_avg = -1.0
        for cid in remaining:
            avg = sum(scores.get((cid, m), 0.0) for m in cluster) / len(cluster)
            if avg > best_avg:
                best_avg = avg
                best_candidate = cid
        if best_candidate is None or best_avg < min_score:
            break
        cluster.append(best_candidate)
        remaining.discard(best_candidate)

    # Need at least 3 members (including requester)
    if len(cluster) < 3:
        return []

    return cluster
