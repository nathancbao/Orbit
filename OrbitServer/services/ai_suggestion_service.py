"""
AI event suggestion service.
Scores events for a user based on:
  1. Tag overlap with user interests (Jaccard similarity)
  2. Boost from tags matching past events the user engaged with
  3. Small random shuffle for discovery
"""

import random

from OrbitServer.models.models import (
    list_events, get_profile, get_user_event_history, record_event_action,
)


def _jaccard(set_a, set_b):
    if not set_a and not set_b:
        return 0.0
    intersection = len(set_a & set_b)
    union = len(set_a | set_b)
    return intersection / union if union else 0.0


def score_event_for_user(event, user_interests: set, history_tags: set = None) -> float:
    """
    Return a relevance score in [0, 1] for an event given a user's interests.
    history_tags: union of tags from events the user has previously joined.
    """
    event_tags = set(event.get('tags') or [])
    base_score = _jaccard(user_interests, event_tags)

    # Boost if event tags match past behaviour
    if history_tags:
        history_overlap = _jaccard(history_tags, event_tags)
        base_score = min(1.0, base_score + history_overlap * 0.2)

    # Add a small random noise (10% max) for discovery
    noise = random.uniform(0, 0.1)
    return min(1.0, base_score + noise)


def get_suggested_events(user_id, limit=5):
    """
    Return up to `limit` AI-suggested events the user hasn't joined or skipped.
    Each event includes a `suggestion_reason` string.
    """
    profile = get_profile(user_id) or {}
    user_interests = set(profile.get('interests') or [])

    # Build history tags from past joined events
    history = get_user_event_history(user_id)
    joined_event_ids = {
        h['event_id'] for h in history
        if h.get('action') in ('joined',)
    }
    skipped_event_ids = {
        h['event_id'] for h in history
        if h.get('action') == 'skipped'
    }
    history_tags: set = set()
    for h in history:
        if h.get('action') == 'joined':
            # We don't store tags in history — use a simple interest proxy for now
            pass

    # Fetch candidate events (open only, not already acted on)
    all_events = list_events(filters={'status': 'open'})
    candidates = [
        e for e in all_events
        if e['id'] not in joined_event_ids and e['id'] not in skipped_event_ids
    ]

    # Score
    scored = []
    for event in candidates:
        score = score_event_for_user(event, user_interests, history_tags)
        reason = _build_reason(event, user_interests)
        scored.append({**event, 'match_score': score, 'suggestion_reason': reason})

    scored.sort(key=lambda e: e['match_score'], reverse=True)
    return scored[:limit]


def _build_reason(event, user_interests: set) -> str:
    """Return a human-readable suggestion reason."""
    event_tags = set(event.get('tags') or [])
    overlap = user_interests & event_tags
    if overlap:
        tag_str = ', '.join(sorted(overlap)[:2])
        return f"Because you like {tag_str}"
    return "Something new to try"
