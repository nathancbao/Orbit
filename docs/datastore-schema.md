# Orbit Datastore Schema — 2026-07-06

> **Source of truth:** `OrbitServer/models/models.py`. Google Cloud Datastore is
> schemaless, so this document is derived from the explicit `entity.update({...})`
> field dictionaries in the model layer — **not** from the live database. When a
> field changes in `models.py`, update this file in the same change.
>
> **Note on the brief:** the overhaul prompt says "Firestore." Orbit runs on
> **Datastore mode** (`google.cloud.datastore`). There is no `firestore.rules`
> file and none applies — all access is server-side via the App Engine service
> account. This supersedes the partial `MDfiles/database_schema.md`, which
> predates the Signal→Mission merge.

## Conventions

- **Kind** ≈ table, **entity** ≈ row, **property** ≈ column. No enforced schema.
- **Key type:** *Auto int ID* (`client.key('Kind')`), *UUID string*
  (`str(uuid.uuid4())` as key name), or *Named key* (a meaningful string).
- `_entity_to_dict()` adds `id` = `str(entity.key.id_or_name)` to every response.
- Datetimes stored as **naive UTC**, serialized ISO-8601 with a `Z` suffix.
- **Not indexed** = excluded via `exclude_from_indexes=[...]`; stored/returned
  normally but can't be filtered or ordered on.
- List-of-int fields (`Pod.member_ids`, `Signal.rsvps`) are stored/queried as
  `int`; the Datastore console renders them quoted (64-bit JS precision).

---

## User

Merged User + Profile. API returns it wrapped as
`{profile: {...}, profile_complete: bool}`. Created by `create_user()`.

- **Kind:** `User` · **Key:** Auto int ID

| Field | Type | Required | Notes |
|---|---|---|---|
| email | string | yes | `.edu`, unique by convention (not enforced); login identity |
| name | string | no | `''` until onboarding |
| college_year | string | no | one of `freshman/sophomore/junior/senior/grad` |
| interests | list<string> | no | 3–10 once profile complete |
| photo | string / null | no | GCS URL |
| gallery_photos | list<string> | no | ≤6 GCS URLs |
| bio | string | no | ≤250 chars |
| links | list<string> | no | ≤3 URLs |
| gender | string | no | `male/female/non-binary/other/''` |
| mbti | string | no | one of 16 types or `''` |
| trust_score | float | yes | clamped [0.0, 5.0]; adjusted transactionally |
| created_at / updated_at | datetime | yes | |

**PII:** `email` (private — see AUDIT H1), `name`, `photo`, `bio`. Profile
completeness = name + valid college_year + ≥3 interests.

---

## Mission

Unified activity kind (replaces the old Event + Signal split). Two modes:
`set` (fixed date/time) and `flex` (group schedules later). Created by
`create_mission()`.

- **Kind:** `Mission` · **Key:** Auto int ID
- **Not indexed:** `embedding`, `availability`, `images`, `description`

| Field | Type | Required | Notes |
|---|---|---|---|
| title | string | yes | ≤200 chars |
| description | string | no | ≤2000 chars |
| tags | list<string> | no | ≤10; profanity-filtered |
| location | string | no | |
| mode | string | yes | `set` or `flex` |
| logo | string / null | no | |
| images | list<string> | no | ≤3 GCS URLs |
| date | string | set-mode yes | `YYYY-MM-DD`, within today+14d |
| start_time / end_time | string / null | start req. for set | `HH:mm` |
| min_pod_size / max_pod_size | int | no | 3–10, default 3/4 |
| creator_id | int | yes | → User |
| creator_type | string | yes | `user` (org type reserved) |
| status | string | yes | `open` / `completed` / `cancelled` |
| utc_offset | int | no | seconds east of UTC for expiry math |
| links | list<string> | no | ≤3 |
| embedding | list<float> / null | no | fastembed vector; stripped from responses |
| created_at / updated_at | datetime | yes | |
| **flex only:** custom_activity_name | string / null | no | |
| availability | list<slot> | flex yes | `[{date, hours[]|time_blocks[]}]` |
| time_range_start / time_range_end | int / null | no | hour 0–23 |
| scheduling_window_days | int | no | 1–14, default 7 |
| scheduleable_from / scheduleable_until | string | no | `YYYY-MM-DD` window |

Expiration handled in `mission_service.check_mission_expiration()`: past end
→ `completed`; past end + 2h → deleted (cascades to pods).

---

## Pod

A formed group for a mission or signal. Created by `create_pod()` /
`create_signal_pod()`.

- **Kind:** `Pod` · **Key:** UUID string

| Field | Type | Required | Notes |
|---|---|---|---|
| mission_id | int / null | one of mission/signal | → Mission |
| signal_id | string / null | one of mission/signal | → Signal (flex pods) |
| member_ids | list<int> | yes | **member_ids[0] = leader** (join order) |
| max_size | int | yes | |
| name | string / null | no | leader-editable |
| status | string | yes | `open`/`full`/`meeting_confirmed`/`completed`/`cancelled` |
| scheduled_time | string / null | no | display string |
| scheduled_place | string / null | no | |
| scheduled_end_time | string / null | no | ISO UTC; drives expiry |
| confirmed_attendees | list<int> | yes | ≥50% → status `completed` |
| kick_votes | map<str,list<int>> | yes | `{target_id: [voter_ids]}` |
| schedule_data | map | yes | `{entries: {...}}` flex availability grid |
| survey_completed_by | list<int> | no | who submitted the post-activity survey |
| completed_at | datetime / null | no | starts 7-day survey window |
| created_at | datetime | yes | |
| expires_at | datetime | yes | default created + 14d |

---

## ChatMessage

Pod chat **and** DMs (DMs use `pod_id = "dm_<a>_<b>"`, a and b sorted).
Created by `create_chat_message()`.

- **Kind:** `ChatMessage` · **Key:** UUID string
- **Not indexed:** `content`, `reactions`

| Field | Type | Required | Notes |
|---|---|---|---|
| pod_id | string | yes | pod UUID **or** `dm_<a>_<b>` |
| user_id | int | yes | sender |
| content | string | yes | ≤1000 (pod) / ≤2000 (DM) |
| message_type | string | yes | `text`/`system`/`vote_created`/`vote_result` |
| reactions | map | yes | `{thumbs_up|thumbs_down|heart: [user_ids]}` |
| pinned | bool | yes | leader-only pin |
| created_at | datetime | yes | supports `since` incremental fetch |

---

## Vote

Time/place poll inside a pod. Created by `create_vote()`.

- **Kind:** `Vote` · **Key:** UUID string

| Field | Type | Required | Notes |
|---|---|---|---|
| pod_id | string | yes | → Pod |
| created_by | int | yes | |
| vote_type | string | yes | `time` or `place` |
| options | list<string> | yes | 2–4 |
| votes | map<str,int> | yes | `{user_id: option_index}` |
| status | string | yes | `open`/`closed` |
| result | string / null | no | winning option on close |
| expected_voters | int / null | no | snapshot of member count at creation |
| created_at / closed_at | datetime | yes/null | auto-close when all voted |

---

## UserHistory

Behavioral log for the ML recommender. Created by `record_action()`.

- **Kind:** `UserHistory` · **Key:** UUID string

| Field | Type | Required | Notes |
|---|---|---|---|
| user_id | int | yes | |
| mission_id | int | yes | |
| pod_id | string / null | no | |
| action | string | yes | `joined`/`skipped`/`browsed` |
| attended | bool / null | no | |
| points_earned | int | yes | |
| enjoyment_rating | int | no | backfilled from survey |
| tags_snapshot | list<string> | yes | mission tags at interaction time (decay scoring) |
| created_at | datetime | yes | |

This is the **primary analytics substrate today** — see
`docs/analytics-and-metrics.md`.

---

## Signal

Spontaneous "who's down" activity request (flex missions link to these). Created
by `create_signal()`.

- **Kind:** `Signal` · **Key:** UUID string
- **Not indexed:** `availability`, `links`

| Field | Type | Required | Notes |
|---|---|---|---|
| creator_id | int | yes | |
| title / description | string | no | |
| activity_category | string | yes | `Sports/Food/Movies/Hangout/Study/Custom` |
| custom_activity_name | string / null | no | |
| min_group_size / max_group_size | int | yes | 3+ / ≤10 |
| availability | list<slot> | yes | `[{date, time_blocks[]}]` |
| tags | list<string> | no | ≤6 |
| links | list<string> | no | ≤2 |
| time_range_start / time_range_end | int | no | default 9 / 21 |
| rsvps | list<int> | yes | capped at 2×max_group_size |
| pod_ids | list<string> | no | ≤2 pods, assigned on RSVP |
| status | string | yes | `pending` → `active` at min_group_size |
| created_at | datetime | yes | |

---

## Auth & social plumbing kinds

| Kind | Key | Key fields | Purpose |
|---|---|---|---|
| **RefreshToken** | Named (SHA-256 hash) | user_id, created_at | Hashed refresh-token store; deleted on logout |
| **VerificationCode** | Named (email) | code, failed_attempts, expires_at (10min) | Email login codes; 3-strike lockout |
| **FriendRequest** | Auto int | from_user_id, to_user_id, status (`pending/accepted/declined`) | Directional friend request |
| **Friendship** | Auto int | user_id, friend_id | **Two entities per friendship** (one each direction) |
| **SurveyResponse** | UUID | user_id, pod_id, mission_id, enjoyment_rating, added_interests, member_votes | Post-activity survey; one per user per pod |
| **Notification** | UUID | user_id, type, title, body, data, read | In-app inbox (not APNS push) |
| **PodInvite** | Auto int | pod_id, from_user_id, to_user_id, status | Direct pod invitation |

---

## Composite indexes (`index.yaml`)

| Kind | Properties | Serves |
|---|---|---|
| UserHistory | user_id + created_at↓ | recent history for recs |
| UserHistory | user_id + mission_id | dedupe / history lookup |
| ChatMessage | pod_id + created_at | ordered chat, `since` fetch |
| Notification | user_id + created_at↓ | inbox newest-first |
| Notification | user_id + read | mark-all-read query |
| Signal | creator_id + created_at↓ | my signals |
| Mission | creator_id + created_at↓ | my missions |
| Mission | tags + status | tag-filtered discovery |
| FriendRequest | to_user_id + status | incoming requests |
| FriendRequest | from_user_id + status | outgoing requests |
| FriendRequest | from_user_id + to_user_id + status | dedupe pending request |

**Gap flagged in AUDIT (M2):** `search_users` and `list_dm_conversations` do
**full-kind scans** with no supporting index (Datastore has no prefix/LIKE
queries) — they read up to 2000 Users / 5000 ChatMessages in Python. A
`Conversation` kind or denormalized search token would remove these scans.
