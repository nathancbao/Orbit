# Orbit Backend Tests

## Running Tests

```bash
python3 -m pytest tests/ -v
```

Run a specific file or test:
```bash
python3 -m pytest tests/test_ai_suggestion_service.py -v
python3 -m pytest tests/ -v -k "embedding"
```

**Total: 216 tests — all pass without GCP credentials or an Anthropic API key.**

## Libraries

| Library | Purpose |
|---------|---------|
| **pytest** | Test runner and assertion framework. Discovers test files matching `test_*.py`, runs them, and reports results. |
| **unittest.mock** (stdlib) | Provides `patch` and `MagicMock` for replacing real functions/objects during tests. Used to mock database calls, service functions, and external APIs. |
| **Flask test client** | Built into Flask (`app.test_client()`). Simulates HTTP requests to the app without starting a real server. |

### conftest.py — Test Setup

`conftest.py` runs before any test. It does three things:

1. **Mocks Google Cloud** — Injects fake `google.cloud.datastore` and `google.cloud.storage` modules into `sys.modules` so the app loads without GCP credentials.
2. **Mocks Anthropic** — Injects a fake `anthropic` module so `embedding_service.py` can be imported without an API key. Embedding API calls in individual tests are patched at the function level.
3. **Provides fixtures** — `app` and `client` fixtures give each test a configured Flask app and test client.

---

## Test Files

### Utilities (pure logic, no mocks needed)

#### `test_validators.py` — 47 tests
Input validation functions used by API endpoints (`utils/validators.py`).

| Area | Tests |
|------|-------|
| `.edu` email validation | Accepts valid emails, normalizes case/whitespace, rejects non-.edu, empty, None, malformed |
| Profile data validation | Enforces field whitelist, name length (1–100), age range (18–100), bio length (500), interest count (max 10), photo count (max 6), type checks on nested objects, rejects old/removed fields |
| Event data validation | Requires title + description, enforces title/description length limits, tag count/type, pod size range, date format |
| Message data validation | Requires non-empty string content within length limit |
| Vote data validation | Requires valid vote type (time/place), enforces option count (2–5), rejects non-list options |

#### `test_responses.py` — 6 tests
The `success()` and `error()` response helpers.

- `success()` returns `{"success": true, "data": ...}` with status 200
- `success()` without data omits the `data` key
- `error()` returns `{"success": false, "error": "msg"}` with configurable status

#### `test_auth.py` — 10 tests
JWT token creation and decoding (`utils/auth.py`).

| Function | Tests |
|----------|-------|
| `create_access_token` | Returns a string, embeds correct `user_id` and `type: "access"`, includes `exp`/`iat` claims |
| `create_refresh_token` | Returns a string, embeds `type: "refresh"`, differs from access token for same user |
| `decode_token` | Decodes valid tokens, returns error for invalid/empty/tampered tokens |

---

### Service Layer (business logic, mocked DB)

#### `test_user_service.py` — 18 tests
Profile formatting and completeness logic (`services/user_service.py`).

| Function | Tests |
|----------|-------|
| `_format_profile` | Extracts known fields, drops unknown fields, fills missing fields with defaults, preserves interests/photo/trust_score, output always has exactly the profile fields defined in `PROFILE_FIELDS` |
| `_is_profile_complete` | Complete when name + college_year + ≥3 interests are present. Incomplete for: empty name, whitespace-only name, non-string name, missing college_year, empty college_year, <3 interests, no interests key |

#### `test_auth_service.py` — 12 tests
Authentication business logic (`services/auth_service.py`).

| Area | Tests |
|------|-------|
| Demo bypass (`"123456"`) | Creates new user, returns existing user, handles whitespace around code |
| Normal verification | Rejects when no code stored, rejects expired code (deletes it), rejects wrong code, accepts correct code for new user |
| `refresh_access_token` | Rejects token not in store, returns new access token for valid refresh, deletes expired/invalid tokens, rejects access tokens used as refresh tokens (checks `type` claim) |
| `logout` | Deletes refresh token from store |

#### `test_pod_service.py` — 14 tests
Pod assignment and attendance logic (`services/pod_service.py`).

| Function | Tests |
|----------|-------|
| `join_event` | Rejects if event not found; rejects if event not open; returns existing pod if user already joined; joins existing open pod (adds user to member list); creates new pod when none open; marks pod `full` when member count reaches max; records `joined` action with `tags_snapshot` |
| `leave_event` | Rejects if user not in a pod; removes user from member list on success |
| `confirm_attendance` | Rejects if pod not found; rejects if user not a member; adds to confirmed_attendees and calls trust adjustment; does not double-confirm same user; marks pod `completed` when majority confirmed |

#### `test_ai_suggestion_service.py` — 32 tests
Hybrid ML recommendation engine (`services/ai_suggestion_service.py`). All embedding API calls are mocked out.

| Class | Tests |
|-------|-------|
| `TestJaccard` | Empty sets → 0, identical → 1, disjoint → 0, partial overlap → correct ratio |
| `TestDecayWeight` | Very recent → near 1.0, 14-day old → near 0.5 (half-life), `None` → 0.0 |
| `TestActionScore` | joined+attended → 1.0, joined alone → 0.8, skipped → negative, browsed → small positive |
| `TestBuildBehavioralProfile` | Empty history → empty; skipped actions excluded; legacy records without `tags_snapshot` excluded; recent joined entry has high weight |
| `TestComputeBehavioralScore` | No profile → 0, no event tags → 0, full overlap → 1.0, no overlap → 0, result clamped to 1.0 |
| `TestNormalizeTrust` | 0 → 0, 5 → 1, 3 → 0.6, None → default 0.6 |
| `TestGetSuggestedEvents` | Returns events when embedding unavailable; excludes joined events; excludes skipped events; respects limit; results sorted descending by score; `match_score` in [0,1]; `suggestion_reason` is non-empty string; empty candidate list → empty result |

#### `test_embedding_service.py` — 14 tests
Anthropic API wrapper and cache logic (`services/embedding_service.py`).

| Class | Tests |
|-------|-------|
| `TestBuildEventText` | Combines title + description + tags; handles missing tags; handles empty description |
| `TestCosineSimilarity` | Identical vectors → 1.0; orthogonal → 0.0; zero vector → 0.0; partial similarity in (0, 1) |
| `TestGetOrCreateEventEmbedding` | Returns `None` for missing event; loads cached vector from Datastore; in-process cache hit skips Datastore call; API failure returns `None`; on full cache miss generates embedding, writes to Datastore, updates in-process cache |
| `TestInvalidateCache` | Removes event from in-process cache; safe to call on non-existent entry |

---

### API Endpoints (Flask test client, mocked services)

#### `test_api_health.py` — 2 tests
- `GET /` returns status JSON
- `GET /api/health` returns `{"status": "healthy"}`

#### `test_api_auth.py` — 14 tests
Auth endpoints (`/api/auth/*`).

| Endpoint | Tests |
|----------|-------|
| `POST /send-code` | Accepts valid .edu email, rejects non-.edu, empty, missing, no body |
| `POST /verify-code` | Rejects missing fields, missing code, missing email. Demo bypass works for new and existing users |
| `POST /refresh` | Rejects missing token, rejects invalid token |
| `POST /logout` | Rejects missing token, succeeds and deletes token |

#### `test_api_users.py` — 10 tests
User/profile endpoints (`/api/users/*`).

| Endpoint | Tests |
|----------|-------|
| `GET /me` | Rejects unauthenticated, rejects bad token, returns profile, returns 404 when missing |
| `PUT /me` | Rejects unauthenticated, rejects empty body, rejects invalid data (age < 18), updates valid data |
| `GET /<user_id>` | Returns public profile, returns 404 for missing user |

#### `test_api_events.py` — 23 tests
Event endpoints (`/api/events/*`).

| Endpoint | Tests |
|----------|-------|
| `GET /events` | Rejects unauthenticated; returns event list; annotates each event with `user_pod_status` |
| `GET /events/suggested` | Rejects unauthenticated; returns suggestions with `suggestion_reason`; returns empty list when none |
| `POST /events` | Rejects unauthenticated; rejects missing title/description; rejects long title; creates event (201); creates with tags; triggers async embedding generation on create |
| `POST /events/<id>/join` | Rejects unauthenticated; join success (201); event not found → 400; closed event → 400 |
| `DELETE /events/<id>/leave` | Rejects unauthenticated; leave success; not in pod → 400 |
| `POST /events/<id>/skip` | Rejects unauthenticated; skip success (records action); event not found → 404 |

#### `test_api_pods.py` — 14 tests
Pod endpoints (`/api/pods/*`).

| Endpoint | Tests |
|----------|-------|
| `GET /pods/<id>` | Rejects unauthenticated; returns pod with members; pod not found → 404; not a member → 403 |
| `POST /pods/<id>/kick` | Rejects unauthenticated; rejects missing target; records kick vote; executes kick when threshold met; pod not found → 404; not a member → 403 |
| `POST /pods/<id>/confirm-attendance` | Rejects unauthenticated; confirms successfully; not a member → 403; pod not found → 404 |
