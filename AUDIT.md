# Orbit Production-Readiness Audit — 2026-07-06

> **Scope:** Full-stack audit of the Orbit monorepo — Python/Flask backend
> (repo root + `OrbitServer/`) on Google App Engine with **Google Cloud
> Datastore**, and the SwiftUI iOS client (`OrbitApp/`). Findings are grouped by
> concern and tagged **Critical / High / Medium / Low**. This is a read-only
> report; no code was changed. The fix phases proposed at the end wait for
> approval before any code is touched.

> **Correction to the overhaul brief:** the brief repeatedly says "Firestore" and
> "Firestore Security Rules." The backend actually uses **Datastore mode**
> (`google-cloud-datastore`), accessed exclusively server-side through a service
> account. There are **no client-facing security rules** to audit — data
> isolation is enforced entirely in the Flask layer, which makes the per-resource
> authorization findings below the real equivalent of a rules audit.

---

## Architecture map

### Request flow

```
iOS app (SwiftUI, MVVM)
  └─ APIService.shared  (URLSession, async/await, Bearer token from Keychain)
       │  HTTPS  https://orbit-app-486204.wl.r.appspot.com/api
       ▼
Google App Engine (F2, gunicorn -w2 --threads4, autoscale 0–3)
  └─ main.py  Flask app  →  @require_auth (JWT HS256)  →  blueprint
       ├─ /api/auth          auth.py        (send-code, verify-code, refresh, logout)
       ├─ /api/users         users.py       (profile CRUD, photo/gallery, my pods/rsvps)
       ├─ /api/missions      missions.py    (list, suggested, CRUD, join/leave/skip)
       ├─ /api/pods          pods.py        (detail, edit, kick, confirm, schedule, survey, invites)
       ├─ /api/pods          chat.py        (messages, reactions, pins, votes) — shares prefix
       ├─ /api/signals       signals.py     (list, discover, CRUD, rsvp)
       ├─ /api/friends       friends.py     (search, requests, accept/decline, remove, status)
       ├─ /api/dm            dm.py          (conversations, messages)
       ├─ /api/notifications notifications.py (inbox, read, suggested)
       └─ /api/voyage        voyage.py      (tile clusters, heartbeat)
            │
            ▼
       services/*  (business logic + authz)  →  models/models.py  →  Datastore
                                                         │
                                    utils/cache.py (in-proc TTL cache: user/mission/pod)
       External: SendGrid (email codes) · GCS (photos) · fastembed + LightFM (recs)
```

### Data flow (write path example — join a mission)

```
POST /api/missions/<id>/join
  → @require_auth sets g.user_id
  → pod_service.join_mission()
       get_mission()  → check status 'open'
       get_user_pod_for_mission()  → dedupe
       at_pod_limit()  → cap 15 pods/user
       _find_best_pod_for_user()  → Jaccard interest match (N+1 get_user per member)
       transactional_pod_update()  → atomic member append  ← race-safe
       record_action('joined')  → UserHistory (ML signal)
  → 201 pod dict
```

Key data relationships: `User 1─* Mission` (creator) · `Mission 1─* Pod` ·
`Pod *─* User` (via `member_ids`) · `Pod 1─* ChatMessage / Vote` · `Signal`
(flex activity) `1─* Pod` · `User *─* User` (via directional `Friendship` +
`FriendRequest`). Full field-level schema is in `docs/datastore-schema.md`.

---

## Critical

### C1 — `JWT_SECRET` falls back to a known constant
**`OrbitServer/utils/auth.py:13`** — `os.environ.get('JWT_SECRET', 'dev-secret-change-me')`.
If the env var is ever unset (misconfig, a new environment, a test container
promoted to prod), the app silently signs tokens with a publicly-known secret,
and anyone can forge tokens for any user.
**Fix:** fail fast in production — raise at import if `JWT_SECRET` is missing (or
matches the known dev value) when running on App Engine (`GAE_ENV` set), while
keeping the convenient fallback for pure local dev. Tests already inject a secret
via `conftest.py`, so this won't break CI.

---

## Retained by owner decision (not being changed)

### D1 — Demo verification bypass `"123456"` accepts any `.edu` email
**`OrbitServer/services/auth_service.py:104-118`.** `verify_code()` returns valid
tokens for code `"123456"` for **any** email, before any real code check. This is
an intentional demo/testing convenience and **the owner has chosen to keep it for
now.** It means authentication is effectively open to anyone who knows a valid
`.edu` address.
**Status:** left in place per your instruction. **This MUST be removed before any
production launch** — it is the single biggest blocker to going live. Flagged here
so it stays visible on the checklist; a matching test currently asserts the bypass
works, and that test should flip the day it's removed.

---

## High

### H1 — Public profile endpoint leaks PII (email) and enables enumeration
**`OrbitServer/api/users.py:115-120`** — `GET /api/users/<user_id>` has **no
`@require_auth`**, and the returned profile includes `email`
(`user_service.PROFILE_FIELDS` includes `'email'`). Anyone can walk sequential
integer IDs and harvest names + `.edu` emails. The public friend deep-link page
(`main.py:179`) similarly renders name/photo for any ID.
**Fix:** require auth on `/users/<id>`; strip `email` (and any private fields)
from the public/other-user profile shape — return email only on `/users/me`.

### H2 — No rate limiting on `verify-code` and `refresh`; limiter is in-memory
**`OrbitServer/api/auth.py:35-63`, `OrbitServer/utils/rate_limit.py:4-8`.**
`send-code` is limited to 5/min but `verify-code` and `refresh` are unlimited.
Worse, the limiter uses `storage_uri="memory://"`, so limits are **per-instance**
and reset on every cold start — with autoscaling 0–3 instances the 5/min cap is
really up to 15/min and evaporates on scale events.
**Fix:** add limits to `verify-code` (e.g. 10/min/IP) and `refresh`; move limiter
storage to a shared backend (Datastore/Redis) or accept per-instance semantics
and document the tradeoff.

### H3 — Refresh tokens are never rotated
**`OrbitServer/services/auth_service.py:163-183`.** `refresh_access_token` mints a
new access token but returns the **same** refresh token, valid for its full 7-day
life. A leaked refresh token stays usable until expiry with no way to detect
reuse.
**Fix:** rotate on use — issue a new refresh token, store its hash, delete the old
one, and return it. Optionally detect reuse of a deleted refresh token as a theft
signal.

### H4 — Raw exception strings returned to clients
**`OrbitServer/api/auth.py:30`** (`f"Failed to send verification code: {str(e)}"`),
**`OrbitServer/services/mission_service.py:157`** → surfaced as 500 body, and
several `return error(str(e), 500)` paths. Internal error text (SendGrid errors,
Datastore errors) reaches the client.
**Fix:** log the exception server-side; return a generic message
(`"Something went wrong"`) with a stable error code. Add a Flask
`@app.errorhandler(Exception)` that returns a consistent JSON 500 and never a
stack trace.

### H5 — iOS accessibility is effectively absent
Across ~20 view files: **1** `accessibilityLabel` total, **zero** Dynamic Type
support, **86** hardcoded `.system(size:)` font calls, and the app is locked to
`.light` (`OrbitApp.swift:18`) with fixed-RGB galaxy colors in
`OrbitTheme.swift`. This fails Apple HIG accessibility / WCAG POUR (perceivable,
operable) on VoiceOver, text scaling, and likely contrast on the dark galaxy
cards.
**Fix (batch F):** adopt scaled text styles (`.font(.body)` / `ScaledMetric`),
add VoiceOver labels/traits to interactive controls, audit contrast on
`cardGradient*`, and honor reduced-motion. Large but incremental.

---

## Medium

### M1 — N+1 Datastore reads in list endpoints
Per-item `get_user`/`get_mission`/`get_signal` inside loops:
`friend_service.get_friends:31-33`, `get_incoming_requests:68-69`,
`get_outgoing_requests:77-78`; `pod_service._find_best_pod_for_user:61-66` and
`get_pod_with_members:471-479`; `pod_invite_service` (per-invite user+pod+mission);
`models.get_user_pods:844-864` (per-pod signal/mission lookup).
**Fix:** batch with `get_multi` (a `get_missions_batch` helper already exists in
`models.py:259` — generalize it to users/pods) and reuse the TTL cache.

### M2 — Full-scan-and-filter queries won't scale
**`models.search_users:122-141`** scans up to 2000 `User` entities and filters in
Python; **`models.list_dm_conversations:1102-1128`** scans up to 5000
`ChatMessage`. Both are O(table) reads on every call (search, DM inbox open).
**Fix:** for search, denormalize a lowercased name/email token field and query
it, or add a search index; for DMs, maintain a `Conversation` entity per pair (or
a per-user conversation index) updated on send, so the inbox is a bounded query.

### M3 — `get_pod_conversations` loads every message of every pod
**`OrbitServer/services/chat_service.py:315-331`** fetches up to 200 messages per
pod just to get the last one, for every pod the user is in.
**Fix:** store `last_message` / `last_message_at` denormalized on the `Pod` (or a
keys-only descending-1 query) instead of pulling full history.

### M4 — Fire-and-forget threads for embeddings may silently drop work
**`OrbitServer/api/missions.py:156-161`**, **`mission_service.edit_mission:206-211`**
spawn daemon threads to generate embeddings. On App Engine an instance can be
frozen/reclaimed after the response, killing the thread — embeddings then never
generate and the failure is swallowed (`except Exception: pass`).
**Fix:** move embedding generation to a proper task queue (Cloud Tasks) or
generate lazily on first read with a cached result; at minimum log failures.

### M5 — iOS polling (mostly a false alarm — corrected 2026-07-06)
On closer inspection the flagged sub-second timers are **not** backend polling:
`ScheduleViewModel`'s 1s loops update a visible **countdown** display,
`EventDiscoverViewModel`'s 2.5s is a **toast auto-dismiss**, `PodViewModel`'s
1.5s is a **retry-once-after-join** backoff, and `FriendsViewModel`'s 400ms is a
**search debounce**. The only genuine backend poll loops are `DMChatViewModel`
(5s, already incremental via the `since` cursor from commit `f334316`),
`VoyageViewModel` (10s presence heartbeat), and `DiscoveryViewModel` (30s) — all
reasonable cadences.
**Resolution:** no change needed; the original finding conflated UI timers with
polling. Left here for the record.

### M6 — Errors swallowed into `print()` on iOS; no user-facing error state
Multiple ViewModels (`FriendsViewModel:48-51`, `DMChatViewModel:28,45`,
`VoyageViewModel:132`) catch and `print()` instead of setting `errorMessage`.
Users see spinners that silently resolve to empty. No `ContentUnavailableView`;
empty states are hand-rolled and inconsistent; no offline handling.
**Fix (batch F):** surface failures to `errorMessage`, standardize empty/error
states.

### M7 — No security headers, no CORS policy
No `after_request` sets HSTS, `X-Content-Type-Options`, etc.; no CORS config.
Native-app traffic makes CORS lower-priority, but the friend deep-link HTML and
AASA endpoint are browser-facing.
**Fix:** add a small `after_request` hook for baseline security headers.

### M8 — Discovery/mission list has no pagination
**`models.list_missions:273-280`** caps at 100 with no cursor; `GET /api/missions`
returns all open + completed missions every call and scores them in Python.
**Fix:** paginate (the `Signal.discover` endpoint already demonstrates
cursor-based pagination in `models.list_all_signals:660`) and cap completed
missions.

---

## Low

- **L1 — `datetime.utcnow()` deprecation** throughout `models.py`,
  `auth_service.py`, `pod_service.py` (369 warnings in the test run). Breaks on
  future Python. Migrate to timezone-aware `datetime.now(datetime.UTC)`.
- **L2 — `_find_replacement` builds a fresh `datastore.Client()`**
  (`pod_service.py:601`) instead of reusing the module client. Minor waste.
- **L3 — `voyage.get_clusters` comment claims 60s caching that doesn't exist**
  (`voyage.py:67`); it fetches 100 missions + 200 signals uncached per call.
- **L4 — Profanity list is a single custom word** (`utils/profanity.py:8`) on top
  of the library defaults; easily bypassed. Low priority for a college app.
- **L5 — `userId` in `UserDefaults`** on iOS (`AuthService.swift:43`). Not
  sensitive (tokens are correctly in Keychain), but note it's not a security
  boundary.
- **L6 — Secrets live in a local plaintext `app.yaml` (not leaked, prod-prep).**
  `app.yaml` is correctly **gitignored and never committed** (verified across all
  git history — the real `JWT_SECRET`/`SendGrid`/APNS values appear in zero
  commits; only `app.yaml.example` placeholders are tracked). So there's no
  active exposure. Before a real production launch, still move `env_variables`
  secrets to **Secret Manager** so they aren't sitting in plaintext on deploy
  machines, and rotate the production values. Owner action; low urgency today.

---

## What's already good (don't regress these)

- Datastore **transactions** wrap every concurrency-critical write
  (`transactional_pod_update`, `_vote_update`, `_message_update`,
  `adjust_trust_score`, `transactional_signal_rsvp`) — the Feb 2026 race-condition
  pass holds up.
- iOS stores tokens in **Keychain**, uses **HTTPS** with no ATS exceptions, and
  has a clean single-retry 401→refresh→retry flow (`APIService.swift:155-178`).
- Account deletion (`delete_user_account`) already cascades across pods, friends,
  requests, signals, and missions.
- Refresh tokens are stored **SHA-256-hashed**, not in plaintext.
- `app.yaml` is correctly **gitignored and never committed** — secrets are not in
  git history (only `app.yaml.example` placeholders are tracked).
- 364 passing pytest tests covering API + service + validator + ML layers.

---

## Testing & CI gaps

- CI (`.github/workflows/ci.yml`) runs **only pytest** — no linter, no coverage
  gate, and the 3 XCTest files in `OrbitApp/OrbitTests/` never run.
- Tests **fully mock Datastore** (`tests/conftest.py` injects MagicMock) — good
  for units, but there is **no integration test against the Datastore emulator**,
  so query/index correctness (composite indexes in `index.yaml`) is unverified.
- No regression test pins the auth contract (a test currently asserts the
  `"123456"` bypass *works* — that test must flip when C2 is fixed).

---

## Deployment safety (verified)

- **Confirmed:** the only CI workflow triggers on push/PR to `main` and runs
  pytest. There is **no TestFlight, Fastlane, Xcode Cloud, or `gcloud deploy`**
  trigger anywhere. Pushing to a feature branch is safe; pushing to `main` only
  runs tests, not a release.
- **Confirmed:** no `dispatch.yaml`, no staging service, no version split in
  `app.yaml`. Deploys are manual and hit production directly — the brief's
  assumption is correct. **No deploy commands will be run.**

---

## Proposed fix phases (severity-ordered — awaiting your go-ahead)

Each batch is one `hardening/*` branch, one concern per commit, `pytest` run
before and after, and I stop for your approval before starting each.

| Batch | Branch | Covers | Severity |
|---|---|---|---|
| **A** | `hardening/security-pass-1` | C1 (fail-fast on missing prod secret), H2 (rate limits on verify/refresh), H3 (refresh rotation). *D1 bypass kept per owner; L6 secret-relocation deferred to pre-launch.* | Critical/High |
| **B** | `hardening/authz-and-errors` | H1 (auth + PII on profile), H4 (generic errors + global handler), M7 (security headers) | High/Med |
| **C** | `hardening/reliability` | M4 (embedding task queue), SendGrid timeout/retry, idempotency on writes | Medium |
| **D** | `hardening/efficiency` | M1 (batch N+1), M2/M3 (DM + conversation denormalization), M8 (pagination), M5 backend side | Medium |
| **E** | `hardening/testing-ci` | flip auth test, auth/authz regression tests, ruff + coverage gate in CI, wire XCTest | Medium |
| **F** | `hardening/ios-a11y-ux` | H5 (accessibility), M5 (polling backoff), M6 (error/empty states) | High(a11y)/Med |
| **G** | `hardening/analytics` | **done** — Datastore-only v1 of `docs/analytics-and-metrics.md`: pseudonymized event stream (`AnalyticsEvent` kind, idempotent), `POST /api/analytics/events`, server-side authoritative emission, iOS buffered client, deletion cascade, tests. BigQuery/Pub/Sub + rollups deferred to v2 (see doc header). | — |

**Recommended order:** A → B first (security), then E (lock in with tests), then
C/D (reliability/perf), then F (iOS), then G (analytics). See `main.md` for the
living status view and `docs/` for the schema, analytics design, and future
features.
