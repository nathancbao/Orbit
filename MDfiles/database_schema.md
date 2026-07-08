# Orbit Database Schema

> **Source of truth:** `OrbitServer/models/models.py`. Google Cloud Datastore is
> schemaless, so this document is derived from the explicit `entity.update({...})`
> field dictionaries in the model layer, **not** from the live database. When you
> add or change a field in `models.py`, update this file in the same change.

## Planned changes (not yet implemented)

Orbit is heading toward a larger restructure. This doc tracks the **current** schema;
the direction below is recorded so it isn't lost, but none of it is built yet:

- **`Signal` → `Mission` merge.** The two activity Kinds will collapse into a single
  `Mission` Kind that holds both *already-scheduled* activities (today's `Mission`) and
  *still-scheduling* spontaneous requests (today's `Signal`), distinguished by a type/mode
  field rather than two Kinds.
- `RefreshToken` and `VerificationCode` are auth-plumbing Kinds, not central to the
  domain model — they exist in the live DB but are peripheral to the restructure.

## Conventions

- **Datastore is NoSQL.** "Kind" ≈ table, "entity" ≈ row, "property" ≈ column. There
  is no enforced schema — these are the fields the app writes.
- **Key type** describes how an entity's key/ID is generated:
  - *Auto int ID* — Datastore assigns a numeric ID (`client.key('Kind')`).
  - *UUID string* — app generates `str(uuid.uuid4())` as the key name.
  - *Named key* — a meaningful string is used directly as the key name.
- `_entity_to_dict()` adds an `id` field to every API response as
  `str(entity.key.id_or_name)`.
- Datetimes are stored as naive UTC and serialized as ISO-8601 with a `Z` suffix.
- **Not indexed** fields are excluded from indexes (`exclude_from_indexes=[...]`) — they
  can't be filtered/ordered on, but they still store and return normally.
- **Int IDs render as strings in the Datastore console.** List-of-int fields
  (`Pod.member_ids`, `Signal.rsvps`) display quoted (e.g. `"5673082664517632"`) because
  the console serializes 64-bit ints as strings to avoid JS precision loss. The code
  stores and queries them as `int`. `Pod.signal_id` / `Signal.pod_ids` are genuinely
  UUID **strings**.

---

## User

Merged User + Profile. API returns it wrapped as `{profile: {...}, profile_complete: bool}`.

- **Kind:** `User`
- **Key:** Auto int ID
- **Created by:** `create_user()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `email` | string | — | `.edu` address, unique by convention |
| `name` | string | `''` | |
| `college_year` | string | `''` | one of `freshman, sophomore, junior, senior, grad` |
| `interests` | list[string] | `[]` | |
| `photo` | string \| null | `None` | profile photo URL |
| `gallery_photos` | list[string] | `[]` | |
| `bio` | string | `''` | |
| `links` | list[string] | `[]` | |
| `gender` | string | `''` | |
| `mbti` | string | `''` | |
| `college` | string | `''` | key into `utils/colleges.py` `COLLEGES`; `''` = not set |
| `max_distance_miles` | int | `0` | mission distance filter radius; `0` = no limit, max 50 |
| `trust_score` | float | `0.0` | clamped to `[0.0, 5.0]`; +0.5 confirm, −0.2 no-show |
| `created_at` | datetime | now | |
| `updated_at` | datetime | now | |

---

## Mission

Fixed-date activities, browseable in the discovery feed.

- **Kind:** `Mission`
- **Key:** Auto int ID
- **Created by:** `create_mission()`
- **Cascade:** deleting a Mission deletes all its Pods.

| Field | Type | Default | Notes |
|---|---|---|---|
| `title` | string | — | required |
| `description` | string | `''` | |
| `tags` | list[string] | `[]` | |
| `location` | string | `''` | |
| `college` | string | `''` | creator's college at creation time; `''` = visible everywhere |
| `date` | string | `''` | `YYYY-MM-DD` |
| `start_time` | string \| null | `None` | |
| `end_time` | string \| null | `None` | |
| `creator_id` | int | — | → `User` |
| `creator_type` | string | `'user'` | `user` \| `seeded` \| `ai_suggested` |
| `max_pod_size` | int | `4` | |
| `utc_offset` | int | `0` | |
| `status` | string | `'open'` | `open` \| `completed` \| `cancelled` |
| `embedding` | list[float] \| null | `None` | recommendation vector |
| `created_at` | datetime | now | |
| `updated_at` | datetime | now | |

---

## Pod

A small group attached to a Mission **or** a Signal. Signal-linked pods are created by
`create_signal_pod()` and carry `signal_id` instead of `mission_id`.

- **Kind:** `Pod`
- **Key:** UUID string
- **Created by:** `create_pod()` (mission), `create_signal_pod()` (signal)
- **Cascade:** deleting a Pod deletes its `ChatMessage` and `Vote` entities.

| Field | Type | Default | Notes |
|---|---|---|---|
| `mission_id` | int \| null | — | set for mission pods; `None` for signal pods |
| `signal_id` | string \| null | — | set only for signal pods → `Signal` |
| `member_ids` | list[int] | `[]` | → `User` |
| `max_size` | int | `4` / `6` | 4 for mission pods, 6 for signal pods |
| `name` | string \| null | `None` | |
| `status` | string | `'open'` | `open` \| `full` \| `meeting_confirmed` \| `completed` \| `cancelled` |
| `scheduled_time` | string \| null | `None` | |
| `scheduled_place` | string \| null | `None` | |
| `scheduled_end_time` | string \| null | — | set via `update_pod`; drives expiry |
| `confirmed_attendees` | list[int] | `[]` | |
| `kick_votes` | dict | `{}` | `{target_user_id: [voter_user_ids]}` |
| `schedule_data` | dict | `{'entries': {}}` | per-member availability: `{"entries": {"<user_id>": {"slots": [{"date": "YYYY-MM-DD", "hour": "H"}]}}}` |
| `survey_completed_by` | list[int] | — | set via `update_pod` |
| `completed_at` | datetime \| string | — | set via `update_pod` |
| `created_at` | datetime | now | |
| `expires_at` | datetime | now + 14 days | |

> Pods auto-expire 24 hours after `scheduled_end_time` (deleted lazily on read in
> `get_user_pods`, matching the mission grace period). A daily cron sweep
> (`cron.yaml` → `GET /api/tasks/cleanup`) also removes expired missions,
> signals, and pods that nobody reads.

---

## ChatMessage

Pod messages **and** direct messages. DMs reuse this Kind with
`pod_id = "dm_<a>_<b>"` (sorted user IDs, see `dm_conversation_id()`).

- **Kind:** `ChatMessage`
- **Key:** UUID string
- **Created by:** `create_chat_message()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `pod_id` | string | — | pod UUID, or `dm_<a>_<b>` for DMs |
| `user_id` | int | — | → `User` (sender) |
| `content` | string | — | **not indexed** |
| `message_type` | string | `'text'` | |
| `created_at` | datetime | now | |

---

## Vote

Time/place poll within a Pod.

- **Kind:** `Vote`
- **Key:** UUID string
- **Created by:** `create_vote()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `pod_id` | string | — | → `Pod` |
| `created_by` | int | — | → `User` |
| `vote_type` | string | — | `time` \| `place` |
| `options` | list[string] | — | choices |
| `votes` | dict | `{}` | `{user_id_str: option_index}` |
| `status` | string | `'open'` | `open` \| `closed` |
| `result` | string \| null | `None` | winning option |
| `expected_voters` | list \| null | `None` | |
| `created_at` | datetime | now | |
| `closed_at` | datetime \| null | `None` | |

---

## UserHistory

Interaction tracking for the ML recommendation engine.

- **Kind:** `UserHistory`
- **Key:** UUID string
- **Created by:** `record_action()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `user_id` | int | — | → `User` |
| `mission_id` | int | — | → `Mission` |
| `pod_id` | string \| null | `None` | → `Pod` |
| `action` | string | — | e.g. `joined`, `browsed`, `skipped` |
| `attended` | bool \| null | `None` | |
| `points_earned` | int | `0` | |
| `tags_snapshot` | list[string] | `[]` | mission tags at interaction time (decay scoring) |
| `enjoyment_rating` | int | — | set via `update_history` |
| `created_at` | datetime | now | |

---

## Signal

Spontaneous "anyone down?" activity requests → RSVP → auto-pod formation.

- **Kind:** `Signal`
- **Key:** UUID string
- **Created by:** `create_signal()`
- **Cascade:** deleting a Signal deletes all Pods with that `signal_id`.

| Field | Type | Default | Notes |
|---|---|---|---|
| `creator_id` | int | — | → `User` |
| `college` | string | `''` | creator's college at creation time; `''` = visible everywhere |
| `title` | string | `''` | |
| `description` | string | `''` | |
| `activity_category` | string | `'Custom'` | matches Swift `ActivityCategory` raw values |
| `custom_activity_name` | string \| null | `None` | |
| `min_group_size` | int | `3` | |
| `max_group_size` | int | `6` | RSVPs capped at `2 × max_group_size` (2 pods) |
| `availability` | list[dict] | `[]` | `{"date": ISO8601, "time_blocks": [...]}` — **not indexed** |
| `tags` | list[string] | `[]` | |
| `links` | list[string] | `[]` | max 2 — **not indexed** |
| `time_range_start` | int | `9` | hour |
| `time_range_end` | int | `21` | hour |
| `rsvps` | list[int] | `[]` | → `User` |
| `pod_ids` | list[string] | — | assigned on RSVP, max 2 (legacy single `pod_id` migrated) |
| `status` | string | `'pending'` | `pending` \| `active` (flips at `min_group_size`) |
| `created_at` | datetime | now | |
| `updated_at` | datetime | — | set via `update_signal` |

> Signals auto-expire 24 hours after their latest `availability` date ends
> (fallback: `created_at` + 14 days when no date parses). Deleted lazily on
> read in `signal_service.check_signal_expiration` and by the daily cron sweep.

---

## RefreshToken

- **Kind:** `RefreshToken`
- **Key:** Named key = the SHA-256-hashed token string
- **Created by:** `store_refresh_token()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `user_id` | int | — | → `User` |
| `created_at` | datetime | now | 7-day refresh lifetime |

---

## VerificationCode

- **Kind:** `VerificationCode`
- **Key:** Named key = email address
- **Created by:** `store_verification_code()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `email` | string | — | also the key |
| `code` | string | — | demo bypass code: `123456` |
| `failed_attempts` | int | `0` | |
| `created_at` | datetime | now | |
| `expires_at` | datetime | now + 10 min | |

---

## FriendRequest

- **Kind:** `FriendRequest`
- **Key:** Auto int ID
- **Created by:** `create_friend_request()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `from_user_id` | int | — | → `User` |
| `to_user_id` | int | — | → `User` |
| `status` | string | `'pending'` | `pending` \| `accepted` \| `declined` |
| `created_at` | datetime | now | |

---

## Friendship

Directional — a mutual friendship is two `Friendship` entities.

- **Kind:** `Friendship`
- **Key:** Auto int ID
- **Created by:** `create_friendship()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `user_id` | int | — | → `User` (owner) |
| `friend_id` | int | — | → `User` |
| `created_at` | datetime | now | |

---

## SurveyResponse

Post-pod feedback survey.

- **Kind:** `SurveyResponse`
- **Key:** UUID string
- **Created by:** `create_survey_response()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `user_id` | int | — | → `User` |
| `pod_id` | string | — | → `Pod` |
| `mission_id` | int \| null | — | → `Mission` |
| `enjoyment_rating` | int | — | |
| `added_interests` | list[string] | `[]` | |
| `member_votes` | dict | `{}` | per-member ratings |
| `created_at` | datetime | now | |

---

## PodInvite

- **Kind:** `PodInvite`
- **Key:** Auto int ID
- **Created by:** `create_pod_invite()`

| Field | Type | Default | Notes |
|---|---|---|---|
| `pod_id` | string | — | → `Pod` |
| `from_user_id` | int | — | → `User` |
| `to_user_id` | int | — | → `User` |
| `status` | string | `'pending'` | `pending` \| `accepted` \| `declined` |
| `created_at` | datetime | now | |

---

## Relationships

```
User 1───* Mission        (creator_id)
User 1───* Signal         (creator_id)
User *───* Pod            (member_ids[])
Mission 1───* Pod         (Pod.mission_id)      ← cascade delete
Signal  1───* Pod         (Pod.signal_id)       ← cascade delete
Pod 1───* ChatMessage     (pod_id)              ← cascade delete
Pod 1───* Vote            (pod_id)              ← cascade delete
Pod 1───* PodInvite       (pod_id)
User 1───* UserHistory    (user_id → mission_id)
User 1───* SurveyResponse (user_id, pod_id, mission_id)
User *───* User           (FriendRequest, Friendship — directional)
ChatMessage               also stores DMs via pod_id = "dm_<a>_<b>"
```

---

## Composite Indexes (`index.yaml`)

Single-property and key queries are auto-indexed by Datastore. These composite indexes
back multi-property filters/orders:

| Kind | Properties | Backs |
|---|---|---|
| `UserHistory` | `user_id` + `created_at DESC` | `get_user_history` (recommendation engine) |
| `UserHistory` | `user_id` + `mission_id` | `get_history_entry` |
| `ChatMessage` | `pod_id` + `created_at` | `list_chat_messages` |
| `Signal` | `creator_id` + `created_at DESC` | `list_signals_for_user` |
| `Mission` | `creator_id` + `created_at DESC` | user's own missions |
| `Mission` | `tags` + `status` | `list_missions` filtered feed |
| `FriendRequest` | `to_user_id` + `status` | `list_incoming_friend_requests` |
| `FriendRequest` | `from_user_id` + `status` | `list_outgoing_friend_requests` |
| `FriendRequest` | `from_user_id` + `to_user_id` + `status` | `find_pending_request` |
