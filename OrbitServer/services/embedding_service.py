"""
Embedding service wrapping the Anthropic API (Voyage AI models).

Embeddings are cached at two levels:
  1. In-process dict (_embedding_cache): survives within a gunicorn worker lifetime
  2. Datastore Event.embedding field: persistent across deployments and worker restarts

Cache miss path: call Anthropic API → write back to Datastore → update in-process cache.

Embedding model: voyage-3-lite (512-dim, cost-effective, tuned for retrieval tasks)
  ~$0.0001 per event embedding. Failures degrade gracefully to 0.0 score.
"""

import logging
import os
from typing import Optional

import numpy as np

from OrbitServer.models.models import get_event, store_event_embedding

logger = logging.getLogger(__name__)

# In-process cache: event_id (int) -> np.ndarray of shape (512,)
_embedding_cache: dict = {}

# Lazy-initialized Anthropic client
_client = None


def _get_client():
    global _client
    if _client is None:
        try:
            import anthropic as _anthropic
            api_key = os.environ.get('ANTHROPIC_API_KEY')
            if not api_key:
                raise RuntimeError("ANTHROPIC_API_KEY environment variable not set")
            _client = _anthropic.Anthropic(api_key=api_key)
        except ImportError:
            raise RuntimeError("anthropic package not installed")
    return _client


def _build_event_text(event: dict) -> str:
    """Combine event fields into a document string for embedding."""
    title = event.get('title', '').strip()
    description = event.get('description', '').strip()
    tags = event.get('tags') or []
    tag_str = ', '.join(tags) if tags else ''
    parts = [p for p in [title, description, f"Tags: {tag_str}" if tag_str else ''] if p]
    return '. '.join(parts)


def _build_user_text(interests: list) -> str:
    """Represent user interests as an embeddable text snippet."""
    return f"Interests: {', '.join(interests)}" if interests else "No interests specified"


def _call_anthropic_embedding(text: str) -> Optional[list]:
    """
    Call Anthropic embeddings API and return float list.
    Returns None on any API error (callers treat None as zero score).
    """
    try:
        client = _get_client()
        response = client.embeddings.create(
            model="voyage-3-lite",
            input=[text],
            input_type="document",
        )
        return response.data[0].embedding
    except Exception as e:
        logger.warning(f"Anthropic embedding API error: {e}")
        return None


def get_or_create_event_embedding(event_id: int) -> Optional[np.ndarray]:
    """
    Return the embedding for an event as a numpy array.

    Cache hierarchy:
      1. In-process dict (_embedding_cache)
      2. Datastore Event.embedding field
      3. Anthropic API call (writes back to Datastore and in-process cache)

    Returns None if embedding cannot be generated (API error, event not found).
    """
    event_id = int(event_id)

    # L1: in-process cache
    if event_id in _embedding_cache:
        return _embedding_cache[event_id]

    # L2: Datastore
    event = get_event(event_id)
    if not event:
        return None

    stored = event.get('embedding')
    if stored and len(stored) > 0:
        vec = np.array(stored, dtype=np.float32)
        _embedding_cache[event_id] = vec
        return vec

    # L3: Generate via API (lazy on first recommendation request)
    text = _build_event_text(event)
    embedding = _call_anthropic_embedding(text)
    if embedding is None:
        return None

    try:
        store_event_embedding(event_id, embedding)
    except Exception as e:
        logger.warning(f"Failed to persist embedding for event {event_id}: {e}")

    vec = np.array(embedding, dtype=np.float32)
    _embedding_cache[event_id] = vec
    return vec


def get_user_embedding(interests: list) -> Optional[np.ndarray]:
    """
    Generate an on-the-fly embedding for a user's interests.
    Not cached (interests change on profile update).
    Returns None on API error.
    """
    if not interests:
        return None
    text = _build_user_text(interests)
    embedding = _call_anthropic_embedding(text)
    if embedding is None:
        return None
    return np.array(embedding, dtype=np.float32)


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity. Returns 0.0 if either vector has zero norm."""
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


def invalidate_cache(event_id: int) -> None:
    """Remove an event from the in-process cache (call after event update)."""
    _embedding_cache.pop(int(event_id), None)
