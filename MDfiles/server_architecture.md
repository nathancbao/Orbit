# Orbit Server Architecture

## Overview

The Orbit server is a Python/Flask web service running on Google App Engine that handles authentication, user profiles, event discovery, pod management, in-pod chat, and activity-request missions.

The design is **events-first**: users browse shared activities (events), join small groups called **pods**, and coordinate within their pod via chat + voting.

### Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Google App Engine (Python 3.11) |
| Framework | Flask 3.x with Blueprints |
| Database | Google Cloud Datastore |
| File Storage | Google Cloud Storage |
| Auth | JWT — PyJWT (email verification via SendGrid, currently demo mode) |

---

## Project Structure

```ini
Orbit/
├── app.yaml                        # GAE config + env vars
├── main.py                         # App entry point, blueprint registration
├── requirements.txt
│
└── OrbitServer/
    ├── api/                        # HTTP layer (Flask Blueprints)
    │   ├── auth.py                 # /api/auth/*
    │   ├── users.py                # /api/users/*
    │   ├── events.py               # /api/events/*
    │   ├── pods.py                 # /api/pods/*  (detail, kick, confirm)
    │   ├── chat.py                 # /api/pods/<id>/messages, votes
    │   └── missions.py             # /api/missions/*
    │
    ├── services/                   # Business logic
    │   ├── auth_service.py         # Email verification, JWT creation, demo bypass
    │   ├── user_service.py         # Profile CRUD, completeness check, photo upload
    │   ├── event_service.py        # Event CRUD, interest-scored listing
    │   ├── pod_service.py          # Join/leave events, pod enrichment, kick, attendance
    │   ├── chat_service.py         # Messages, vote creation/response, auto-close
    │   ├── mission_service.py      # Activity-request mission CRUD
    │   ├── ai_suggestion_service.py# Jaccard-scored event suggestions
    │   └── storage_service.py      # GCS photo upload
    │
    ├── models/
    │   └── models.py               # All Datastore entity functions
    │
    └── utils/
        ├── auth.py                 # JWT helpers, @require_auth decorator
        ├── responses.py            # success() / error() formatters
        ├── validators.py           # Input validation for all endpoints
        └── profanity.py            # Chat message filter

```

---

## Three-Layer Architecture

```ini
┌──────────────────────────────────────────────────────┐
│                    API Layer                          │
│              (OrbitServer/api/*.py)                   │
│  Flask Blueprints — parse requests, validate input,  │
│  enforce auth, call services, format responses        │
└────────────────────────┬─────────────────────────────┘
                         │ (result, error) tuples
┌────────────────────────▼─────────────────────────────┐
│                 Service Layer                         │
│           (OrbitServer/services/*.py)                 │
│  Business logic — no HTTP knowledge; coordinates     │
│  model calls and returns (data, None) or (None, err) │
└────────────────────────┬─────────────────────────────┘
                         │ plain dict returns
┌────────────────────────▼─────────────────────────────┐
│                  Data Layer                           │
│         (OrbitServer/models/models.py)                │
│  Datastore CRUD — all entity reads/writes live here  │
└──────────────────────────────────────────────────────┘

```

---

## Datastore Entity Reference

### User

```yaml
Kind:    User
Key:     auto int (Datastore-generated)
Fields:  email, created_at

```

### Profile

```md
Kind:    Profile
Key:     same int as User (user_id)
Fields:  user_id, name, college_year (freshman|sophomore|junior|senior|grad),
         interests [str], trust_score (0.0–5.0), photo (GCS URL|None),
         email (copied from User), created_at, updated_at

```

__Profile completeness__ (drives Swift `profileComplete` flag): name set + college_year set + ≥ 3 interests.

### Event

```md
Kind:    Event
Key:     auto int (Datastore-generated)
          ⚠ Returned to Swift as *string* — Swift Event.id is String.
Fields:  title, description, tags [str], location, date (YYYY-MM-DD),
         creator_id (int), creator_type (user|seeded|ai_suggested),
         max_pod_size (2–10, default 4), status (open|completed|cancelled),
         created_at, updated_at

```

__Serialization note:__ `events.py` converts `event['id']` to `str()` in every response via `_to_str_id()`. Internally all service/model code still uses the native int.

```md

```

### EventPod

```md
Kind:    EventPod
Key:     UUID string
Fields:  event_id (int), member_ids [int], max_size (int),
         status (open|full|meeting_confirmed|completed|cancelled),
         scheduled_time (str|None), scheduled_place (str|None),
         confirmed_attendees [int], kick_votes {str: [int]},
         created_at, expires_at

```

Pod lifecycle:

- Created on first join for an event (or when the previous pod is full)
- `open` → `full` when `len(member_ids) == max_size`
- `scheduled_time` / `scheduled_place` set by vote auto-close
- `completed` when ≥ 50% of members confirm attendance

### ChatMessage

```yaml
Kind:    ChatMessage
Key:     UUID string
Fields:  pod_id, user_id, content (excluded from Datastore indexes),
         message_type (text|vote_created|vote_result), created_at

```

### Vote

```md
Kind:    Vote
Key:     UUID string
Fields:  pod_id, created_by (user_id), vote_type (time|place),
         options [str], votes {user_id_str: option_index},
         status (open|closed), result (str|None), created_at, closed_at

```

Auto-closes when all pod members have voted; winning option is written back to the pod's `scheduled_time` or `scheduled_place`.

### UserEventHistory

```md
Kind:    UserEventHistory
Key:     UUID string
Fields:  user_id, event_id, pod_id (nullable), action (joined|skipped),
         attended (None|bool), points_earned, created_at

```

Used by the AI suggestion service to exclude events the user has already acted on.

### Mission (Activity Request)

```md
Kind:    Mission
Key:     UUID string
Fields:  creator_id (int), title, description,
         activity_category (Pickleball|Basketball|Cafe Hopping|Restaurant|
                             Study Session|Hiking|Gym|Running|Yoga|
                             Board Games|Movies|Custom),
         custom_activity_name (str|None),
         min_group_size (int), max_group_size (int),
         availability [{"date": "<ISO 8601>", "time_blocks": ["morning",...]}],
         status (pending_match|matched), created_at

```

> The `availability` field is stored as an embedded list (excluded from Datastore indexes).
> When Swift's `MissionsViewModel` is wired to the real API, `AvailabilitySlot` will need
> a `CodingKeys` entry: `"time_blocks"` → `timeBlocks`.

### Auth Entities

```yaml
RefreshToken  key: token string   fields: user_id, created_at
VerificationCode key: email       fields: email, code, created_at, expires_at (10 min)

```

---

## Key Service Details

### auth_service.py

- `send_verification_code(email)` — generates 6-digit code, stores in Datastore, prints to log (demo mode; SendGrid integration is commented out)
- `verify_code(email, code)` — code `123456` bypasses check (demo bypass); otherwise validates and expires codes; creates User on first login; returns JWT pair
- `refresh_access_token(refresh_token)` — validates Datastore token + JWT signature; returns new access token

### event_service.py + ai_suggestion_service.py

`get_events_for_user(user_id, filters)`:

1. Queries Datastore for open events
2. Loads user's interest set from Profile
3. Scores each event via **Jaccard similarity** between user interests and event tags
4. Adds ±0.1 random noise for discovery variety
5. Sorts descending by score

`get_suggested_events(user_id, limit)`:

- Same scoring + history boost (past-joined event tags boost similar events by 20%)
- Excludes events already joined or skipped

### pod_service.py

`join_event(event_id, user_id)`:

1. Check event is `open`
2. If user already in a pod for this event → return existing pod
3. Find first open pod with room → add user
4. If none → create new pod with `first_member_id = user_id`
5. Log `UserEventHistory` action

`vote_to_kick(pod_id, kicker_id, target_id)`:

- Records kick vote per target; majority = `> 50%` of non-target members
- On majority: removes target, reopens pod status, placeholder for replacement logic

`confirm_attendance(pod_id, user_id)`:

- Appends to `confirmed_attendees`; if ≥ 50% confirmed → marks pod `completed`
- Awards `+0.5` trust score points to confirming user

### chat_service.py

Vote auto-close: when `len(votes_map) >= len(member_ids)`, tallies by plurality, writes result to pod's `scheduled_time`/`scheduled_place`, creates a `vote_result` system message.

### user_service.py

`_is_profile_complete(profile)` → `name` set + `college_year` set + `len(interests) >= 3`

Photo upload path: `storage_service.upload_file()` → GCS → public URL → stored in Profile.

---

## Utilities

### utils/auth.py

```python
JWT_SECRET          = os.environ.get('JWT_SECRET', 'dev-secret-change-me')
ACCESS_TOKEN_EXPIRY = 15 minutes
REFRESH_TOKEN_EXPIRY = 7 days

create_access_token(user_id) → str    # payload: {user_id, type='access', exp, iat}
create_refresh_token(user_id) → str   # payload: {user_id, type='refresh', exp, iat}
decode_token(token) → (payload, None) | (None, error_string)

@require_auth   # decorator — sets g.user_id from Bearer token

```

### utils/responses.py

```python
success(data, status=200) → {"success": True,  "data": data}
error(message, status=400) → {"success": False, "error": message}

```

### utils/validators.py

| Function | Validates |
|----------|-----------|
| `validate_edu_email(email)` | `.edu` domain, format |
| `validate_profile_data(data)` | allowed fields, name length, college_year enum, 3–10 interests |
| `validate_event_data(data, is_update)` | required fields, title/desc length, tag count, date format, pod size |
| `validate_mission_data(data)` | activity_category enum, custom name if Custom, group sizes 2–10, availability slots |
| `validate_message_data(data)` | content present, ≤ 1000 chars |
| `validate_vote_data(data)` | vote_type (time\|place), 2–4 options |

### utils/profanity.py

Simple word-list filter applied to chat messages. `filter_message(text) → (is_clean, reason)`.

---

## Request Flow Example — Join an Event

```ini
POST /api/events/5629499534213120/join
Authorization: Bearer <access_token>

1. events_bp.join() in api/events.py
   └── @require_auth sets g.user_id

2. pod_service.join_event(event_id=5629499534213120, user_id=g.user_id)
   ├── get_event(event_id) — confirm exists + open
   ├── get_user_pod_for_event(...) — already joined?
   ├── find_open_pod_for_event(...) — room in existing pod?
   │     YES → update_event_pod (append member, maybe → full)
   │     NO  → create_event_pod (new pod, first_member_id=user_id)
   └── record_event_action(user_id, event_id, 'joined', pod_id)

3. success(pod_dict, 201)
   → Swift decodes as EventPod

```

---

## What Changed vs the Old Design

| Aspect | Old (pre-redesign) | Current |
|--------|-------------------|---------|
| Core concept | User-to-user friendship matching | Activity-based event joining |
| Social unit | Crew (persistent friend group) | EventPod (per-event, ephemeral) |
| Discovery | Solar system of user planets | Event card feed with AI scoring |
| Profile fields | name, age, location, bio, personality sliders, photos[] | name, college_year, interests, photo, trust_score |
| Server entities | User, Profile, Crew, CrewMember, Mission(old), MissionRSVP | User, Profile, Event, EventPod, ChatMessage, Vote, UserEventHistory, Mission(new) |
| Server API files | auth, users, crews, missions(old), discover | auth, users, events, pods, chat, missions(new) |
| Matching | User interest overlap → suggested friends | Jaccard tag overlap → scored event feed |
| Mission meaning | One-time activity posted in a crew | Activity request with availability + group size |
| In-app communication | Not implemented | Pod chat + time/place voting |
| Trust system | Not implemented | trust_score 0–5 adjusted by attendance confirms and no-shows |
