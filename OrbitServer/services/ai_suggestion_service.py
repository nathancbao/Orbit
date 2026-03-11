"""
Hybrid multi-signal recommendation engine for Orbit missions.

Scoring formula (all signals normalized to [0, 1] before weighting):
    score = 0.30 * tfidf_cosine      -- keyword/tag content similarity
          + 0.20 * semantic_cosine   -- meaning-level similarity via fastembed
          + 0.25 * lightfm_score     -- collaborative filtering (learned from all users)
          + 0.15 * behavioral_decay  -- weighted join/skip history with temporal decay
          + 0.10 * trust_weight      -- user reliability signal

Degrades gracefully:
  - No interaction history -> behavioral_decay = 0.0
  - No interests -> tfidf_cosine = 0.0
  - fastembed unavailable -> semantic_cosine = 0.0
  - LightFM not yet trained or user unknown -> lightfm_score = 0.0
"""

import datetime
import logging
import math
import random

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity as sk_cosine

from OrbitServer.models.models import list_missions, get_user, get_user_history
from OrbitServer.services.embedding_service import (
    get_or_create_mission_embedding, get_user_embedding, cosine_similarity,
    preload_embeddings,
)
from OrbitServer.services.lightfm_service import get_lightfm_scores

logger = logging.getLogger(__name__)

# ── Scoring weights ────────────────────────────────────────────────────────────
W_TFIDF      = 0.30
W_SEMANTIC   = 0.20
W_LIGHTFM    = 0.25
W_BEHAVIORAL = 0.15
W_TRUST      = 0.10

# ── Display rescaling ──────────────────────────────────────────────────────────
# Raw scores cluster low (0.05–0.50) because most signal components are zero
# for newer users.  Rescale to a human-friendly range so the UI percentages
# feel intuitive while preserving rank order.
DISPLAY_FLOOR = 0.55   # minimum displayed score
DISPLAY_CEIL  = 0.97   # maximum displayed score

# ── Behavioral decay parameters ────────────────────────────────────────────────
DECAY_LAMBDA = 0.05   # exp(-0.05 * days), half-life ~ 14 days
EPSILON = 1e-8

ACTION_SCORES = {
    'joined':  0.8,
    'browsed': 0.3,
    'skipped': -0.4,
}
ATTENDED_BONUS = 0.2  # added to 'joined' score when attended=True
ENJOYMENT_MULTIPLIER = {1: 0.3, 2: 0.6, 3: 1.0, 4: 1.3, 5: 1.6}


# ── TF-IDF helpers ─────────────────────────────────────────────────────────────

def _mission_to_doc(mission: dict) -> str:
    title = mission.get('title', '')
    desc = mission.get('description', '')
    tags = mission.get('tags') or []
    tag_str = ' '.join(tags * 2)  # double-weight tags
    return f"{title} {desc} {tag_str}".strip()


def _interests_to_doc(interests: list) -> str:
    return ' '.join(list(interests) * 2)  # double-weight


def _compute_tfidf_scores(user_interests: list, missions: list) -> dict:
    """
    Build TF-IDF corpus from missions, add user interest doc, return
    {mission_id: cosine_similarity_with_user} for each mission.
    """
    if not missions or not user_interests:
        return {m['id']: 0.0 for m in missions}

    user_doc = _interests_to_doc(user_interests)
    mission_docs = [_mission_to_doc(m) for m in missions]
    all_docs = mission_docs + [user_doc]  # user doc is last

    try:
        vectorizer = TfidfVectorizer(
            analyzer='word',
            ngram_range=(1, 2),
            min_df=1,
            max_df=0.95,
            sublinear_tf=True,
            stop_words='english',
        )
        tfidf_matrix = vectorizer.fit_transform(all_docs)
        user_vec = tfidf_matrix[-1]
        mission_vecs = tfidf_matrix[:-1]
        sims = sk_cosine(mission_vecs, user_vec).flatten()
        return {missions[i]['id']: float(sims[i]) for i in range(len(missions))}
    except Exception as e:
        logger.warning(f"TF-IDF computation failed: {e}")
        return {m['id']: 0.0 for m in missions}


# ── Behavioral decay signal ────────────────────────────────────────────────────

def _action_score(action: str, attended, enjoyment_rating=None) -> float:
    base = ACTION_SCORES.get(action, 0.0)
    if action == 'joined' and attended is True:
        base += ATTENDED_BONUS
    if action == 'joined' and enjoyment_rating is not None:
        base *= ENJOYMENT_MULTIPLIER.get(int(enjoyment_rating), 1.0)
    return base


def _decay_weight(created_at) -> float:
    if created_at is None:
        return 0.0
    if isinstance(created_at, str):
        try:
            created_at = datetime.datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        except ValueError:
            return 0.0
    now = datetime.datetime.utcnow()
    if hasattr(created_at, 'tzinfo') and created_at.tzinfo:
        created_at = created_at.replace(tzinfo=None)
    age_days = max(0.0, (now - created_at).total_seconds() / 86400.0)
    return math.exp(-DECAY_LAMBDA * age_days)


def _build_behavioral_profile(history: list) -> list:
    """
    Convert history to list of (tags_set, effective_weight) for positive-signal entries.
    Skipped missions are excluded (already filtered from candidates).
    Legacy records without tags_snapshot are skipped silently.
    """
    profile = []
    for h in history:
        action = h.get('action', '')
        if action == 'skipped':
            continue
        tags_snapshot = h.get('tags_snapshot') or []
        if not tags_snapshot:
            continue
        base = _action_score(action, h.get('attended'), h.get('enjoyment_rating'))
        if base <= 0:
            continue
        w = _decay_weight(h.get('created_at'))
        profile.append((set(tags_snapshot), base * w))
    return profile


def _jaccard(set_a: set, set_b: set) -> float:
    if not set_a and not set_b:
        return 0.0
    union = len(set_a | set_b)
    return len(set_a & set_b) / union if union else 0.0


def _compute_behavioral_score(mission_tags: set, behavioral_profile: list) -> float:
    """
    Weighted-average Jaccard similarity between mission tags and history tag profile.
    Formula: sum(weight * jaccard(history_tags, mission_tags)) / sum(weights)
    Clamped to [0, 1].
    """
    if not behavioral_profile or not mission_tags:
        return 0.0

    weighted_sum = 0.0
    weight_total = 0.0
    for (hist_tags, weight) in behavioral_profile:
        weighted_sum += weight * _jaccard(hist_tags, mission_tags)
        weight_total += weight

    if weight_total < EPSILON:
        return 0.0
    return min(1.0, weighted_sum / weight_total)


# ── Trust weight ───────────────────────────────────────────────────────────────

def _rescale_for_display(raw: float) -> float:
    """Map a raw score in [0, 1] to [DISPLAY_FLOOR, DISPLAY_CEIL].

    Preserves rank order — higher raw scores still produce higher display
    scores.  Missions with raw 0.0 still get the floor so the UI never
    shows an awkwardly low percentage.
    """
    return DISPLAY_FLOOR + raw * (DISPLAY_CEIL - DISPLAY_FLOOR)


def _normalize_trust(trust_score) -> float:
    """Normalize trust_score [0, 5] to [0, 1]. Default 0.0."""
    try:
        return min(1.0, max(0.0, float(trust_score) / 5.0))
    except (TypeError, ValueError):
        return 0.0


# ── Reason generation ──────────────────────────────────────────────────────────

def _build_reason(mission: dict, user_interests: set, behav_score: float) -> str:
    mission_tags = set(mission.get('tags') or [])
    overlap = user_interests & mission_tags

    if behav_score > 0.4:
        return "Based on missions you've joined"
    if overlap:
        tag_str = ', '.join(sorted(overlap)[:2])
        return f"Because you like {tag_str}"
    return "Something new to try"


# ── Public API ─────────────────────────────────────────────────────────────────

def score_mission_for_user(mission: dict, user_interests: set, history_tags: set = None) -> float:
    """
    Fast single-mission scorer used by mission_service.get_missions_for_user (list view).
    Uses Jaccard + tiny noise -- no API calls -- so it scales to N missions without latency.
    The full hybrid scorer is reserved for get_suggested_missions().
    history_tags parameter kept for backward compatibility.
    """
    mission_tags = set(mission.get('tags') or [])
    raw = _jaccard(user_interests, mission_tags) + random.uniform(0, 0.05)
    return _rescale_for_display(min(1.0, raw))


def get_suggested_missions(user_id, limit=5) -> list:
    """
    Return up to `limit` suggested missions with multi-signal hybrid scoring.

    Pipeline:
      1. Load user (interests, trust_score)
      2. Load history -> joined/skipped ID sets + behavioral profile
      3. Load open missions, filter already-acted-on
      4. Batch TF-IDF cosine similarities
      5. Generate user embedding for semantic scoring
      6. Batch LightFM collaborative scores
      7. Per-mission: behavioral decay + semantic cosine + LightFM scores
      8. Combine -> sort -> return top-limit with match_score + suggestion_reason
    """
    # 1. User
    user = get_user(user_id) or {}
    interests_list = list(user.get('interests') or [])
    trust_weight = _normalize_trust(user.get('trust_score', 0.0))

    # 2. History
    history = get_user_history(user_id)
    joined_ids = {h['mission_id'] for h in history if h.get('action') == 'joined'}
    skipped_ids = {h['mission_id'] for h in history if h.get('action') == 'skipped'}
    behavioral_profile = _build_behavioral_profile(history)

    # 3. Candidate missions (open, not yet acted on)
    all_missions = list_missions(filters={'status': 'open'})
    candidates = [
        m for m in all_missions
        if m['id'] not in joined_ids and m['id'] not in skipped_ids
    ]
    if not candidates:
        return []

    # 4. TF-IDF scores (batch)
    tfidf_scores = _compute_tfidf_scores(interests_list, candidates)

    # 5. User embedding for semantic scoring (None if model unavailable)
    user_vec = get_user_embedding(interests_list)

    # 5b. Batch-load mission embeddings from already-fetched mission dicts
    #     (avoids N+1 Datastore reads)
    mission_embeddings = preload_embeddings(candidates) if user_vec is not None else {}

    # 6. LightFM collaborative scores (batch, non-blocking)
    lightfm_scores = get_lightfm_scores(user_id, [m['id'] for m in candidates])

    # 7. Score each candidate
    scored = []
    user_interests_set = set(interests_list)
    for mission in candidates:
        mid = mission['id']
        mission_tags = set(mission.get('tags') or [])

        tfidf_s = tfidf_scores.get(mid, 0.0)
        behav_s = _compute_behavioral_score(mission_tags, behavioral_profile)
        lightfm_s = lightfm_scores.get(mid, 0.0)

        semantic_s = 0.0
        if user_vec is not None:
            mission_vec = mission_embeddings.get(int(mid))
            if mission_vec is not None:
                semantic_s = max(0.0, min(1.0, cosine_similarity(user_vec, mission_vec)))

        final = (
            W_TFIDF      * tfidf_s     +
            W_SEMANTIC   * semantic_s  +
            W_LIGHTFM    * lightfm_s   +
            W_BEHAVIORAL * behav_s     +
            W_TRUST      * trust_weight
        )
        final = min(1.0, max(0.0, final))
        display = _rescale_for_display(final)

        scored.append({
            **mission,
            'match_score': round(display, 4),
            'suggestion_reason': _build_reason(mission, user_interests_set, behav_s),
        })

    scored.sort(key=lambda m: m['match_score'], reverse=True)
    return scored[:limit]
