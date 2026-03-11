# Orbit AI/ML Integration — Current State

---

## The Recommendation Engine (5 Signals)

Every mission gets scored for each user via a hybrid multi-signal formula:

| Signal | Weight | Data Source |
|---|---|---|
| **TF-IDF cosine** | 30% | User interests vs mission title/description/tags |
| **LightFM collaborative filtering** | 25% | Learned from all users' join/skip/browse patterns + side features (interests, college year, tags) |
| **Semantic embeddings** | 20% | BAAI/bge-small-en-v1.5 meaning-level similarity (local, no API) |
| **Behavioral decay** | 15% | Weighted history of joins/browses with exponential time decay (~14-day half-life) |
| **Trust weight** | 10% | User reliability score [0-5] |

Scores are rescaled to 55-97% for display.

---

## How the Post-Activity Survey Feeds All 5 Signals

The post-activity survey creates a closed feedback loop — every signal improves with real data:

### 1. Enjoyment Rating (1-5 stars)

- **Behavioral decay (15%)**: Multiplies the action weight (`{1: 0.3x, 2: 0.6x, 3: 1.0x, 4: 1.3x, 5: 1.6x}`). A 5-star hike makes future hike-tagged missions rank much higher; a 1-star experience dampens them.
- **LightFM (25%)**: Adds bonus to interaction weights (`{1: -0.3, 2: -0.1, 3: 0.0, 4: 0.2, 5: 0.5}`). The model learns which *types* of missions users actually enjoy, not just which they join.

### 2. "Add to Your Interests" (Tag Selection)

- **TF-IDF (30%)**: New interests immediately improve keyword matching on next recommendation call.
- **Semantic (20%)**: User embedding is regenerated from interests each time, so meaning-level matching improves too.

### 3. Member Upvote/Downvote

- **Trust weight (10%)**: Upvotes add +0.1, downvotes subtract -0.15 from the target user's trust score. Higher-trust users' missions rank better in recommendations.

---

## Other AI-Powered Features

- **Pod assignment**: When you join a mission, you're placed in the pod with the highest Jaccard interest overlap with existing members (not random).
- **LightFM cold-start handling**: Side features (interests, college year, mission tags) let the model score new users/missions even without interaction history.
- **Embedding persistence**: Mission embeddings are generated once, stored in Datastore, and cached in-process to avoid redundant computation.

---

## What's Still Not AI-Powered

- Chat/DMs — pure user-to-user messaging
- Pod voting (time/place) — simple plurality
- Friend suggestions — no ML yet
- No LLM/generative AI calls anywhere — all classical ML + local embeddings

---

## The Key Narrative

Before the survey, the AI was a skeleton — it could score missions but had almost no feedback signal to learn from. Now there's a complete loop: **user joins mission -> does activity -> rates it -> AI learns -> better recommendations next time**. Every survey submission enriches all 5 scoring signals simultaneously.

---

## Survey Flow Details

### Backend
- `POST /pods/<id>/survey` — submit survey (enjoyment rating, added interests, member votes)
- `GET /pods/<id>/survey/status` — check if user already submitted
- Survey window: 7 days after pod completion, then expires silently

### Frontend
- Completed pods show green gradient highlight with "Activity done! Fill out survey!" badge
- Tapping opens SurveyView with 3 sections: star rating, tag chips, member thumbs up/down
- Skip button available — no penalty for not filling it out

### ML Side Effects on Submit
1. Store `SurveyResponse` entity
2. Merge selected tags into user's interests (capped at 10, case-insensitive dedup)
3. Adjust trust scores from member votes (+0.1 upvote, -0.15 downvote)
4. Enrich `UserHistory` with `attended=True` + `enjoyment_rating`
5. Add user to pod's `survey_completed_by` list

---

## Key Files

| File | Purpose |
|------|---------|
| `OrbitServer/services/ai_suggestion_service.py` | Main scorer with display rescaling and enjoyment multiplier |
| `OrbitServer/services/lightfm_service.py` | LightFM model with enjoyment weight bonus |
| `OrbitServer/services/embedding_service.py` | fastembed model loading, embedding generation, caching |
| `OrbitServer/services/survey_service.py` | Survey orchestration — stores response, merges interests, adjusts trust, enriches history |
| `OrbitServer/services/pod_service.py` | Pod assignment + completed_at tracking |
| `OrbitServer/api/pods.py` | Survey API endpoints |
| `OrbitServer/models/models.py` | SurveyResponse entity, enriched get_user_pods with has_pending_survey + mission_tags |
| `tests/test_survey_service.py` | 19 tests — validation, interest capping, trust adjustments, history enrichment |
| `tests/test_survey_ml_integration.py` | 16 tests — enjoyment multiplier, behavioral profiles, display rescaling, LightFM bonuses |
