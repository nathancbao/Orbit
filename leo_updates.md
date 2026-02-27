# AI Integration Updates — Leo

---

## Overview

Replaced the Jaccard-only event scorer with a four-signal hybrid ML recommendation engine that powers the `GET /api/events/suggested` endpoint. The iOS app (MissionsView) surfaces results as a "suggested for you" horizontal strip with match score badges and suggestion reason labels.

---

## How It Works

### The Scoring Formula

```
score = 0.4 * tfidf_cosine
      + 0.3 * embedding_cosine
      + 0.2 * behavioral_decay
      + 0.1 * trust_weight
```

Every signal is normalized to [0, 1] before weighting. All signals degrade gracefully to 0.0 if unavailable (no API key, no history, no interests, etc.) — the system always returns a ranked list rather than crashing.

### Signal 1 — TF-IDF Cosine (40%)

Classic keyword matching using scikit-learn's `TfidfVectorizer` (unigrams + bigrams, sublinear TF, English stopwords removed). Each event's title, description, and tags are combined into a single document string; tags are repeated twice to double their weight. The user's interest list is treated the same way. The vectorizer is fit over the full candidate pool per request, then cosine similarity is computed between the user vector and every event vector in one batch.

Handles: `"hiking" → events tagged "hiking"`. Does not handle: `"outdoor adventure" → "hiking trip"` (that's the embedding signal).

### Signal 2 — Semantic Embedding Cosine (30%)

Uses the **Anthropic API (voyage-3-lite, 512 dimensions)** to produce dense semantic vectors. These capture meaning rather than tokens, so conceptually similar events score highly even with no shared vocabulary.

**Cache hierarchy (two levels):**
1. In-process dict per gunicorn worker — fastest, survives within a worker's lifetime
2. Datastore `Event.embedding` field — persistent across deployments and restarts

**Embedding generation flow:**
- When a new event is created (`POST /events`), a daemon thread immediately generates and caches its embedding — the HTTP response is not blocked.
- If an event reaches a recommendation request without an embedding (e.g., events created before this feature shipped), it is lazily backfilled on the spot.
- The user's interests are embedded fresh on each suggestion request (not cached, since interests can change anytime).

Cost: ~$0.0001 per event embedding (voyage-3-lite). Failures return `None` and contribute 0.0 to the score.

### Signal 3 — Behavioral Decay (20%)

Looks at the user's interaction history and asks: does this candidate event resemble events the user has engaged with before?

Each history record now stores a `tags_snapshot` — the event's tags captured at interaction time. The signal computes Jaccard similarity between those historical tags and the candidate's tags, then down-weights older interactions using exponential decay:

```
decay_weight = exp(-0.05 * age_days)   # half-life ≈ 14 days
```

Action score table:

| Action | Score |
|--------|-------|
| joined + attended | 1.0 |
| joined | 0.8 |
| browsed | 0.3 |
| skipped | excluded |

The final behavioral score is a weighted average of Jaccard similarities across all positive history entries.

**Bug fix included:** `record_event_action()` previously didn't save event tags, making this signal dead code. Fixed by adding `tags_snapshot` to `UserEventHistory`. Both join (`pod_service`) and skip (`events API`) paths now pass it.

### Signal 4 — Trust Weight (10%)

A flat baseline signal. The user's `trust_score` (0–5, reflects attendance reliability) is normalized to [0, 1] and added in. New users start at 0 stars and earn trust through confirmed attendance. Higher-trust users get a small universal uplift on every candidate.

---

## What Gets Returned

Each event in the suggestion list includes two extra fields consumed by the iOS app:

| Field | Type | Description |
|-------|------|-------------|
| `match_score` | float [0, 1] | Combined weighted score, shown as a badge in MissionsView |
| `suggestion_reason` | string | Human-readable label shown under the suggestion card |

Reason text logic (priority order):
1. `"Based on events you've joined"` — behavioral score > 0.4
2. `"Because you like {tag1}, {tag2}"` — tag overlap with interests
3. `"Matches your vibe"` — embedding score > 0.5
4. `"Something new to try"` — fallback

---

## Two Separate Scorers

There are intentionally two scoring functions:

| Function | Used by | Method |
|---|---|---|
| `get_suggested_events()` | `GET /api/events/suggested` | Full 4-signal ML pipeline with API calls |
| `score_event_for_user()` | Main `GET /api/events` list | Jaccard + tiny noise only, no API calls |

The main feed uses the cheap scorer deliberately — running the embedding API for every event on every page load would be too slow and expensive.

---

## Files Changed

### New files

| File | Purpose |
|------|---------|
| `OrbitServer/services/embedding_service.py` | Anthropic API wrapper. Two-level cache. `get_or_create_event_embedding()`, `get_user_embedding()`, `cosine_similarity()`, `invalidate_cache()`. |
| `tests/test_ai_suggestion_service.py` | 32 tests covering all scorer components |
| `tests/test_embedding_service.py` | 12 tests covering cache hierarchy, API failure handling, cosine similarity |

### Modified files

| File | Change |
|------|--------|
| `OrbitServer/services/ai_suggestion_service.py` | Full rewrite. `get_suggested_events()` runs full 4-signal pipeline. `score_event_for_user()` preserved (Jaccard+noise) for the main event list. |
| `OrbitServer/models/models.py` | `embedding: None` field on `create_event`. New `store_event_embedding()`. `tags_snapshot` param on `record_event_action`. |
| `OrbitServer/api/events.py` | `POST /events` spawns daemon thread for async embedding. `POST /events/<id>/skip` passes `tags_snapshot`. |
| `OrbitServer/services/pod_service.py` | `join_event` passes `tags_snapshot` to `record_event_action`. |
| `requirements.txt` | Added `scikit-learn==1.4.2`, `numpy==1.26.4`, `anthropic==0.28.0`. |
| `tests/conftest.py` | Mocks `anthropic` module so tests run without an API key. |

---

## Deployment

Set `ANTHROPIC_API_KEY` as an environment variable on App Engine. Events created before this feature shipped will be lazily backfilled with embeddings on the first `/api/events/suggested` request.
