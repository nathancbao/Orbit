# Orbit Server Architecture

## Overview

The Orbit server is a Python web service that handles all backend logic: user authentication via .edu email verification (skipping for Milestone 0), profile management, crews, missions, and interest-based matching. It runs on Google App Engine and stores data in Google Cloud Datastore.

### Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Google App Engine (Python 3.11) |
| Web Framework | Flask 3.0 with Blueprints |
| Database | Google Cloud Datastore |
| File Storage | Google Cloud Storage |
| Authentication | JWT tokens (email verification via SendGrid) |
| Email | SendGrid (currently in demo mode) |

---

## Project Structure

```ini
Orbit/
├── app.yaml                 # GAE configuration
├── main.py                  # App entry point, blueprint registration
├── requirements.txt         # Python dependencies
│
├── api/                     # Request handlers (routes)
│   ├── auth.py             # /api/auth/* endpoints
│   ├── users.py            # /api/users/* endpoints
│   ├── crews.py            # /api/crews/* endpoints
│   ├── missions.py         # /api/missions/* endpoints
│   └── discover.py         # /api/discover/* endpoints
│
├── services/                # Business logic
│   ├── auth_service.py     # Email verification, JWT creation
│   ├── user_service.py     # Profile CRUD, profile completeness
│   ├── crew_service.py     # Crew CRUD, membership
│   ├── mission_service.py  # Mission CRUD, RSVP
│   ├── matching_service.py # Interest-based matching
│   └── storage_service.py  # Photo upload to GCS
│
├── models/                  # Data models
│   └── models.py           # All Datastore entity functions
│
└── utils/                   # Shared utilities
    ├── auth.py             # JWT helpers, @require_auth decorator
    ├── responses.py        # Standard JSON response formatting
    └── validators.py       # Input validation (.edu email, profile, crew, mission)
```

---

## Main Components

The server follows a **three-layer architecture**:

```ini
┌─────────────────────────────────────────────────────┐
│                    API Layer                         │
│         (api/*.py - Flask Blueprints)               │
│   Handles HTTP requests, input validation, auth     │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│                 Service Layer                        │
│              (services/*.py)                         │
│   Contains business logic, coordinates operations    │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│                  Data Layer                          │
│           (models/models.py)                         │
│   Datastore entity functions, database operations    │
└─────────────────────────────────────────────────────┘
```

### Why This Structure?

- **Separation of concerns** - Each layer has one job
- **Testability** - Services can be tested without HTTP
- **Readability** - Easy to find where code lives
- **Maintainability** - Changes in one layer don't break others

---

## Component Details

### 1. API Layer (`api/`)

Each file is a Flask Blueprint with a URL prefix that groups related endpoints.

| File | URL Prefix | Key Endpoints |
|------|------------|---------------|
| `auth.py` | `/api/auth` | send-code, verify-code, refresh, logout |
| `users.py` | `/api/users` | GET/PUT /me, POST /me/photo, GET /<user_id> |
| `crews.py` | `/api/crews` | POST /, GET /, POST /<id>/join, POST /<id>/leave |
| `missions.py` | `/api/missions` | POST /, GET /, POST /<id>/rsvp |
| `discover.py` | `/api/discover` | GET /users, GET /crews, GET /missions |

**Responsibilities:**

- Parse incoming requests
- Validate input data (via `utils/validators.py`)
- Check authentication (via `@require_auth` decorator)
- Call the appropriate service
- Format and return responses (via `utils/responses.py`)

**Example:**

```python
# api/users.py
from flask import Blueprint, request, g
from utils.responses import success, error
from utils.auth import require_auth
from utils.validators import validate_profile_data
from services.user_service import get_user_profile, update_user_profile

users_bp = Blueprint('users', __name__, url_prefix='/api/users')

@users_bp.route('/me', methods=['GET'])
@require_auth
def get_me():
    profile, err = get_user_profile(g.user_id)
    if err:
        return error(err, 404)
    return success(profile)

@users_bp.route('/me', methods=['PUT'])
@require_auth
def update_me():
    data = request.get_json(silent=True) or {}
    valid, errors = validate_profile_data(data)
    if not valid:
        return error(errors, 400)
    profile, err = update_user_profile(g.user_id, data)
    if err:
        return error(err, 500)
    return success(profile)
```

---

### 2. Service Layer (`services/`)

Services contain all business logic. They don't know about HTTP—they take inputs and return `(result, error)` tuples.

| File | Purpose |
|------|---------|
| `auth_service.py` | Email verification code generation, JWT token creation, demo mode bypass |
| `user_service.py` | Profile retrieval/update, profile completeness check, photo upload |
| `crew_service.py` | Crew creation, join/leave with member count tracking |
| `mission_service.py` | Mission creation, RSVP with count tracking |
| `matching_service.py` | Interest overlap matching for users, crews, and missions |
| `storage_service.py` | Upload files to Google Cloud Storage with public URLs |

**Responsibilities:**

- Implement business rules
- Coordinate between multiple model functions
- Return `(data, None)` on success or `(None, error_message)` on failure

**Example:**

```python
# services/crew_service.py
from models.models import (
    create_crew as db_create_crew,
    get_crew, get_crew_member, add_crew_member,
    remove_crew_member, update_crew_member_count,
)

def join_crew(crew_id, user_id):
    crew = get_crew(crew_id)
    if not crew:
        return None, "Crew not found"

    existing = get_crew_member(crew_id, user_id)
    if existing:
        return None, "Already a member of this crew"

    add_crew_member(crew_id, user_id)
    update_crew_member_count(crew_id, 1)
    return {"message": "Joined crew successfully"}, None
```

---

### 3. Data Layer (`models/models.py`)

The data layer is a single module of plain functions (not classes) that wrap the Google Cloud Datastore client. Each entity kind has its own set of CRUD functions.

**Entity Kinds:**

| Kind | Purpose | Key Fields |
|------|---------|------------|
| `User` | User account | email, created_at |
| `Profile` | User profile data | user_id, name, age, interests, personality, ... |
| `Crew` | Friend group | name, description, tags, creator_id, member_count |
| `CrewMember` | Crew membership | crew_id, user_id, joined_at |
| `Mission` | Event | title, description, tags, location, time, creator_id, rsvp_count |
| `MissionRSVP` | Mission attendance | mission_id, user_id, rsvped_at |
| `RefreshToken` | Auth tokens | user_id, created_at |
| `VerificationCode` | Email verification codes | email, code, expires_at |

**Key patterns:**

- Auto-generated numeric IDs for User, Crew, Mission entities
- Composite string keys for join entities: `"{parent_id}_{user_id}"` for CrewMember and MissionRSVP
- `_entity_to_dict()` helper converts Datastore entities to plain dicts with an `id` field
- `_deep_convert()` recursively converts embedded Datastore entities to plain dicts

---

## Key Data Structures

### User & Profile

```python
# Stored as two separate Datastore kinds
# User key is auto-generated numeric ID
# Profile key uses the same numeric ID as the User

User:
    id: int                  # Auto-generated Datastore ID
    email: str               # .edu email address
    created_at: datetime

Profile:
    user_id: int             # Same as User ID (used as key)
    name: str
    age: int
    location: {
        city: str,
        state: str,
        coordinates: { lat: float, lng: float } or None
    }
    bio: str
    photos: [str]            # GCS public URLs
    interests: [str]
    personality: {
        introvert_extrovert: float,   # 0.0 to 1.0
        spontaneous_planner: float,
        active_relaxed: float
    }
    social_preferences: {
        group_size: str,              # e.g. "Small groups (3-5)"
        meeting_frequency: str,       # e.g. "Weekly"
        preferred_times: [str]
    }
    friendship_goals: [str]
    email: str               # Copied from User entity on update
    created_at: datetime
    updated_at: datetime
```

**Profile completeness** is determined by the service layer: a profile is complete when it has a non-empty name, at least 3 interests, and at least one preferred time.

### Crew & Membership

```python
Crew:
    id: int                  # Auto-generated Datastore ID
    name: str
    description: str
    tags: [str]              # Interest tags for matching
    creator_id: int          # User ID
    member_count: int        # Tracked via delta updates
    created_at: datetime

CrewMember:
    id: str                  # Composite key: "{crew_id}_{user_id}"
    crew_id: int
    user_id: int
    joined_at: datetime
```

### Mission & RSVP

```python
Mission:
    id: int                  # Auto-generated Datastore ID
    title: str
    description: str
    tags: [str]              # Interest tags for matching
    location: str            # Free-text location string
    time: str                # Free-text time string
    creator_id: int          # User ID
    rsvp_count: int          # Tracked via delta updates
    created_at: datetime

MissionRSVP:
    id: str                  # Composite key: "{mission_id}_{user_id}"
    mission_id: int
    user_id: int
    rsvped_at: datetime
```

---

## Request Flow

Here's how a typical request flows through the system:

```ini
1. Client sends request
        │
        ▼
2. main.py routes to correct Blueprint
        │
        ▼
3. API layer (api/*.py)
   ├── @require_auth decorator validates JWT, sets g.user_id
   ├── Validates request body via utils/validators.py
   └── Calls service function
        │
        ▼
4. Service layer (services/*.py)
   ├── Implements business logic
   ├── Calls model functions
   └── Returns (result, None) or (None, error_message)
        │
        ▼
5. Data layer (models/models.py)
   ├── Queries/updates Datastore
   └── Returns dict or None
        │
        ▼
6. Response flows back up
   └── API layer formats via success() or error()
        │
        ▼
7. Client receives JSON response
```

**Example: User joins a crew**

```rb
POST /api/crews/12345/join
Authorization: Bearer eyJ...

1. Request hits api/crews.py → join()
2. @require_auth extracts user_id from JWT, stores in g.user_id
3. Calls join_crew(crew_id, g.user_id)
4. Service checks:
   - Does crew exist? (get_crew)
   - Is user already a member? (get_crew_member)
5. Service calls add_crew_member(crew_id, user_id)
6. Service calls update_crew_member_count(crew_id, 1)
7. Returns success({"message": "Joined crew successfully"})
```

---

## Utilities

### Authentication (`utils/auth.py`)

```python
# JWT configuration
JWT_SECRET = os.environ.get('JWT_SECRET', 'dev-secret-change-me')
ACCESS_TOKEN_EXPIRY = 15 minutes
REFRESH_TOKEN_EXPIRY = 7 days

# Token creation
create_access_token(user_id) → str   # JWT with type='access'
create_refresh_token(user_id) → str  # JWT with type='refresh'
decode_token(token) → (payload, None) or (None, error_message)

# Flask decorator - extracts user_id from Bearer token, stores in g.user_id
@require_auth
def protected_route():
    # g.user_id is available here
    pass
```

### Responses (`utils/responses.py`)

```python
# Consistent JSON response formatting
success(data, status=200) → {"success": True, "data": data}
error(message, status=400) → {"success": False, "error": "message string"}
```

### Validators (`utils/validators.py`)

```python
# Input validation - returns (bool, result_or_errors)
validate_edu_email(email) → (True, cleaned_email) or (False, error_message)
validate_profile_data(data) → (True, None) or (False, [error_messages])
validate_crew_data(data) → (True, None) or (False, [error_messages])
validate_mission_data(data) → (True, None) or (False, [error_messages])
```

**Validation rules:**

- Email must be a valid `.edu` address
- Profile: name ≤ 100 chars, age 18–100, bio ≤ 500 chars, max 10 interests, max 6 photos
- Crew: name required, name ≤ 100 chars, description ≤ 500 chars
- Mission: title and description required, title ≤ 200 chars

---

## External Services

| Service | Purpose | Used By |
|---------|---------|---------|
| __SendGrid__ | Send email verification codes (currently demo mode) | auth_service.py |
| __Google Cloud Storage__ | Store user profile photos with public URLs | storage_service.py |
| __Google Cloud Datastore__ | Primary database for all entities | models/models.py |

---

## Configuration

Environment variables (set in `app.yaml`):

```yaml
runtime: python311
entrypoint: gunicorn -b :$PORT main:app

env_variables:
  PROJECT_ID: "orbit-app-486204"
  JWT_SECRET: "<secret-key>"
  SENDGRID_API_KEY: "<sendgrid-api-key>"
  GCS_BUCKET_NAME: "orbit-app-486204-photos"
```

### Dependencies (`requirements.txt`)

```sh
Flask==3.0.0
gunicorn==21.2.0
google-cloud-datastore==2.19.0
google-cloud-storage==2.14.0
PyJWT==2.8.0
sendgrid==6.11.0
python-dotenv==1.0.0
```

---

## Matching Algorithm

The matching service (`matching_service.py`) uses a simple interest overlap approach:

1. **User matching**: Fetches all profiles, counts shared interests with the current user, returns up to 20 sorted by overlap count (highest first). Excludes users without a name set.
2. **Crew matching**: Fetches all crews, counts overlap between user interests and crew `tags`, returns up to 20 sorted by overlap.
3. **Mission matching**: Fetches all missions, counts overlap between user interests and mission `tags`, returns up to 20 sorted by overlap.

Suggested user profiles are formatted to match the Swift `Profile` struct fields (name, age, location, bio, photos, interests, personality, social_preferences, friendship_goals).
