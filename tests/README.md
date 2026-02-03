# Orbit Backend Tests

## Running Tests

```bash
python3 -m pytest tests/ -v
```

## Libraries

| Library | Purpose |
|---------|---------|
| **pytest** | Test runner and assertion framework. Discovers test files matching `test_*.py`, runs them, and reports results. |
| **unittest.mock** (stdlib) | Provides `patch` and `MagicMock` for replacing real functions/objects during tests. Used to mock database calls and service functions so tests run without GCP credentials. |
| **Flask test client** | Built into Flask (`app.test_client()`). Simulates HTTP requests to the app without starting a real server. |

### conftest.py — Test Setup

`conftest.py` runs before any test. It does two things:

1. **Mocks Google Cloud** — Injects fake `google.cloud.datastore` and `google.cloud.storage` modules into `sys.modules` so the app loads without the GCP SDK installed or credentials configured.
2. **Provides fixtures** — `app` and `client` fixtures give each test a configured Flask app and test client.

## Test Files

### Utilities (pure logic, no mocks needed)

#### `test_validators.py` — 28 tests
Input validation functions used by API endpoints.

| Area | Tests |
|------|-------|
| `.edu` email validation | Accepts valid emails, normalizes case/whitespace, rejects non-.edu, empty, None, malformed |
| Profile data validation | Enforces field whitelist, name length (1-100), age range (18-100), bio length (500), interest count (max 10), photo count (max 6), type checks on nested objects |
| Crew data validation | Requires name, enforces name/description length limits |
| Mission data validation | Requires title + description, enforces title length limit |

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

### Service Layer (business logic, mocked DB)

#### `test_user_service.py` — 15 tests
Profile formatting and completeness logic (`services/user_service.py`).

| Function | Tests |
|----------|-------|
| `_format_profile` | Extracts known fields, drops unknown fields, fills missing fields with defaults, preserves nested structures, output always has exactly the 9 profile fields |
| `_is_profile_complete` | Complete when name + 3 interests + preferred_times exist. Incomplete for: empty name, whitespace name, non-string name, <3 interests, no interests, empty preferred_times, missing social_preferences, non-dict social_preferences |

#### `test_auth_service.py` — 12 tests
Authentication business logic (`services/auth_service.py`).

| Area | Tests |
|------|-------|
| Demo bypass (`"123456"`) | Creates new user, returns existing user, handles whitespace around code |
| Normal verification | Rejects when no code stored, rejects expired code (deletes it), rejects wrong code, accepts correct code for new user |
| `refresh_access_token` | Rejects token not in store, returns new access token for valid refresh, deletes expired/invalid tokens, rejects access tokens used as refresh tokens (checks `type` claim) |
| `logout` | Deletes refresh token from store |

#### `test_crew_service.py` — 6 tests
Crew join/leave logic (`services/crew_service.py`).

| Operation | Tests |
|-----------|-------|
| `join_crew` | Rejects if crew not found, rejects if already a member, succeeds and increments member count |
| `leave_crew` | Rejects if crew not found, rejects if not a member, succeeds and decrements member count |

#### `test_mission_service.py` — 3 tests
Mission RSVP logic (`services/mission_service.py`).

| Operation | Tests |
|-----------|-------|
| `rsvp_mission` | Rejects if mission not found, rejects if already RSVPed, succeeds and increments RSVP count |

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

#### `test_api_crews.py` — 12 tests
Crew endpoints (`/api/crews/*`).

| Endpoint | Tests |
|----------|-------|
| `POST /` | Rejects unauthenticated, rejects missing name, rejects long name, creates crew (201) |
| `GET /` | Lists crews, passes tag query param as filter |
| `POST /<id>/join` | Rejects unauthenticated, succeeds, returns 400 if already a member |
| `POST /<id>/leave` | Rejects unauthenticated, succeeds, returns 400 if not a member |

#### `test_api_missions.py` — 10 tests
Mission endpoints (`/api/missions/*`).

| Endpoint | Tests |
|----------|-------|
| `POST /` | Rejects unauthenticated, rejects missing title/description, rejects long title, creates mission (201) |
| `GET /` | Lists missions, passes tag query param as filter |
| `POST /<id>/rsvp` | Rejects unauthenticated, succeeds, returns 400 if already RSVPed |

#### `test_api_discover.py` — 7 tests
Discovery/matching endpoints (`/api/discover/*`).

| Endpoint | Tests |
|----------|-------|
| `GET /users` | Rejects unauthenticated, returns suggestions, returns empty list |
| `GET /crews` | Rejects unauthenticated, returns suggestions |
| `GET /missions` | Rejects unauthenticated, returns suggestions |
