# Notification System

## Overview

The notification system provides in-app notifications and Apple Push Notifications (APNs) for Orbit. Users are notified when someone joins or leaves their pod, when they receive a chat message, and when events are recommended for them. Notifications appear in an inbox sheet accessed via the bell icon on every tab.

## Architecture

```
Trigger (pod join, chat, etc.)
  → notification_service.py (background thread)
    → models.py: save Notification entity to Datastore
    → APNs: send push to user's registered devices (if configured)

iOS app
  → NotificationService.swift → API endpoints → models.py (read/mark)
  → NotificationViewModel.swift → InboxView.swift (UI)
  → AppDelegate → APNs token registration
```

All notification work runs on **background daemon threads** via `_fire_and_forget()`. This means notify calls never block or break the HTTP request that triggered them. If anything fails, it's logged and silently dropped.

## Backend

### Datastore Entities

**Notification** (kind: `Notification`)
| Field | Type | Description |
|-------|------|-------------|
| user_id | int | Recipient |
| type | str | `pod_join`, `pod_leave`, `chat_message`, `recommended_event` |
| title | str | Display title |
| body | str | Display body (excluded from indexes) |
| data | dict | Context payload: pod_id, event_id, etc. (excluded from indexes) |
| read | bool | Read state, default False |
| created_at | datetime | Creation timestamp |

**DeviceToken** (kind: `DeviceToken`)
| Field | Type | Description |
|-------|------|-------------|
| user_id | int | Owner |
| token | str | APNs device token (hex string) |
| updated_at | datetime | Last registration time |

### Model Functions (`OrbitServer/models/models.py`)

- `create_notification(user_id, type, title, body, data)` — write a notification to Datastore
- `list_notifications(user_id, limit=50)` — fetch notifications, newest first
- `count_unread_notifications(user_id)` — count where read=False (keys-only query)
- `mark_notifications_read(user_id, notification_ids)` — set read=True for specific IDs
- `mark_all_notifications_read(user_id)` — set read=True for all unread
- `save_device_token(user_id, token)` — upsert a device token
- `get_device_tokens(user_id)` — list all token strings for a user
- `delete_device_token(token)` — remove a token

### Notification Service (`OrbitServer/services/notification_service.py`)

Every public function spawns a background thread that:
1. Looks up context (pod members, user display name)
2. Creates a `Notification` entity in Datastore for each recipient
3. Sends an APNs push to each recipient's registered devices

| Function | Trigger | Recipients |
|----------|---------|------------|
| `notify_pod_join(pod_id, joiner_user_id)` | User joins a pod | Other pod members |
| `notify_pod_leave(pod_id, leaver_user_id, remaining_member_ids)` | User leaves a pod | Remaining members (passed explicitly since leaver is already removed) |
| `notify_chat_message(pod_id, sender_user_id, preview)` | Chat message sent | Pod members except sender |
| `notify_recommended_events(user_id, events)` | AI recommendations | Single user |

### API Endpoints (`OrbitServer/api/notifications.py`)

All endpoints require JWT auth (`@require_auth`).

| Method | Path | Body | Description |
|--------|------|------|-------------|
| GET | `/api/notifications` | — | List notifications + unread count. Optional `?limit=N` (max 200) |
| POST | `/api/notifications/read` | `{notification_ids: [str]}` | Mark specific notifications as read |
| POST | `/api/notifications/read-all` | — | Mark all notifications as read |
| GET | `/api/notifications/unread-count` | — | Badge count only |
| POST | `/api/devices` | `{token: str}` | Register APNs device token |
| DELETE | `/api/devices` | `{token: str}` | Unregister device token |

### Where Notifications Are Triggered

**`OrbitServer/services/pod_service.py`:**
- `join_event()` line 113 → `notify_pod_join(pod['id'], user_id)`
- `leave_event()` line 142 → `notify_pod_leave(pod['id'], user_id, remaining_members)`
- `leave_pod()` line 180 → `notify_pod_leave(pod_id, user_id, remaining_members)`

**`OrbitServer/services/chat_service.py`:**
- `send_message()` line 34 → `notify_chat_message(pod_id, user_id, content[:100])`

All calls are wrapped in try/except inside background threads — they cannot crash the parent request.

## APNs Configuration

Push notifications require these environment variables (set in `.env`):

| Variable | Description |
|----------|-------------|
| `APNS_KEY_PATH` | Path to `.p8` key file |
| `APNS_KEY_ID` | 10-char key ID (from filename) |
| `APNS_TEAM_ID` | Apple Developer Team ID |
| `APNS_BUNDLE_ID` | App bundle ID (`adrian.Orbit`) |
| `APNS_USE_SANDBOX` | `true` for dev, `false` for production |

If any of the first three are missing, push is silently skipped — notifications are still saved to Datastore and visible in the inbox.

The APNs client is **lazy-loaded** on first push and reused for all subsequent pushes (thread-safe via lock).

## iOS

### Files

| File | Purpose |
|------|---------|
| `Models/AppNotification.swift` | `AppNotification` struct (Codable, Identifiable) with icon and timeAgo computed properties |
| `Services/NotificationService.swift` | API calls: list, mark read, mark all read, unread count, register/unregister device token |
| `ViewModels/NotificationViewModel.swift` | `@MainActor ObservableObject` — holds notifications list, unread count, loading state |
| `Views/Notifications/InboxView.swift` | Inbox sheet UI: notification list, empty state, mark all read, pull to refresh |
| `OrbitApp.swift` | `AppDelegate` for APNs permission + device token registration |

### How It Works

1. **App launch** → `AppDelegate` requests push permission and registers for remote notifications
2. **Token received** → `didRegisterForRemoteNotificationsWithDeviceToken` sends hex token to `POST /api/devices`
3. **Bell icon tap** (any tab) → opens `InboxView` sheet via `NotificationViewModel` (shared as `@EnvironmentObject`)
4. **Inbox loads** → `GET /api/notifications` fetches list + unread count
5. **Tap notification** → marks it read via `POST /api/notifications/read`
6. **Mark all read** → `POST /api/notifications/read-all`
7. **Badge count** refreshes on app appear and after any read/mark-all action

### Bell Icon Badge

All three tab views (MissionsView, SignalsView, PodsView) show a red badge on the bell icon with `notificationVM.unreadCount`. The badge caps at 99.

## Dependencies

- `PyAPNS2==0.7.2` — Python APNs client (added to `requirements.txt`)

## Testing

16 tests in `tests/test_api_notifications.py` covering all API endpoints:
- Auth rejection for unauthenticated requests
- Notification listing (populated and empty)
- Mark read (specific IDs and all)
- Unread count
- Device token register/unregister
- Input validation (missing/empty fields)

Run: `python3 -m pytest tests/test_api_notifications.py -v`
