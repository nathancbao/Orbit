# Orbit Flask Server — Quick Reference

## Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Google App Engine (Python 3.11) |
| Framework | Flask 3.x with Blueprints |
| Database | Google Cloud Datastore (Firestore in Datastore mode) |
| File Storage | Google Cloud Storage (profile photos) |
| Auth | JWT (PyJWT) — email verification via SendGrid (demo mode) |

## Entry Point

`main.py` — creates the Flask app and registers all blueprints.

## Blueprint Registration

```python
from OrbitServer.api.auth     import auth_bp      # /api/auth/*
from OrbitServer.api.users    import users_bp     # /api/users/*
from OrbitServer.api.events   import events_bp    # /api/events/*
from OrbitServer.api.pods     import pods_bp      # /api/pods/*
from OrbitServer.api.chat     import chat_bp      # /api/pods/<id>/messages, votes
from OrbitServer.api.missions import missions_bp  # /api/missions/*
```

## API Surface

### Auth (`/api/auth`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/send-code` | — | Send 6-digit code to `.edu` email |
| POST | `/verify-code` | — | Verify code → returns JWT pair + user_id |
| POST | `/refresh` | — | Swap refresh_token for new access_token |
| POST | `/logout` | — | Invalidate refresh_token |

**Demo mode:** code `123456` bypasses email, always succeeds.

### Users (`/api/users`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/me` | ✓ | Get own profile + profile_complete flag |
| PUT | `/me` | ✓ | Update profile (name, college_year, interests, photo) |
| POST | `/me/photo` | ✓ | Upload profile photo (multipart/form-data) |
| GET | `/<user_id>` | — | Get any user's public profile |

### Events (`/api/events`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | ✓ | List open events, scored by interest overlap |
| GET | `/suggested` | ✓ | AI-suggested events (Jaccard + history boost) |
| POST | `/` | ✓ | Create event |
| GET | `/<id>` | ✓ | Event detail with pod summaries + user_pod_status |
| PUT | `/<id>` | ✓ | Edit event (creator only) |
| DELETE | `/<id>` | ✓ | Delete event + all pods (creator only) |
| POST | `/<id>/join` | ✓ | Join next open pod (or create one) → returns EventPod |
| DELETE | `/<id>/leave` | ✓ | Leave current pod for this event |
| POST | `/<id>/skip` | ✓ | Record skip in history (excluded from future suggestions) |

**Important:** Event `id` is returned as a **string** in all responses even though Datastore uses integer keys internally. Swift's `Event.id` is declared as `String`.

### Pods (`/api/pods`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/<id>` | ✓ | Pod detail with enriched member profiles (members-only) |
| POST | `/<id>/kick` | ✓ | Vote to kick a member (majority → removes them) |
| POST | `/<id>/confirm-attendance` | ✓ | Mark yourself as attended → awards trust points |

### Chat (`/api/pods` — same prefix as pods)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/<id>/messages` | ✓ | Fetch chat history (members-only) |
| POST | `/<id>/messages` | ✓ | Send text message (profanity filtered) |
| GET | `/<id>/votes` | ✓ | List votes for the pod |
| POST | `/<id>/votes` | ✓ | Create time or place vote |
| POST | `/<id>/votes/<vid>/respond` | ✓ | Submit vote response (auto-closes when all voted) |

### Missions (`/api/missions`)

> Activity-request missions (user says "I want to play basketball Tuesday morning with 3-6 people").
> The Swift `MissionsViewModel` currently uses **mock data only** — these endpoints are ready for when the API is wired up.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | ✓ | List authenticated user's missions |
| POST | `/` | ✓ | Create new activity-request mission |
| DELETE | `/<id>` | ✓ | Delete mission (creator only) |

## Standard Response Envelope

```json
// Success
{ "success": true, "data": <payload> }

// Error
{ "success": false, "error": "human-readable message" }
```

## Authentication

JWT Bearer tokens. 15-min access tokens, 7-day refresh tokens stored in Datastore.

```
Authorization: Bearer <access_token>
```

The `@require_auth` decorator in `utils/auth.py` validates the token and sets `g.user_id`.

## Environment Variables (app.yaml)

```yaml
env_variables:
  PROJECT_ID: "orbit-app-486204"
  JWT_SECRET: "<secret>"
  SENDGRID_API_KEY: "<key>"          # optional in demo mode
  GCS_BUCKET_NAME: "orbit-app-486204-photos"
```

## Local Development

```bash
python main.py
# Runs on http://localhost:8080
# Use code "123456" to bypass email verification
```
