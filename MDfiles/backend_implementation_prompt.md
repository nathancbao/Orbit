# Backend Implementation Prompt — Missions API + Missing Features

## Overview

The iOS frontend has a **Missions** feature fully built out with UI and data models, but it's currently using **hardcoded mock data**. We need you to implement the backend API and service layer to support it. Additionally, there are a few other missing backend features that need implementation.

---

## Part 1: Missions Feature (Priority: High)

### What is a Mission?

A Mission is a user-created activity request. Users specify what they want to do (category), when they're available (time slots), and how many people they want to do it with (group size). The system should eventually match users with overlapping availability and interests into groups.

### Data Model — `Mission` Entity (Datastore)

Create a new Datastore entity with the following fields:

```
Mission:
  id              : string (UUID)
  title           : string
  description     : string (optional, max 500 chars)
  activity_category: string enum ["Sports", "Food", "Movies", "Hangout", "Study", "Custom"]
  custom_activity_name: string (optional, only used when activity_category == "Custom")
  min_group_size  : int (2-10)
  max_group_size  : int (2-10, must be >= min_group_size)
  availability    : list of AvailabilitySlot objects (see below)
  status          : string enum ["pending_match", "matched"]
  creator_id      : int (user_id of creator)
  created_at      : ISO8601 timestamp
  updated_at      : ISO8601 timestamp
```

**AvailabilitySlot structure** (nested within availability array):
```
AvailabilitySlot:
  date        : string (ISO8601 date, e.g., "2026-03-15")
  time_blocks : list of strings ["morning", "afternoon", "evening"]
```

### API Endpoints — `/api/missions`

Create a new blueprint `missions.py` in `OrbitServer/api/` with these endpoints:

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| `GET` | `/api/missions` | List all missions for the current user | Required |
| `POST` | `/api/missions` | Create a new mission | Required |
| `GET` | `/api/missions/<id>` | Get a single mission by ID | Required |
| `PUT` | `/api/missions/<id>` | Update a mission (creator only) | Required |
| `DELETE` | `/api/missions/<id>` | Delete a mission (creator only) | Required |

### Request/Response Formats

**POST /api/missions** — Create Mission

Request body:
```json
{
  "activity_category": "Sports",
  "custom_activity_name": null,
  "title": "Pickup Basketball",
  "description": "Looking for people to play 5v5 at the ARC",
  "min_group_size": 4,
  "max_group_size": 10,
  "availability": [
    {
      "date": "2026-03-15",
      "time_blocks": ["afternoon", "evening"]
    },
    {
      "date": "2026-03-17",
      "time_blocks": ["morning"]
    }
  ]
}
```

Response (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid-string",
    "title": "Pickup Basketball",
    "description": "Looking for people to play 5v5 at the ARC",
    "activity_category": "Sports",
    "custom_activity_name": null,
    "min_group_size": 4,
    "max_group_size": 10,
    "availability": [...],
    "status": "pending_match",
    "creator_id": 123,
    "created_at": "2026-03-14T10:30:00Z"
  },
  "error": null
}
```

**GET /api/missions** — List User's Missions

Response (200):
```json
{
  "success": true,
  "data": [
    { ...mission object... },
    { ...mission object... }
  ],
  "error": null
}
```

Returns only missions where `creator_id == current_user_id`. Sort by `created_at` descending (newest first).

### Validation Rules

Add to `OrbitServer/utils/validators.py`:

```python
def validate_mission_data(data, is_update=False):
    """
    Validates mission creation/update data.
    Returns (is_valid: bool, errors: str or None)
    """
    errors = []

    if not is_update:
        # Required fields for creation
        if not data.get('activity_category'):
            errors.append("activity_category is required")
        if not data.get('availability') or len(data['availability']) == 0:
            errors.append("At least one availability slot is required")
        if not data.get('min_group_size'):
            errors.append("min_group_size is required")
        if not data.get('max_group_size'):
            errors.append("max_group_size is required")

    # Validate activity_category enum
    valid_categories = ["Sports", "Food", "Movies", "Hangout", "Study", "Custom"]
    if data.get('activity_category') and data['activity_category'] not in valid_categories:
        errors.append(f"activity_category must be one of: {valid_categories}")

    # Custom category requires custom_activity_name
    if data.get('activity_category') == 'Custom':
        if not data.get('custom_activity_name') or not data['custom_activity_name'].strip():
            errors.append("custom_activity_name is required when activity_category is Custom")

    # Group size validation
    min_size = data.get('min_group_size', 2)
    max_size = data.get('max_group_size', 4)
    if min_size < 2 or min_size > 10:
        errors.append("min_group_size must be between 2 and 10")
    if max_size < 2 or max_size > 10:
        errors.append("max_group_size must be between 2 and 10")
    if max_size < min_size:
        errors.append("max_group_size must be >= min_group_size")

    # Availability validation
    valid_time_blocks = ["morning", "afternoon", "evening"]
    for slot in data.get('availability', []):
        if not slot.get('date'):
            errors.append("Each availability slot must have a date")
        if not slot.get('time_blocks') or len(slot['time_blocks']) == 0:
            errors.append("Each availability slot must have at least one time_block")
        for tb in slot.get('time_blocks', []):
            if tb not in valid_time_blocks:
                errors.append(f"time_block must be one of: {valid_time_blocks}")

    # Description length
    if data.get('description') and len(data['description']) > 500:
        errors.append("description must be 500 characters or less")

    return (len(errors) == 0, "; ".join(errors) if errors else None)
```

### Service Layer

Create `OrbitServer/services/mission_service.py`:

```python
from OrbitServer.models.models import (
    create_mission, get_mission, update_mission, delete_mission,
    list_missions_for_user
)

def get_user_missions(user_id):
    """Return all missions created by this user, sorted by created_at desc."""
    return list_missions_for_user(user_id)

def create_new_mission(data, creator_id):
    """Create a new mission with pending_match status."""
    return create_mission(data, creator_id)

def get_mission_detail(mission_id):
    """Get a single mission by ID."""
    return get_mission(mission_id)

def edit_mission(mission_id, data, user_id):
    """Update a mission. Only the creator can edit."""
    mission = get_mission(mission_id)
    if not mission:
        return None, "Mission not found"
    if mission['creator_id'] != int(user_id):
        return None, "Only the creator can edit this mission"
    updated = update_mission(mission_id, data)
    return updated, None

def remove_mission(mission_id, user_id):
    """Delete a mission. Only the creator can delete."""
    mission = get_mission(mission_id)
    if not mission:
        return False, "Mission not found"
    if mission['creator_id'] != int(user_id):
        return False, "Only the creator can delete this mission"
    delete_mission(mission_id)
    return True, None
```

### Model Layer

Add to `OrbitServer/models/models.py`:

```python
import uuid
from datetime import datetime

def create_mission(data, creator_id):
    """Create a new Mission entity."""
    mission_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat() + 'Z'

    # Build title from category if not provided
    title = data.get('title', '')
    if not title and data.get('activity_category') == 'Custom':
        title = data.get('custom_activity_name', 'Custom Activity')
    elif not title:
        title = data.get('activity_category', 'Activity')

    entity = {
        'id': mission_id,
        'title': title,
        'description': data.get('description', ''),
        'activity_category': data['activity_category'],
        'custom_activity_name': data.get('custom_activity_name'),
        'min_group_size': data.get('min_group_size', 2),
        'max_group_size': data.get('max_group_size', 4),
        'availability': data.get('availability', []),
        'status': 'pending_match',
        'creator_id': int(creator_id),
        'created_at': now,
        'updated_at': now,
    }

    key = client.key('Mission', mission_id)
    mission_entity = datastore.Entity(key=key)
    mission_entity.update(entity)
    client.put(mission_entity)

    return entity

def get_mission(mission_id):
    """Get a mission by ID."""
    key = client.key('Mission', str(mission_id))
    entity = client.get(key)
    return _entity_to_dict(entity) if entity else None

def list_missions_for_user(user_id):
    """List all missions created by a user."""
    query = client.query(kind='Mission')
    query.add_filter('creator_id', '=', int(user_id))
    query.order = ['-created_at']
    results = list(query.fetch())
    return [_entity_to_dict(e) for e in results]

def update_mission(mission_id, data):
    """Update a mission's fields."""
    key = client.key('Mission', str(mission_id))
    entity = client.get(key)
    if not entity:
        return None

    allowed_fields = ['title', 'description', 'activity_category',
                      'custom_activity_name', 'min_group_size',
                      'max_group_size', 'availability', 'status']
    for field in allowed_fields:
        if field in data:
            entity[field] = data[field]

    entity['updated_at'] = datetime.utcnow().isoformat() + 'Z'
    client.put(entity)
    return _entity_to_dict(entity)

def delete_mission(mission_id):
    """Delete a mission."""
    key = client.key('Mission', str(mission_id))
    client.delete(key)
```

### Register Blueprint

In `main.py`, add:

```python
from OrbitServer.api.missions import missions_bp
app.register_blueprint(missions_bp)
```

### Tests

Create `tests/test_api_missions.py` with tests for:
- Create mission (valid data)
- Create mission (invalid data - missing required fields)
- Create mission (custom category without custom_activity_name)
- List missions (returns only user's own missions)
- Get single mission
- Update mission (creator)
- Update mission (non-creator - should 403)
- Delete mission (creator)
- Delete mission (non-creator - should 403)

---

## Part 2: Missing Backend Features (Priority: Medium)

### 2.1 — `/api/users/me/pods` Endpoint

The `MyEventsView` on iOS needs to display all pods the current user is in.

**Add to `users.py`:**

```python
@users_bp.route('/me/pods', methods=['GET'])
@require_auth
def get_my_pods():
    """Get all pods the current user is a member of."""
    pods = list_user_pods(g.user_id)
    return success(pods)
```

**Add to `models.py`:**

```python
def list_user_pods(user_id):
    """List all pods where user_id is in member_ids."""
    query = client.query(kind='EventPod')
    # Note: Datastore doesn't support array-contains directly,
    # so we fetch all and filter in Python
    results = list(query.fetch())
    user_pods = [
        _entity_to_dict(e) for e in results
        if int(user_id) in (e.get('member_ids') or [])
    ]
    # Sort by created_at descending
    user_pods.sort(key=lambda p: p.get('created_at', ''), reverse=True)
    return user_pods
```

### 2.2 — College Year Filter on Events

The `list_events()` function accepts a `year` filter but doesn't use it.

**Option A: Add `target_years` field to Event entity**

When creating events, allow specifying which college years can join:
```json
{
  "title": "Freshman Mixer",
  "target_years": ["freshman", "sophomore"]
}
```

Then filter in `list_events()`:
```python
if filters.get('year'):
    events = [e for e in events if not e.get('target_years')
              or filters['year'] in e['target_years']]
```

### 2.3 — Kick Replacement Logic

In `pod_service.py`, the `_find_replacement()` function is a stub. Implement it to:

1. Find users who have:
   - Joined the same event but are in a different pod
   - OR have similar interests to the kicked user
2. Return a candidate user_id or `None`

(This can be a simple implementation for now — just return the first matching user)

### 2.4 — Trust Score Penalties (Cron Job)

`apply_no_show_penalties()` exists but isn't called. Set up a Cloud Scheduler job:

- Schedule: Daily at midnight
- Target: `POST /api/internal/apply-penalties`
- Add an internal endpoint that calls `apply_no_show_penalties()`

### 2.5 — Chat Deletion Cron

Pods should have their chat messages deleted 48 hours after the pod expires.

**Add to `models.py`:**
```python
def delete_expired_pod_messages():
    """Delete messages from pods that expired > 48 hours ago."""
    cutoff = datetime.utcnow() - timedelta(hours=48)
    # Query pods with expires_at < cutoff
    # Delete all ChatMessages with those pod_ids
```

**Set up Cloud Scheduler:**
- Schedule: Every 6 hours
- Target: `POST /api/internal/cleanup-messages`

---

## Part 3: iOS Integration Notes

Once the backend is ready, the iOS app needs these changes:

### Create `MissionService.swift`

```swift
// OrbitApp/Orbit/Services/MissionService.swift

import Foundation

class MissionService {
    static let shared = MissionService()
    private let api = APIService.shared

    func listMissions() async throws -> [Mission] {
        let response: APIResponse<[Mission]> = try await api.request(
            endpoint: "/missions",
            method: "GET"
        )
        guard let data = response.data else {
            throw NetworkError.noData
        }
        return data
    }

    func createMission(_ mission: CreateMissionRequest) async throws -> Mission {
        let response: APIResponse<Mission> = try await api.request(
            endpoint: "/missions",
            method: "POST",
            body: mission
        )
        guard let data = response.data else {
            throw NetworkError.noData
        }
        return data
    }

    func deleteMission(id: String) async throws {
        let _: APIResponse<EmptyResponse> = try await api.request(
            endpoint: "/missions/\(id)",
            method: "DELETE"
        )
    }
}

struct CreateMissionRequest: Encodable {
    let activityCategory: String
    let customActivityName: String?
    let title: String
    let description: String
    let minGroupSize: Int
    let maxGroupSize: Int
    let availability: [AvailabilitySlotRequest]

    enum CodingKeys: String, CodingKey {
        case activityCategory = "activity_category"
        case customActivityName = "custom_activity_name"
        case title, description
        case minGroupSize = "min_group_size"
        case maxGroupSize = "max_group_size"
        case availability
    }
}

struct AvailabilitySlotRequest: Encodable {
    let date: String  // ISO8601 date string
    let timeBlocks: [String]

    enum CodingKeys: String, CodingKey {
        case date
        case timeBlocks = "time_blocks"
    }
}
```

### Update `MissionsViewModel.swift`

Replace the mock data loading with real API calls:

```swift
func loadMissions() {
    guard !isLoading else { return }
    isLoading = true

    Task {
        do {
            missions = try await MissionService.shared.listMissions()
        } catch {
            handleError(error)
        }
        isLoading = false
    }
}

func createMission(...) {
    isSubmitting = true

    Task {
        do {
            let request = CreateMissionRequest(...)
            let mission = try await MissionService.shared.createMission(request)
            missions.insert(mission, at: 0)
            showToastMessage("Mission created!")
        } catch {
            handleError(error)
        }
        isSubmitting = false
    }
}

func deleteMission(id: String) {
    Task {
        do {
            try await MissionService.shared.deleteMission(id: id)
            missions.removeAll { $0.id == id }
            showToastMessage("Mission deleted")
        } catch {
            handleError(error)
        }
    }
}
```

---

## Summary Checklist

### Must Have (Missions)
- [ ] `Mission` entity in Datastore
- [ ] `missions.py` blueprint with 5 endpoints
- [ ] `mission_service.py` with CRUD logic
- [ ] `validate_mission_data()` in validators
- [ ] Model functions: `create_mission`, `get_mission`, `list_missions_for_user`, `update_mission`, `delete_mission`
- [ ] Tests in `test_api_missions.py`
- [ ] Register blueprint in `main.py`

### Should Have (Other Features)
- [ ] `GET /api/users/me/pods` endpoint
- [ ] College year filter implementation on events
- [ ] Kick replacement logic (basic implementation)

### Nice to Have (Cron Jobs)
- [ ] Trust score penalty cron job
- [ ] Chat message cleanup cron job

---

## Existing Code Patterns to Follow

Look at these files for reference on the established patterns:

- **API Blueprint**: `OrbitServer/api/events.py`
- **Service Layer**: `OrbitServer/services/event_service.py`
- **Model Layer**: `OrbitServer/models/models.py`
- **Validators**: `OrbitServer/utils/validators.py`
- **Response Format**: Always use `success(data)` or `error(message, status_code)` from `utils/responses.py`
- **Auth**: Use `@require_auth` decorator, access user via `g.user_id`
- **Tests**: See `tests/test_api_events.py` for patterns

---

## Questions?

If anything is unclear about the iOS data models or expected behavior, check:
- `OrbitApp/Orbit/Models/Mission.swift` — iOS data structures
- `OrbitApp/Orbit/ViewModels/MissionsViewModel.swift` — Expected API behavior
- `OrbitApp/Orbit/Views/Missions/MissionsView.swift` — UI that consumes the data
