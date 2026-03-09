# Backend: Friends Feature API

Implement a friends system with friend requests. All endpoints are authenticated (require `@require_auth` decorator) and return the standard `{ "success": true, "data": ... }` wrapper.

## Data Models (Datastore Entities)

### FriendRequest
```
Kind: FriendRequest
Fields:
  - from_user_id: int (sender)
  - to_user_id: int (recipient)
  - status: string ("pending" | "accepted" | "declined")
  - created_at: string (ISO 8601)
```

### Friendship
```
Kind: Friendship
Fields:
  - user_id: int
  - friend_id: int
  - created_at: string (ISO 8601)
```

When a request is accepted, create TWO Friendship entities (one for each direction: user_id=A/friend_id=B and user_id=B/friend_id=A). This makes querying "my friends" a simple single-property filter.

## API Endpoints

### 1. GET /api/friends
Return all accepted friends for the authenticated user with enriched profiles.

**Response `data`:**
```json
[
  {
    "id": 1,
    "user_id": 42,
    "friend_id": 99,
    "created_at": "2026-03-09T12:00:00Z",
    "friend": {
      "user_id": 99,
      "name": "Alex Chen",
      "college_year": "junior",
      "interests": ["Hiking", "Coffee"],
      "photo": "https://storage.googleapis.com/...",
      "bio": "Coffee enthusiast"
    }
  }
]
```

Query: `Friendship` where `user_id == g.user_id`. For each result, fetch the friend's profile using `get_user_profile(friend_id)` and attach as `friend`.

### 2. POST /api/friends/requests
Send a friend request.

**Request body:**
```json
{ "to_user_id": 99 }
```

**Validation:**
- Cannot send to yourself
- Cannot send if a pending request already exists (in either direction)
- Cannot send if already friends

**Response `data`:** The created `FriendRequest` entity with `from_user` and `to_user` profiles enriched.

### 3. GET /api/friends/requests/incoming
Return pending requests sent TO the authenticated user.

**Response `data`:**
```json
[
  {
    "id": 5,
    "from_user_id": 77,
    "to_user_id": 42,
    "status": "pending",
    "created_at": "2026-03-09T12:00:00Z",
    "from_user": {
      "user_id": 77,
      "name": "Jordan Lee",
      "college_year": "sophomore",
      "interests": ["Gaming", "Music"],
      "photo": null,
      "bio": ""
    }
  }
]
```

Query: `FriendRequest` where `to_user_id == g.user_id` and `status == "pending"`. Enrich each with `from_user` profile.

### 4. GET /api/friends/requests/outgoing
Return pending requests sent BY the authenticated user.

Same shape as incoming but enrich with `to_user` profile instead.

Query: `FriendRequest` where `from_user_id == g.user_id` and `status == "pending"`.

### 5. POST /api/friends/requests/{request_id}/accept
Accept an incoming friend request.

**Validation:**
- Request must exist and have `to_user_id == g.user_id`
- Request must be in `pending` status

**Actions:**
1. Update `FriendRequest.status` to `"accepted"`
2. Create two `Friendship` entities (bidirectional)
3. Return the newly created `Friendship` entity (with `friend` profile enriched)

### 6. POST /api/friends/requests/{request_id}/decline
Decline an incoming friend request.

**Validation:** Same as accept.

**Actions:** Update `FriendRequest.status` to `"declined"`.

**Response `data`:** `{}` (empty object)

### 7. DELETE /api/friends/{friendship_id}
Remove a friend.

**Validation:** Friendship must exist and `user_id == g.user_id`.

**Actions:** Delete BOTH directional Friendship entities.

**Response `data`:** `{}` (empty object)

### 8. GET /api/friends/status/{user_id}
Check the friendship status between the authenticated user and another user.

**Response `data`:**
```json
{
  "status": "none",
  "request_id": null
}
```

Status values:
- `"none"` — no relationship
- `"pending_sent"` — current user sent a request (include `request_id`)
- `"pending_received"` — other user sent a request (include `request_id`)
- `"friends"` — already friends

Logic:
1. Check `Friendship` where `user_id == g.user_id` and `friend_id == target_user_id` → if found, return `"friends"`
2. Check `FriendRequest` where `from_user_id == g.user_id` and `to_user_id == target` and `status == "pending"` → `"pending_sent"`
3. Check `FriendRequest` where `from_user_id == target` and `to_user_id == g.user_id` and `status == "pending"` → `"pending_received"`
4. Otherwise → `"none"`

## FriendProfile Shape
The `friend`, `from_user`, and `to_user` embedded objects should include:
```json
{
  "user_id": int,
  "name": string,
  "college_year": string,
  "interests": [string],
  "photo": string | null,
  "bio": string
}
```

This matches the existing `PodMember` enrichment pattern — pull from the user's profile entity.

## Blueprint Setup
Create a new blueprint file `api/friends.py` with `friends_bp = Blueprint('friends', __name__, url_prefix='/api/friends')` and register it in the app factory alongside the existing blueprints.

## Deep Link Route (Optional)
Add a web route `GET /friend/{user_id}` that redirects to the iOS app via Universal Link or shows a simple "Open in Orbit" page. This supports the QR code / share link feature on the frontend.
