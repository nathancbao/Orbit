# Orbit Server Architecture

## Overview

The Orbit server is a Python web service that handles all backend logic: user authentication, profile management, crews, missions, and AI-powered matching. It runs on Google App Engine and stores data in Firestore (Datastore mode).

### Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Google App Engine (Python 3.11) |
| Web Framework | Flask with Blueprints |
| Database | Firestore in Datastore mode |
| File Storage | Google Cloud Storage |
| Authentication | JWT tokens (SMS verification) |

---

## Project Structure

```
orbit-server/
├── app.yaml                 # GAE configuration
├── main.py                  # App entry point
├── requirements.txt         # Python dependencies
├── .gcloudignore           # Files to exclude from deploy
│
├── api/                     # Request handlers (routes)
│   ├── __init__.py
│   ├── auth.py             # Authentication endpoints
│   ├── users.py            # User/profile endpoints
│   ├── crews.py            # Crew endpoints
│   ├── missions.py         # Mission endpoints
│   └── discover.py         # Matching/discovery endpoints
│
├── services/                # Business logic
│   ├── __init__.py
│   ├── auth_service.py     # Auth logic (tokens, SMS)
│   ├── user_service.py     # User/profile logic
│   ├── crew_service.py     # Crew logic
│   ├── mission_service.py  # Mission logic
│   ├── matching_service.py # AI matching logic
│   └── storage_service.py  # File upload logic
│
├── models/                  # Data models
│   ├── __init__.py
│   └── models.py           # All Datastore entities
│
├── utils/                   # Shared utilities
│   ├── __init__.py
│   ├── auth.py             # JWT helpers, decorators
│   ├── responses.py        # Standard response formatting
│   └── validators.py       # Input validation
│
└── tests/                   # Test files
    ├── __init__.py
    ├── test_auth.py
    ├── test_users.py
    ├── test_crews.py
    ├── test_missions.py
    └── test_discover.py
```

---

## Main Components

The server follows a **three-layer architecture**:

```
┌─────────────────────────────────────────────────────┐
│                    API Layer                        │
│         (api/*.py - Flask Blueprints)               │
│   Handles HTTP requests, input validation, auth     │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│                 Service Layer                       │
│              (services/*.py)                        │
│   Contains business logic, coordinates operations   │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│                  Data Layer                         │
│           (models/models.py)                        │
│   Datastore entities, database operations           │
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

Each file is a Flask Blueprint that groups related endpoints.

| File | Purpose | Key Endpoints |
|------|---------|---------------|
| `auth.py` | Authentication | send-code, verify-code, refresh, logout |
| `users.py` | User profiles | get profile, update profile, upload photo |
| `crews.py` | Crew management | create, join, leave, list crews |
| `missions.py` | Mission management | create, RSVP, list missions |
| `discover.py` | AI suggestions | suggested users, crews, missions |

**Responsibilities:**
- Parse incoming requests
- Validate input data
- Check authentication
- Call the appropriate service
- Format and return responses

**Example:**
```python
# api/users.py
from flask import Blueprint, request
from services.user_service import UserService
from utils.auth import require_auth
from utils.responses import success, error

users_bp = Blueprint('users', __name__)

@users_bp.route('/users/me', methods=['GET'])
@require_auth
def get_current_user(user_id):
    user = UserService.get_user(user_id)
    if not user:
        return error('NOT_FOUND', 'User not found', 404)
    return success(user.to_dict())
```

---

### 2. Service Layer (`services/`)

Services contain all business logic. They don't know about HTTP—they just take inputs and return results.

| File | Purpose |
|------|---------|
| `auth_service.py` | SMS verification, JWT creation/validation |
| `user_service.py` | Create/update users, profile completion logic |
| `crew_service.py` | Crew CRUD, membership management, validation |
| `mission_service.py` | Mission CRUD, RSVP logic, date validation |
| `matching_service.py` | Compatibility scoring, suggestion algorithms |
| `storage_service.py` | Upload/delete photos to Cloud Storage |

**Responsibilities:**
- Implement business rules
- Coordinate between multiple models
- Call external services (SMS, AI)
- Return data or raise exceptions

**Example:**
```python
# services/crew_service.py
from models.models import Crew, CrewMember

class CrewService:
    @staticmethod
    def join_crew(user_id: str, crew_id: str) -> dict:
        crew = Crew.get_by_id(crew_id)

        if not crew:
            raise ValueError('Crew not found')

        if crew.member_count >= crew.max_members:
            raise ValueError('Crew is full')

        if CrewMember.exists(user_id, crew_id):
            raise ValueError('Already a member')

        CrewMember.create(user_id, crew_id, role='member')
        crew.increment_member_count()

        return {'message': 'Successfully joined crew'}
```

---

### 3. Data Layer (`models/`)

Models represent Datastore entities and handle all database operations.

**Entities:**

| Entity | Purpose | Key Fields |
|--------|---------|------------|
| `User` | User account | id, phone_number, created_at |
| `Profile` | User profile data | user_id, name, age, interests, personality |
| `Crew` | Friend group | id, name, interest_tags, member_count |
| `CrewMember` | Crew membership | user_id, crew_id, role, joined_at |
| `Mission` | One-time event | id, title, date, location, host_id |
| `MissionRSVP` | Mission attendance | user_id, mission_id, status |
| `RefreshToken` | Auth tokens | token, user_id, expires_at |
| `VerificationCode` | SMS codes | phone_number, code, expires_at |

---

## Key Data Structures

### User & Profile

```python
# Stored as two separate entities for flexibility

User:
    id: str                  # "usr_abc123"
    phone_number: str        # "+14155551234"
    profile_complete: bool
    created_at: datetime

Profile:
    user_id: str             # References User
    name: str
    age: int
    location: {
        city: str
        state: str
        lat: float
        lng: float
    }
    bio: str
    photos: [str]            # Cloud Storage URLs
    interests: [str]
    personality: {
        introvert_extrovert: float    # 0.0 to 1.0
        spontaneous_planner: float
        active_relaxed: float
    }
    social_preferences: {
        group_size: str
        meeting_frequency: str
        preferred_times: [str]
    }
    friendship_goals: [str]
```

### Crew & Membership

```python
Crew:
    id: str                  # "crew_abc123"
    name: str
    description: str
    interest_tags: [str]
    member_count: int
    max_members: int         # 3-15
    created_by: str          # User ID
    created_at: datetime
    last_activity_at: datetime

CrewMember:
    id: str                  # Composite: "usr_abc123_crew_xyz789"
    user_id: str
    crew_id: str
    role: str                # "admin" or "member"
    joined_at: datetime
```

### Mission & RSVP

```python
Mission:
    id: str                  # "msn_abc123"
    title: str
    description: str
    date: datetime
    location: {
        name: str
        address: str
        lat: float
        lng: float
    }
    interest_tags: [str]
    crew_id: str             # Optional
    host_id: str
    max_attendees: int
    visibility: str          # "public" or "crew_only"
    created_at: datetime

MissionRSVP:
    id: str                  # Composite: "usr_abc123_msn_xyz789"
    user_id: str
    mission_id: str
    status: str              # "going", "maybe", "not_going"
    updated_at: datetime
```

---

## Request Flow

Here's how a typical request flows through the system:

```
1. Client sends request
        │
        ▼
2. main.py routes to correct Blueprint
        │
        ▼
3. API layer (api/*.py)
   ├── @require_auth decorator validates JWT
   ├── Validates request body
   └── Calls service method
        │
        ▼
4. Service layer (services/*.py)
   ├── Implements business logic
   ├── Calls model methods
   └── Returns result or raises exception
        │
        ▼
5. Data layer (models/models.py)
   ├── Queries/updates Datastore
   └── Returns entity or None
        │
        ▼
6. Response flows back up
   └── API layer formats as JSON
        │
        ▼
7. Client receives response
```

**Example: User joins a crew**

```
POST /api/v1/crews/crew_abc123/join
Authorization: Bearer eyJ...

1. Request hits api/crews.py → join_crew()
2. @require_auth extracts user_id from JWT
3. Calls CrewService.join_crew(user_id, crew_id)
4. Service checks:
   - Does crew exist?
   - Is crew full?
   - Is user already a member?
5. Service creates CrewMember entity
6. Service increments crew.member_count
7. Returns success response
```

---

## Utilities

### Authentication (`utils/auth.py`)

```python
# Decorator to protect routes
@require_auth
def protected_route(user_id):
    # user_id is automatically extracted from JWT
    pass

# Helper functions
create_access_token(user_id) → str
create_refresh_token(user_id) → str
verify_token(token) → dict or None
```

### Responses (`utils/responses.py`)

```python
# Consistent response formatting
success(data) → {"success": True, "data": data}
error(code, message, status) → {"success": False, "error": {...}}
```

### Validators (`utils/validators.py`)

```python
# Input validation
validate_phone_number(phone) → bool
validate_profile_data(data) → (bool, errors)
validate_crew_data(data) → (bool, errors)
```

---

## External Services

| Service | Purpose | Used By |
|---------|---------|---------|
| **Twilio** (or similar) | Send SMS verification codes | auth_service.py |
| **Google Cloud Storage** | Store user photos | storage_service.py |
| **OpenAI API** (optional) | Enhanced matching suggestions | matching_service.py |

---

## Configuration

Environment variables (set in `app.yaml` or locally):

```yaml
env_variables:
  PROJECT_ID: "orbit-app"
  JWT_SECRET: "your-secret-key"
  TWILIO_ACCOUNT_SID: "..."
  TWILIO_AUTH_TOKEN: "..."
  TWILIO_PHONE_NUMBER: "+1..."
  GCS_BUCKET_NAME: "orbit-photos"
```

---

## Testing Strategy

Tests mirror the source structure:

| Test File | What It Tests |
|-----------|---------------|
| `test_auth.py` | SMS flow, token generation, token refresh |
| `test_users.py` | Profile CRUD, photo upload |
| `test_crews.py` | Crew creation, join/leave, permissions |
| `test_missions.py` | Mission CRUD, RSVP logic |
| `test_discover.py` | Matching algorithm, suggestions |

**Running tests:**
```bash
# Run all tests
pytest tests/

# Run specific test file
pytest tests/test_auth.py

# Run with coverage
pytest --cov=. tests/
```
