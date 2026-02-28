# AI Integration Updates — Leo

---

## Current State (as of Feb 2026)

All recommendation logic runs locally — no API keys, no external calls. Pod formation uses interest-based compatibility matching.

### Scoring Formula

```
score = 0.30 * tfidf_cosine      — keyword/tag content similarity
      + 0.20 * semantic_cosine   — meaning-level similarity via fastembed
      + 0.25 * lightfm_score     — collaborative filtering (learned from all users)
      + 0.15 * behavioral_decay  — weighted join/skip history with temporal decay
      + 0.10 * trust_weight      — user reliability signal
```

No API keys required. No external calls. All models run locally.

### What Each Signal Does

| Signal | Weight | How it works |
|--------|--------|-------------|
| **TF-IDF cosine** | 30% | scikit-learn `TfidfVectorizer` (unigrams + bigrams). Matches user interests against event title, description, and tags (tags double-weighted). Fast batch computation over all candidates. |
| **Semantic cosine** | 20% | `fastembed` with `BAAI/bge-small-en-v1.5` (~24MB, ONNX Runtime). Converts user interests and event text to 384-dim vectors and scores cosine similarity. Catches meaning-level matches that TF-IDF misses (e.g. "hiking" ↔ "trail walking"). Event embeddings are generated once and cached in Datastore + in-process. |
| **LightFM score** | 25% | Collaborative filtering model trained on all `UserEventHistory` records. Learns latent user and event embeddings from who joined what across the entire user base. Incorporates user interests and event tags as side features to handle cold start. Gets better as more users interact. Unknown users/events degrade to 0.0. |
| **Behavioral decay** | 15% | Jaccard similarity between candidate event tags and tags from events the user has previously joined/browsed. Older interactions down-weighted by `exp(-0.05 * age_days)` (half-life ≈ 14 days). Skipped events excluded from candidates entirely. |
| **Trust weight** | 10% | User's `trust_score` (0–5, reflects confirmed attendance) normalized to [0, 1]. Flat uplift across all candidates. |

### Two Separate Scorers

| Function | Used by | Method |
|---|---|---|
| `get_suggested_events()` | `GET /api/events/suggested` | Full 5-signal pipeline (TF-IDF + semantic + LightFM + behavioral + trust) |
| `score_event_for_user()` | Main `GET /api/events` list | Jaccard + tiny noise only — fast, scales to N events |

---

## What the AI Actually Does

> **What "AI" means here:** the system combines a pre-trained ML model (fastembed/`BAAI/bge-small-en-v1.5`) with a set of hand-tuned heuristics to produce recommendation scores. 

There are two places this runs — event recommendations and pod formation. No generative AI, no chat, no external model calls anywhere.

**Event recommendations:** Every open event gets a score for each user based on five signals. TF-IDF matches keywords — if you're into "hiking" and the event says "hiking," that's a direct hit. The semantic model (`BAAI/bge-small-en-v1.5`, runs locally) catches meaning-level matches even when the words differ — it knows "trail walking" and "hiking" are the same idea. LightFM looks across all users: if people with similar interests to yours tend to join certain events, those events get a boost for you too, even if the tags don't line up. Behavioral decay weights your own join/browse history, fading older interactions so recent activity counts more. Trust weight gives a small flat uplift to users who have a track record of actually showing up. Events are sorted by final score so the most relevant ones surface first.

**Pod formation:** When a user joins an event, instead of dropping them into whatever pod has an open slot, the system finds the pod whose current members share the most interests with them. It scores every open pod using average Jaccard similarity between the joining user's interests and each member's interests, then routes the user to the best match. The goal is that by the time a pod fills up, the four members already have something in common before they've even said hello.

### Worked Example

**User profile:**
- Interests: `["machine learning", "python", "data science"]`
- History: joined `"Intro to PyTorch"` (3 days ago), joined `"NLP Workshop"` (10 days ago), skipped `"Web Dev Bootcamp"` (5 days ago)
- Trust score: 4.2 / 5

**Candidate events:**
1. `"Advanced ML with Python"` — tags: `["machine learning", "python", "advanced"]`
2. `"React Frontend Workshop"` — tags: `["javascript", "react", "frontend"]`

**Scoring event 1 — "Advanced ML with Python":**
```
TF-IDF cosine:    0.82   (strong keyword overlap with interests)
Semantic cosine:  0.91   (embedding model knows "ML" and "data science" are closely related)
LightFM score:    0.76   (users with similar interests have joined ML events)
Behavioral decay: 0.78   (tag overlap with PyTorch/NLP joins, recent → low decay)
Trust weight:     0.84   (4.2/5 normalized)

score = 0.30 × 0.82 + 0.20 × 0.91 + 0.25 × 0.76 + 0.15 × 0.78 + 0.10 × 0.84
      = 0.246 + 0.182 + 0.190 + 0.117 + 0.084
      = 0.819
```

**Scoring event 2 — "React Frontend Workshop":**
```
TF-IDF cosine:    0.05   (no keyword overlap with ML/Python interests)
Semantic cosine:  0.11   (embedding model confirms frontend/ML are unrelated)
LightFM score:    0.08   (users similar to you rarely join frontend events)
Behavioral decay: 0.00   (no tag overlap; "Web Dev Bootcamp" was skipped → excluded)
Trust weight:     0.84

score = 0.30 × 0.05 + 0.20 × 0.11 + 0.25 × 0.08 + 0.15 × 0.00 + 0.10 × 0.84
      = 0.015 + 0.022 + 0.020 + 0.000 + 0.084
      = 0.141
```

**Result:** Event 1 surfaces near the top of suggestions; Event 2 is ranked near the bottom. The skipped web dev event is filtered out entirely before scoring begins.

---

## LightFM Collaborative Filtering

The LightFM model is the only signal that learns from your actual user base. All other signals operate on a single user in isolation — LightFM looks across everyone.

### How It Works

1. On first scoring request, the model trains on all `UserEventHistory` records in Datastore.
2. It learns latent embeddings for every user and event from interaction patterns — who joined what, who browsed what.
3. Side features (user interests, college year, event tags) are incorporated so new users/events have a starting point before enough interactions exist.
4. Scores are output as raw floats and normalized to (0, 1) via sigmoid.
5. Unknown users or events (not in training data) fall back to 0.0 gracefully.

### Training Data

| Input | Source | How used |
|---|---|---|
| Interactions | `UserEventHistory` — all records | joined=1.0, browsed=0.3, attended bonus=+0.5, skipped=excluded |
| User features | `Profile.interests`, `college_year` | Side features to bootstrap cold-start users |
| Item features | `Event.tags` | Side features to bootstrap cold-start events |

### Retraining

The model is lazy-trained in memory on first call. Call `retrain()` from a scheduled cron endpoint to refresh it with new interaction data. As the user base grows this should run nightly.

### Scaling Considerations

- **Retraining cost** grows with data. At 100 users it's instant. At 100,000+ users with millions of interactions, move retraining to a dedicated Cloud Scheduler / Cloud Run job rather than running it on the app server.
- **Cold start** — new events have no interaction history so LightFM scores them 0.0. The TF-IDF and semantic signals cover this gap until enough interactions accumulate.
- **Memory** — the LightFM model grows as the user/event matrix grows. Combined with the fastembed model in memory, monitor instance RAM as the user base scales.
- **Model staleness** — with nightly retraining, interactions from the current day aren't reflected until the next retrain. The behavioral decay signal covers recent history in the interim.

### Key Functions

| Function | Location | Purpose |
|---|---|---|
| `get_lightfm_scores(user_id, event_ids)` | `lightfm_service.py` | Batch scoring for a user against a list of events |
| `retrain()` | `lightfm_service.py` | Force a full retrain from current Datastore data |
| `list_all_event_history()` | `models.py` | Fetch all interaction records for training |
| `list_all_profiles()` | `models.py` | Fetch all profiles for user side features |

---

## Smart Pod Formation

When a user joins an event, the system routes them into the open pod whose existing members have the most interest overlap with them, rather than assigning FIFO.

### How It Works

1. On `POST /events/{id}/join`, the joining user's profile is fetched to get their `interests` list.
2. All open pods for the event are scored by **average Jaccard similarity** between the user's interests and each existing member's interests.
3. The user is placed in the highest-scoring pod. If the user has no interests set, falls back to FIFO. If no open pods exist, a new pod is created as before.
4. The existing Datastore transaction (race-condition safety) is unchanged.

### Compatibility Score

```
compatibility(user, pod) = mean over members of:
    |user_interests ∩ member_interests| / |user_interests ∪ member_interests|
```

Pure Python — no model, no API calls. Runs at join time only (one profile fetch per existing pod member).

### Key Functions

| Function | Location | Purpose |
|---|---|---|
| `_compute_pod_compatibility()` | `pod_service.py` | Average Jaccard between user and pod members |
| `_find_best_pod_for_user()` | `pod_service.py` | Scans open pods, returns best-scoring one |

---

## Key Files

| File | Purpose |
|------|---------|
| `OrbitServer/services/ai_suggestion_service.py` | Main scorer. `get_suggested_events()` and `score_event_for_user()`. |
| `OrbitServer/services/lightfm_service.py` | LightFM model. `get_lightfm_scores()`, `retrain()`, lazy training pipeline. |
| `OrbitServer/services/embedding_service.py` | fastembed model loading, embedding generation, Datastore caching, `cosine_similarity` helper. |
| `OrbitServer/services/pod_service.py` | Pod assignment. `_find_best_pod_for_user()` and `_compute_pod_compatibility()` for smart formation. |
| `OrbitServer/models/models.py` | `list_all_event_history()`, `list_all_profiles()` for training. `store_event_embedding()` persists vectors. |
| `tests/test_ai_suggestion_service.py` | 34 tests covering all scorer components including LightFM and semantic signals. |
| `tests/test_lightfm_service.py` | 11 tests covering scoring, sigmoid normalization, graceful degradation, and retrain. |
| `tests/test_pod_service.py` | 26 tests covering pod assignment including 11 tests for smart formation. |
| `tests/test_embedding_service.py` | 18 tests covering model loading, generation, caching, and math helpers. |

### Dependencies

- `scikit-learn==1.4.2`
- `numpy==1.26.4`
- `fastembed==0.3.6` — local semantic embeddings (ONNX Runtime, no API)
- `lightfm==1.17` — collaborative filtering model

### Previously Removed
- `anthropic==0.28.0` — Voyage API removed to eliminate API costs; replaced by local fastembed model
