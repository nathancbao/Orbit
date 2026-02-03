# Orbit API Documentation

## Overview

### Base URL
```
Production: https://orbit-app-486204.wl.r.appspot.com/api
Development: http://localhost:8080/api
```

### Authentication
Orbit uses **.edu email verification** with JWT tokens.

1. User provides their `.edu` email address
2. Server sends a 6-digit verification code to that email (via SendGrid; currently in demo mode)
3. User submits the code to verify their identity
4. Server returns an access token (15 min) and refresh token (7 days)
5. Client includes the access token in all authenticated requests via the `Authorization` header

**Header format:**
```
Authorization: Bearer <access_token>
```

**Demo mode:** The code `123456` is accepted as valid for any email, bypassing actual email verification.

### Standard Response Format

All endpoints return responses in this structure:

**Success:**
```json
{
  "success": true,
  "data": { ... }
}
```

**Error:**
```json
{
  "success": false,
  "error": "Human-readable error message"
}
```

Note: The error field is usually a plain string. For validation errors (profile, crew, mission), it may be an array of error strings.

### Common HTTP Status Codes

| HTTP Status | Description |
|-------------|-------------|
| 200 | Success |
| 201 | Created (new crew/mission) |
| 400 | Validation error or bad request |
| 401 | Missing, invalid, or expired access token |
| 404 | Resource not found |
| 500 | Internal server error |

---

## Authentication

### Send Verification Code

Sends a 6-digit verification code to the provided .edu email address.

```
POST /api/auth/send-code
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | A valid `.edu` email address |

**Example Request:**
```json
{
  "email": "alex@university.edu"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Verification code sent"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "Email is required" |
| 400 | "Invalid email format" |
| 400 | "Only .edu email addresses are allowed" |
| 500 | "Failed to send verification code: ..." |

---

### Verify Code

Verifies the email code and returns authentication tokens. Creates a new user if this is a new email.

```
POST /api/auth/verify-code
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | The .edu email address |
| `code` | string | Yes | 6-digit verification code (or "123456" for demo bypass) |

**Example Request:**
```json
{
  "email": "alex@university.edu",
  "code": "123456"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 900,
    "is_new_user": true,
    "user_id": 5629499534213120
  }
}
```

**Notes:**
- `expires_in` is 900 seconds (15 minutes) for access tokens
- `user_id` is a numeric Datastore auto-generated ID
- `is_new_user` indicates whether this email was seen for the first time

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "Email and code are required" |
| 400 | "No verification code found for this email" |
| 400 | "Verification code has expired" |
| 400 | "Invalid verification code" |

---

### Refresh Token

Exchanges a refresh token for a new access token.

```
POST /api/auth/refresh
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `refresh_token` | string | Yes | Valid refresh token |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "refresh_token is required" |
| 401 | "Invalid refresh token" |
| 401 | "Token has expired" |
| 401 | "Invalid token type" |

---

### Logout

Revokes the refresh token.

```
POST /api/auth/logout
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `refresh_token` | string | Yes | Refresh token to revoke |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "refresh_token is required" |

---

## Users & Profiles

### Get Current User Profile

Returns the authenticated user's profile data and completeness status.

```
GET /api/users/me
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "profile": {
      "name": "Alex Chen",
      "age": 22,
      "location": {
        "city": "Davis",
        "state": "CA",
        "coordinates": null
      },
      "bio": "CS major who loves hiking and photography",
      "photos": [
        "https://storage.googleapis.com/orbit-app-486204-photos/profile_photos/abc123.jpg"
      ],
      "interests": ["Hiking", "Photography", "Coffee", "Coding"],
      "personality": {
        "introvert_extrovert": 0.6,
        "spontaneous_planner": 0.4,
        "active_relaxed": 0.7
      },
      "social_preferences": {
        "group_size": "Small groups (3-5)",
        "meeting_frequency": "Weekly",
        "preferred_times": ["Weekends", "Evenings"]
      },
      "friendship_goals": []
    },
    "profile_complete": true
  }
}
```

**Profile completeness** requires: a non-empty name, at least 3 interests, and at least one preferred time.

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 404 | "User not found" |
| 404 | "Profile not found" (no profile saved yet) |

---

### Update Profile

Creates or updates the authenticated user's profile. Supports full or partial updates.

```
PUT /api/users/me
```

**Headers:** Requires `Authorization`

**Request Body (all fields optional):**
| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name (max 100 characters) |
| `age` | integer | Age in years (18–100) |
| `location` | object | `{ city, state, coordinates }` |
| `bio` | string | Short bio (max 500 characters) |
| `photos` | array[string] | Photo URLs (max 6) |
| `interests` | array[string] | List of interests (max 10) |
| `personality` | object | `{ introvert_extrovert, spontaneous_planner, active_relaxed }` (0.0–1.0) |
| `social_preferences` | object | `{ group_size, meeting_frequency, preferred_times }` |
| `friendship_goals` | array[string] | What user is looking for |

**Example Request:**
```json
{
  "name": "Alex Chen",
  "age": 22,
  "interests": ["Hiking", "Photography", "Coffee"],
  "personality": {
    "introvert_extrovert": 0.6,
    "spontaneous_planner": 0.4,
    "active_relaxed": 0.7
  },
  "social_preferences": {
    "group_size": "Small groups (3-5)",
    "meeting_frequency": "Weekly",
    "preferred_times": ["Weekends", "Evenings"]
  }
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "profile": { ... },
    "profile_complete": true
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "No data provided" |
| 400 | Validation error list (e.g. `["name must be a non-empty string", "age must be a number between 18 and 100"]`) |

---

### Upload Photo

Uploads a profile photo to Google Cloud Storage. Adds the public URL to the user's photos list.

```
POST /api/users/me/photo
```

**Headers:** Requires `Authorization`

**Request:** Multipart form data with `photo` field

**Example Response:**
```json
{
  "success": true,
  "data": {
    "profile": { ... },
    "profile_complete": true
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "No photo file provided" |
| 400 | "No file selected" |

---

### Get User Profile (Public)

Returns another user's profile by ID. Does not require authentication.

```
GET /api/users/{user_id}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "profile": {
      "name": "Jordan Lee",
      "age": 21,
      "location": { "city": "Davis", "state": "CA", "coordinates": null },
      "bio": "Film student and amateur chef",
      "photos": [],
      "interests": ["Movies", "Cooking", "Music"],
      "personality": { ... },
      "social_preferences": { ... },
      "friendship_goals": []
    },
    "profile_complete": true
  }
}
```

---

## Crews

### Create Crew

Creates a new crew. The creator is automatically added as a member.

```
POST /api/crews/
```

**Headers:** Requires `Authorization`

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Crew name (max 100 characters) |
| `description` | string | No | Description (max 500 characters) |
| `tags` | array[string] | No | Interest tags for matching |

**Example Request:**
```json
{
  "name": "Davis Hiking Crew",
  "description": "Weekly hikes around Yolo County",
  "tags": ["hiking", "outdoors"]
}
```

**Example Response (201):**
```json
{
  "success": true,
  "data": {
    "id": 5629499534213120,
    "name": "Davis Hiking Crew",
    "description": "Weekly hikes around Yolo County",
    "tags": ["hiking", "outdoors"],
    "creator_id": 4785074604081152,
    "member_count": 1,
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | Validation error list (e.g. `["name is required"]`) |

---

### List Crews

Returns all crews, optionally filtered by tag.

```
GET /api/crews/
```

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `tag` | string | Filter crews that contain this tag |

**Example Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 5629499534213120,
      "name": "Davis Hiking Crew",
      "description": "Weekly hikes around Yolo County",
      "tags": ["hiking", "outdoors"],
      "creator_id": 4785074604081152,
      "member_count": 3,
      "created_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

Note: Returns a flat array of crew objects, limited to 50 results.

---

### Join Crew

Joins an existing crew.

```
POST /api/crews/{crew_id}/join
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Joined crew successfully"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "Crew not found" |
| 400 | "Already a member of this crew" |

---

### Leave Crew

Leaves a crew.

```
POST /api/crews/{crew_id}/leave
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Left crew successfully"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "Crew not found" |
| 400 | "Not a member of this crew" |

---

## Missions

### Create Mission

Creates a new mission/event.

```
POST /api/missions/
```

**Headers:** Requires `Authorization`

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Mission title (max 200 characters) |
| `description` | string | Yes | Description |
| `tags` | array[string] | No | Interest tags for matching |
| `location` | string | No | Free-text location |
| `time` | string | No | Free-text time/date |

**Example Request:**
```json
{
  "title": "Board Game Night",
  "description": "Casual games at the student lounge",
  "tags": ["board games", "social"],
  "location": "Student Union Room 204",
  "time": "Friday 7pm"
}
```

**Example Response (201):**
```json
{
  "success": true,
  "data": {
    "id": 5629499534213120,
    "title": "Board Game Night",
    "description": "Casual games at the student lounge",
    "tags": ["board games", "social"],
    "location": "Student Union Room 204",
    "time": "Friday 7pm",
    "creator_id": 4785074604081152,
    "rsvp_count": 0,
    "created_at": "2025-01-25T10:00:00Z"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | Validation error list (e.g. `["title is required", "description is required"]`) |

---

### List Missions

Returns all missions, optionally filtered by tag.

```
GET /api/missions/
```

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `tag` | string | Filter missions that contain this tag |

**Example Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 5629499534213120,
      "title": "Board Game Night",
      "description": "Casual games at the student lounge",
      "tags": ["board games", "social"],
      "location": "Student Union Room 204",
      "time": "Friday 7pm",
      "creator_id": 4785074604081152,
      "rsvp_count": 3,
      "created_at": "2025-01-25T10:00:00Z"
    }
  ]
}
```

Note: Returns a flat array of mission objects, limited to 50 results.

---

### RSVP to Mission

Adds the user's RSVP to a mission.

```
POST /api/missions/{mission_id}/rsvp
```

**Headers:** Requires `Authorization`

**Request Body:** None required.

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "RSVPed to mission successfully"
  }
}
```

**Errors:**
| HTTP Status | Error Message |
|-------------|---------------|
| 400 | "Mission not found" |
| 400 | "Already RSVPed to this mission" |

---

## Matching & Discovery

### Get Suggested Users

Returns user profiles ranked by interest overlap with the current user.

```
GET /api/discover/users
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "Jordan Lee",
      "age": 21,
      "location": { "city": "Davis", "state": "CA", "coordinates": null },
      "bio": "Film student and amateur chef",
      "photos": [],
      "interests": ["Movies", "Cooking", "Music", "Art", "Food"],
      "personality": {
        "introvert_extrovert": 0.4,
        "spontaneous_planner": 0.7,
        "active_relaxed": 0.5
      },
      "social_preferences": {
        "group_size": "One-on-one",
        "meeting_frequency": "Bi-weekly",
        "preferred_times": ["Evenings"]
      },
      "friendship_goals": []
    }
  ]
}
```

Note: Returns a flat array of Profile objects (up to 20), sorted by number of shared interests (descending). Excludes users without a name and the requesting user.

---

### Get Suggested Crews

Returns crews ranked by interest overlap with the current user.

```
GET /api/discover/crews
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 5629499534213120,
      "name": "Davis Hiking Crew",
      "description": "Weekly hikes",
      "tags": ["hiking", "outdoors"],
      "creator_id": 4785074604081152,
      "member_count": 3,
      "match_score": 2,
      "created_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

Note: Returns crew objects with an added `match_score` field (count of shared tags), up to 20 results.

---

### Get Suggested Missions

Returns missions ranked by interest overlap with the current user.

```
GET /api/discover/missions
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 5629499534213120,
      "title": "Photography Walk",
      "description": "Explore campus with cameras",
      "tags": ["photography", "outdoors"],
      "location": "Main Quad",
      "time": "Saturday 10am",
      "creator_id": 4785074604081152,
      "rsvp_count": 3,
      "match_score": 1,
      "created_at": "2025-01-20T08:00:00Z"
    }
  ]
}
```

Note: Returns mission objects with an added `match_score` field (count of shared tags), up to 20 results.

---

## Data Types Reference

### Profile Fields
| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Max 100 chars |
| `age` | integer | 18–100 |
| `location` | object | `{ city, state, coordinates }` |
| `bio` | string | Max 500 chars |
| `photos` | array[string] | Max 6, GCS public URLs |
| `interests` | array[string] | Max 10 |
| `personality` | object | Three 0.0–1.0 float scales |
| `social_preferences` | object | Group size, frequency, times |
| `friendship_goals` | array[string] | Free-form strings |

### Personality Object
All values are floats from 0.0 to 1.0:
```json
{
  "introvert_extrovert": 0.6,
  "spontaneous_planner": 0.3,
  "active_relaxed": 0.7
}
```

### Social Preferences Object
```json
{
  "group_size": "Small groups (3-5)",
  "meeting_frequency": "Weekly",
  "preferred_times": ["Weekends", "Evenings", "Mornings", "Afternoons"]
}
```

### Entity IDs
All entity IDs (users, crews, missions) are **numeric** auto-generated Datastore IDs (e.g., `5629499534213120`). Join entity IDs (CrewMember, MissionRSVP) are composite strings like `"{parent_id}_{user_id}"`.
