# Orbit API Documentation

## Overview

### Base URL
```
Production: https://orbit-app.uc.r.appspot.com/api/v1
Development: http://localhost:8080/api/v1
```

### Authentication
Orbit uses **SMS-based authentication** with JWT tokens.

1. User requests a verification code sent to their phone number
2. User submits the code to verify their identity
3. Server returns an access token (short-lived) and refresh token (long-lived)
4. Client includes the access token in all authenticated requests via the `Authorization` header

**Header format:**
```
Authorization: Bearer <access_token>
```

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
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid access token |
| `TOKEN_EXPIRED` | 401 | Access token has expired; use refresh token |
| `FORBIDDEN` | 403 | User lacks permission for this action |
| `NOT_FOUND` | 404 | Requested resource does not exist |
| `VALIDATION_ERROR` | 400 | Request body failed validation |
| `RATE_LIMITED` | 429 | Too many requests; slow down |
| `SERVER_ERROR` | 500 | Internal server error |

---

## Authentication

### Send Verification Code

Sends a 6-digit SMS verification code to the provided phone number.

```
POST /auth/send-code
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `phone_number` | string | Yes | Phone number in E.164 format (e.g., "+14155551234") |

**Example Request:**
```json
{
  "phone_number": "+14155551234"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Verification code sent",
    "expires_in": 300
  }
}
```

**Errors:**
| Code | Description |
|------|-------------|
| `INVALID_PHONE_NUMBER` | Phone number format is invalid |
| `RATE_LIMITED` | Too many code requests; wait before retrying |

---

### Verify Code

Verifies the SMS code and returns authentication tokens. Creates a new user if this is a new phone number.

```
POST /auth/verify-code
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `phone_number` | string | Yes | Phone number in E.164 format |
| `code` | string | Yes | 6-digit verification code |

**Example Request:**
```json
{
  "phone_number": "+14155551234",
  "code": "123456"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJl...",
    "expires_in": 3600,
    "is_new_user": true,
    "user": {
      "id": "usr_abc123",
      "phone_number": "+14155551234",
      "profile_complete": false
    }
  }
}
```

**Errors:**
| Code | Description |
|------|-------------|
| `INVALID_CODE` | Verification code is incorrect |
| `CODE_EXPIRED` | Verification code has expired |

---

### Refresh Token

Exchanges a refresh token for a new access token.

```
POST /auth/refresh
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
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 3600
  }
}
```

**Errors:**
| Code | Description |
|------|-------------|
| `INVALID_REFRESH_TOKEN` | Refresh token is invalid or revoked |

---

### Logout

Revokes the current refresh token.

```
POST /auth/logout
```

**Headers:** Requires `Authorization`

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

---

## Users & Profiles

### Get Current User Profile

Returns the authenticated user's full profile.

```
GET /users/me
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "id": "usr_abc123",
    "phone_number": "+14155551234",
    "profile_complete": true,
    "created_at": "2025-01-15T10:30:00Z",
    "profile": {
      "name": "Alex Chen",
      "age": 26,
      "location": {
        "city": "San Francisco",
        "state": "CA",
        "coordinates": {
          "lat": 37.7749,
          "lng": -122.4194
        }
      },
      "bio": "Software engineer who loves hiking and board games",
      "photos": [
        "https://storage.googleapis.com/orbit-photos/usr_abc123/1.jpg"
      ],
      "interests": ["hiking", "board games", "cooking", "tech"],
      "personality": {
        "introvert_extrovert": 0.6,
        "spontaneous_planner": 0.3,
        "active_relaxed": 0.7
      },
      "social_preferences": {
        "group_size": "small",
        "meeting_frequency": "weekly",
        "preferred_times": ["weekday_evenings", "weekends"]
      },
      "friendship_goals": ["activity_partners", "close_friends"]
    }
  }
}
```

---

### Update Profile

Updates the authenticated user's profile. Supports partial updates.

```
PATCH /users/me/profile
```

**Headers:** Requires `Authorization`

**Request Body (all fields optional):**
| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name (2-50 characters) |
| `age` | integer | Age in years (18-99) |
| `location` | object | City, state, and optional coordinates |
| `bio` | string | Short bio (max 500 characters) |
| `interests` | array[string] | List of interests (max 20) |
| `personality` | object | Personality trait scores (0.0-1.0) |
| `social_preferences` | object | Social preferences |
| `friendship_goals` | array[string] | What user is looking for |

**Example Request:**
```json
{
  "name": "Alex Chen",
  "age": 26,
  "interests": ["hiking", "board games", "cooking"],
  "personality": {
    "introvert_extrovert": 0.6,
    "spontaneous_planner": 0.3,
    "active_relaxed": 0.7
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
| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | One or more fields failed validation |

---

### Upload Photo

Uploads a profile photo. Returns a URL to the uploaded image.

```
POST /users/me/photos
```

**Headers:** Requires `Authorization`

**Request:** Multipart form data with `photo` field (JPEG/PNG, max 10MB)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "photo_url": "https://storage.googleapis.com/orbit-photos/usr_abc123/2.jpg",
    "photo_index": 1
  }
}
```

---

### Delete Photo

Deletes a profile photo by index.

```
DELETE /users/me/photos/{photo_index}
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Photo deleted"
  }
}
```

---

### Get User Profile (Public)

Returns another user's public profile.

```
GET /users/{user_id}
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "id": "usr_xyz789",
    "profile": {
      "name": "Jordan Lee",
      "age": 24,
      "location": {
        "city": "San Francisco",
        "state": "CA"
      },
      "bio": "Coffee enthusiast and amateur photographer",
      "photos": ["..."],
      "interests": ["photography", "coffee", "hiking"],
      "friendship_goals": ["activity_partners"]
    }
  }
}
```

**Note:** Public profiles exclude sensitive data like exact coordinates and phone number.

---

## Crews

### List My Crews

Returns all crews the authenticated user is a member of.

```
GET /crews
```

**Headers:** Requires `Authorization`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 20 | Max results (1-50) |
| `cursor` | string | - | Pagination cursor |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "crews": [
      {
        "id": "crew_abc123",
        "name": "SF Hiking Crew",
        "description": "Weekly hikes around the Bay Area",
        "interest_tags": ["hiking", "outdoors", "nature"],
        "member_count": 5,
        "max_members": 8,
        "created_at": "2025-01-10T08:00:00Z",
        "last_activity_at": "2025-01-28T14:30:00Z",
        "my_role": "member",
        "preview_members": [
          { "id": "usr_1", "name": "Alex", "photo": "..." },
          { "id": "usr_2", "name": "Jordan", "photo": "..." }
        ]
      }
    ],
    "next_cursor": "eyJsYXN0X2lkIjoi..."
  }
}
```

---

### Get Crew Details

Returns full details for a specific crew.

```
GET /crews/{crew_id}
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "id": "crew_abc123",
    "name": "SF Hiking Crew",
    "description": "Weekly hikes around the Bay Area",
    "interest_tags": ["hiking", "outdoors", "nature"],
    "member_count": 5,
    "max_members": 8,
    "created_at": "2025-01-10T08:00:00Z",
    "created_by": "usr_xyz789",
    "members": [
      {
        "id": "usr_1",
        "name": "Alex Chen",
        "photo": "...",
        "role": "admin",
        "joined_at": "2025-01-10T08:00:00Z"
      },
      {
        "id": "usr_2",
        "name": "Jordan Lee",
        "photo": "...",
        "role": "member",
        "joined_at": "2025-01-12T10:15:00Z"
      }
    ],
    "upcoming_missions": [
      { "id": "msn_1", "title": "Muir Woods Hike", "date": "2025-02-05T09:00:00Z" }
    ],
    "is_member": true,
    "my_role": "member"
  }
}
```

---

### Create Crew

Creates a new crew. The creator becomes the admin.

```
POST /crews
```

**Headers:** Requires `Authorization`

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Crew name (3-50 characters) |
| `description` | string | No | Description (max 500 characters) |
| `interest_tags` | array[string] | Yes | 1-5 interest tags |
| `max_members` | integer | No | Max size, default 8 (3-8) |

**Example Request:**
```json
{
  "name": "SF Hiking Crew",
  "description": "Weekly hikes around the Bay Area",
  "interest_tags": ["hiking", "outdoors"],
  "max_members": 8
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "id": "crew_abc123",
    "name": "SF Hiking Crew",
    ...
  }
}
```

---

### Join Crew

Joins an existing crew.

```
POST /crews/{crew_id}/join
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Successfully joined crew",
    "crew_id": "crew_abc123"
  }
}
```

**Errors:**
| Code | Description |
|------|-------------|
| `CREW_FULL` | Crew has reached max members |
| `ALREADY_MEMBER` | User is already in this crew |

---

### Leave Crew

Leaves a crew. Admins cannot leave if they are the only admin.

```
POST /crews/{crew_id}/leave
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "message": "Successfully left crew"
  }
}
```

---

### Update Crew

Updates crew details. Only admins can update.

```
PATCH /crews/{crew_id}
```

**Headers:** Requires `Authorization`

**Request Body:** Same fields as create (all optional)

---

### Delete Crew

Deletes a crew. Only the original creator can delete.

```
DELETE /crews/{crew_id}
```

**Headers:** Requires `Authorization`

---

## Missions

### List Missions

Returns missions the user can see (their own, their crews', or public nearby).

```
GET /missions
```

**Headers:** Requires `Authorization`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `filter` | string | "all" | "all", "my_rsvp", "my_crews", "nearby" |
| `status` | string | "upcoming" | "upcoming", "past", "all" |
| `limit` | integer | 20 | Max results (1-50) |
| `cursor` | string | - | Pagination cursor |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "missions": [
      {
        "id": "msn_abc123",
        "title": "Board Game Night",
        "description": "Casual games at my place",
        "date": "2025-02-08T18:00:00Z",
        "location": {
          "name": "Alex's Apartment",
          "address": "123 Main St, SF",
          "coordinates": { "lat": 37.77, "lng": -122.41 }
        },
        "interest_tags": ["board games", "social"],
        "crew_id": "crew_xyz789",
        "crew_name": "Game Night Gang",
        "host": {
          "id": "usr_abc123",
          "name": "Alex Chen",
          "photo": "..."
        },
        "rsvp_count": 4,
        "max_attendees": 6,
        "my_rsvp": "going",
        "created_at": "2025-01-25T10:00:00Z"
      }
    ],
    "next_cursor": "..."
  }
}
```

---

### Get Mission Details

Returns full details for a specific mission.

```
GET /missions/{mission_id}
```

**Headers:** Requires `Authorization`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "id": "msn_abc123",
    "title": "Board Game Night",
    "description": "Casual games at my place. Bring snacks!",
    "date": "2025-02-08T18:00:00Z",
    "location": { ... },
    "interest_tags": ["board games", "social"],
    "crew_id": "crew_xyz789",
    "host": { ... },
    "attendees": [
      { "id": "usr_1", "name": "Alex", "photo": "...", "rsvp": "going" },
      { "id": "usr_2", "name": "Jordan", "photo": "...", "rsvp": "maybe" }
    ],
    "rsvp_count": 4,
    "max_attendees": 6,
    "my_rsvp": "going",
    "is_host": false
  }
}
```

---

### Create Mission

Creates a new mission. Can be standalone or associated with a crew.

```
POST /missions
```

**Headers:** Requires `Authorization`

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Mission title (3-100 characters) |
| `description` | string | No | Description (max 1000 characters) |
| `date` | string | Yes | ISO 8601 datetime |
| `location` | object | Yes | Name, address, and/or coordinates |
| `interest_tags` | array[string] | No | 0-5 interest tags |
| `crew_id` | string | No | Associate with a crew |
| `max_attendees` | integer | No | Max attendees (2-20) |
| `visibility` | string | No | "crew_only" or "public" (default) |

**Example Request:**
```json
{
  "title": "Board Game Night",
  "description": "Casual games at my place. Bring snacks!",
  "date": "2025-02-08T18:00:00Z",
  "location": {
    "name": "Alex's Apartment",
    "address": "123 Main St, San Francisco, CA"
  },
  "interest_tags": ["board games"],
  "crew_id": "crew_xyz789",
  "max_attendees": 6,
  "visibility": "crew_only"
}
```

---

### RSVP to Mission

Sets or updates the user's RSVP status.

```
POST /missions/{mission_id}/rsvp
```

**Headers:** Requires `Authorization`

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | Yes | "going", "maybe", or "not_going" |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "mission_id": "msn_abc123",
    "rsvp": "going",
    "rsvp_count": 5
  }
}
```

**Errors:**
| Code | Description |
|------|-------------|
| `MISSION_FULL` | Mission has reached max attendees |
| `MISSION_PAST` | Cannot RSVP to past missions |

---

### Update Mission

Updates mission details. Only the host can update.

```
PATCH /missions/{mission_id}
```

**Headers:** Requires `Authorization`

---

### Delete Mission

Cancels/deletes a mission. Only the host can delete.

```
DELETE /missions/{mission_id}
```

**Headers:** Requires `Authorization`

---

## Matching & Discovery

### Get Suggested Users

Returns AI-matched user suggestions based on compatibility.

```
GET /discover/users
```

**Headers:** Requires `Authorization`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 10 | Max results (1-20) |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "user": {
          "id": "usr_xyz789",
          "name": "Jordan Lee",
          "age": 24,
          "photo": "...",
          "bio": "Coffee enthusiast...",
          "interests": ["photography", "coffee", "hiking"]
        },
        "compatibility": {
          "score": 0.87,
          "shared_interests": ["hiking", "coffee"],
          "reasons": [
            "You both enjoy outdoor activities",
            "Similar social preferences"
          ]
        }
      }
    ]
  }
}
```

---

### Get Suggested Crews

Returns AI-recommended crews based on user's interests.

```
GET /discover/crews
```

**Headers:** Requires `Authorization`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 10 | Max results (1-20) |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "crew": {
          "id": "crew_abc123",
          "name": "SF Hiking Crew",
          "description": "Weekly hikes...",
          "interest_tags": ["hiking", "outdoors"],
          "member_count": 5,
          "preview_members": [...]
        },
        "compatibility": {
          "score": 0.92,
          "matching_interests": ["hiking", "outdoors"],
          "reasons": ["Matches your interest in hiking"]
        }
      }
    ]
  }
}
```

---

### Get Suggested Missions

Returns AI-recommended missions based on interests and availability.

```
GET /discover/missions
```

**Headers:** Requires `Authorization`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 10 | Max results (1-20) |

**Example Response:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "mission": {
          "id": "msn_abc123",
          "title": "Photography Walk",
          "date": "2025-02-10T10:00:00Z",
          "location": { "name": "Golden Gate Park" },
          "host": { "id": "usr_1", "name": "Sam", "photo": "..." },
          "rsvp_count": 3,
          "max_attendees": 8
        },
        "compatibility": {
          "score": 0.85,
          "reasons": ["Matches your interest in photography"]
        }
      }
    ]
  }
}
```

---

## Data Types Reference

### Location Object
```json
{
  "city": "San Francisco",
  "state": "CA",
  "coordinates": {
    "lat": 37.7749,
    "lng": -122.4194
  }
}
```

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
  "group_size": "small" | "medium" | "large",
  "meeting_frequency": "weekly" | "biweekly" | "monthly" | "flexible",
  "preferred_times": ["weekday_evenings", "weekends", "mornings"]
}
```

### Friendship Goals
Valid values: `"activity_partners"`, `"close_friends"`, `"networking"`, `"explore_city"`, `"workout_buddy"`

### RSVP Status
Valid values: `"going"`, `"maybe"`, `"not_going"`

### Crew Roles
Valid values: `"admin"`, `"member"`
