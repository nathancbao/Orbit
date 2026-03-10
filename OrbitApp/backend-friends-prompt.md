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

### 9. GET /api/friends/search?q={query}
Search for users by email or name. Used for the "Find Friends" feature.

**Query parameter:** `q` — at least 3 characters. Search against both `email` and `name` fields (case-insensitive, partial match).

**Response `data`:**
```json
[
  {
    "user_id": 99,
    "name": "Alex Chen",
    "college_year": "junior",
    "interests": ["Hiking", "Coffee"],
    "photo": "https://storage.googleapis.com/...",
    "bio": "Coffee enthusiast"
  }
]
```

**Logic:**
1. Query the user/profile entities where `email` contains `q` OR `name` contains `q` (case-insensitive)
2. Exclude the authenticated user from results
3. Limit to 20 results
4. Return `FriendProfile` shape for each match

**Note:** This is authenticated so we know who's searching, but it returns any matching user regardless of friend status. The frontend handles filtering out existing friends.

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

## Deep Link Route — `GET /friend/<user_id>`

This is the URL users share (via QR code or copy-link) to let others add them as a friend. When someone opens this link in a browser, the backend should:

1. **Look up the user** by `user_id`. If the user doesn't exist, show a simple error page ("User not found").
2. **Render a lightweight HTML page** that shows:
   - The user's name and profile photo (if available)
   - A message like "**Alex Chen** invited you to connect on Orbit"
   - A big "Open in Orbit" button that attempts to open the iOS app via a custom URL scheme or universal link (e.g., `orbit://friend/<user_id>`)
   - A fallback message: "Don't have Orbit? Download it here." (link to App Store once available)
3. **No authentication required** — this is a public page so anyone can view it.
4. This route should NOT live under `/api/` — just `GET /friend/<user_id>` at the top level.

This does NOT auto-send a friend request. It just gets the person into the app where they can view the profile and tap "Add Friend" themselves.
