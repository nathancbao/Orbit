"""
Embedding service -- local fastembed model, no external API.

Uses BAAI/bge-small-en-v1.5 (~24MB, ONNX Runtime) for semantic embeddings.
No API keys required. Model is lazy-loaded on first call and kept in memory.

Mission embeddings are generated once and persisted to Datastore, then cached
in-process. User embeddings are generated fresh per request from interests.

cosine_similarity() is exposed as a shared math helper for other services.
"""

import logging
import threading
from typing import Optional

import numpy as np

from OrbitServer.models.models import get_mission, store_mission_embedding

logger = logging.getLogger(__name__)

# In-process cache: mission_id (int) -> np.ndarray
_embedding_cache: dict = {}
_cache_lock = threading.Lock()

# In-process cache for user-interest embeddings: interests-tuple -> np.ndarray.
# get_user_embedding runs on every /missions/suggested call, but a user's
# interests rarely change between requests, so recomputing the same fastembed
# inference each time is wasted CPU (and CPU is what App Engine bills). Bounded
# to cap memory on a small instance.
_user_embedding_cache: dict = {}
_USER_CACHE_MAX = 512

# Lazy-loaded fastembed model
_fastembed_model = None
_model_lock = threading.Lock()


def _get_model():
    """Lazy-load the fastembed model on first call (thread-safe, double-checked)."""
    global _fastembed_model
    if _fastembed_model is None:
        with _model_lock:
            if _fastembed_model is None:
                from fastembed import TextEmbedding
                _fastembed_model = TextEmbedding("BAAI/bge-small-en-v1.5")
    return _fastembed_model


def _generate_embedding(text: str) -> Optional[np.ndarray]:
    """Generate a float32 embedding vector for text. Returns None on failure."""
    try:
        vectors = list(_get_model().embed([text]))
        return np.array(vectors[0], dtype=np.float32)
    except Exception:
        logger.exception("fastembed generation failed")
        return None


def _build_mission_text(mission: dict) -> str:
    """Combine mission fields into a document string."""
    title = mission.get('title', '').strip()
    description = mission.get('description', '').strip()
    tags = mission.get('tags') or []
    tag_str = ', '.join(tags) if tags else ''
    parts = [p for p in [title, description, f"Tags: {tag_str}" if tag_str else ''] if p]
    return '. '.join(parts)


def _build_user_text(interests: list) -> str:
    """Represent user interests as a text snippet."""
    return f"Interests: {', '.join(interests)}" if interests else "No interests specified"


def get_or_create_mission_embedding(mission_id: int) -> Optional[np.ndarray]:
    """
    Return the embedding for a mission, generating and persisting it if needed.

    Lookup order:
      L1 -- in-process cache
      L2 -- Datastore (already stored from a previous request)
      L3 -- generate with fastembed, store to Datastore, cache in-process

    Returns None if the mission doesn't exist or generation fails.
    """
    mission_id = int(mission_id)

    # L1: in-process cache
    with _cache_lock:
        if mission_id in _embedding_cache:
            return _embedding_cache[mission_id]

    # L2: Datastore
    mission = get_mission(mission_id)
    if not mission:
        return None

    stored = mission.get('embedding')
    if stored and len(stored) > 0:
        vec = np.array(stored, dtype=np.float32)
        with _cache_lock:
            _embedding_cache[mission_id] = vec
        return vec

    # L3: generate, persist, cache
    vec = _generate_embedding(_build_mission_text(mission))
    if vec is not None:
        store_mission_embedding(mission_id, vec.tolist())
        with _cache_lock:
            _embedding_cache[mission_id] = vec
    return vec


def get_user_embedding(interests: list) -> Optional[np.ndarray]:
    """Generate an embedding for a user's interests, cached by interest set.

    Keyed on the interests themselves (not user id), so a profile edit naturally
    produces a new key and a fresh embedding.
    """
    key = tuple(interests or [])
    with _cache_lock:
        cached = _user_embedding_cache.get(key)
    if cached is not None:
        return cached

    vec = _generate_embedding(_build_user_text(interests))
    if vec is not None:
        with _cache_lock:
            if len(_user_embedding_cache) >= _USER_CACHE_MAX:
                _user_embedding_cache.clear()  # crude bound; fine at this scale
            _user_embedding_cache[key] = vec
    return vec


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity. Returns 0.0 if either vector has zero norm."""
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


def preload_embeddings(missions: list) -> dict:
    """Bulk-load embeddings for a list of mission dicts into the in-process cache.

    Returns {mission_id: np.ndarray or None}.  Avoids N+1 Datastore reads by
    using the embedding field already present on mission dicts fetched by
    list_missions().
    """
    result = {}
    for mission in missions:
        try:
            mid = int(mission['id'])
        except (TypeError, ValueError):
            mid = mission['id']
        # Check L1 cache first
        with _cache_lock:
            if mid in _embedding_cache:
                result[mid] = _embedding_cache[mid]
                continue

        # Use embedding already on the mission dict (from list_missions query)
        stored = mission.get('embedding')
        if stored and len(stored) > 0:
            vec = np.array(stored, dtype=np.float32)
            with _cache_lock:
                _embedding_cache[mid] = vec
            result[mid] = vec
        else:
            result[mid] = None
    return result


def invalidate_cache(mission_id: int) -> None:
    """Remove a mission from the in-process cache."""
    with _cache_lock:
        _embedding_cache.pop(int(mission_id), None)
