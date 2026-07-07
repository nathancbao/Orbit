# Orbit Production-Hardening Overhaul — Summary

> **Status:** Batches A–G complete (2026-07-06 → 2026-07-07). All work is
> committed to stacked local `hardening/*` branches; **nothing has been pushed
> or deployed.** Driven by `orbit-overhaul-prompt.md`; findings live in
> `AUDIT.md`.

---

## At a glance

| | |
|---|---|
| **Batches shipped** | 7 (A, B, C, D, E, F, G) |
| **Commits** | 20 (`main..hardening/analytics`) |
| **Files touched** | 71 (`+1433 / −180`) |
| **Tests** | 364 → **400 passing** (+36), 11 skipped |
| **Coverage** | ungated → **47%** (gate at 40%) |
| **Lint** | none → **ruff clean**, enforced in CI |
| **Pushed / deployed** | **No** — local branches only |

**Branch stack** (each builds on the previous):

```
main
 └─ hardening/security-pass-1        (A)
     └─ hardening/authz-and-errors    (B)
         └─ hardening/testing-ci       (E)
             └─ hardening/reliability-efficiency  (C+D)
                 └─ hardening/ios-a11y-ux          (F)
                     └─ hardening/analytics         (G)
```

---

## Batch A — Security pass 1 (`hardening/security-pass-1`)

Critical/high auth hardening.

- **C1 — JWT secret fail-fast.** `_load_jwt_secret()` refuses to start in
  production (`GAE_ENV` set) if `JWT_SECRET` is missing or the dev default —
  no more silently signing tokens with a public value. Dev fallback kept for
  local convenience. (`utils/auth.py`)
- **H2 — Rate limits.** `verify-code` 10/min, `refresh` 20/min, to blunt
  brute-force / token-farming. (`api/auth.py`)
- **H3 — Refresh-token rotation.** Each refresh mints a new refresh token,
  stores its hash, and deletes the old one. A unique `jti` on every token
  prevents same-second collisions (caught by a test). iOS `AuthService` saves
  the returned `refresh_token`. (`services/auth_service.py`, `utils/auth.py`,
  iOS `AuthService.swift`)

> ⚠️ **Deploy ordering for H3:** ship the iOS app change **before** deploying
> the rotating backend, or in-field apps get logged out on their next refresh.

---

## Batch B — AuthZ & errors (`hardening/authz-and-errors`)

- **H1 — Profile authz + PII.** `GET /users/<id>` now requires auth and strips
  private fields (email) unless you're requesting yourself.
  (`api/users.py`, `services/user_service.py`)
- **H4 — Consistent errors.** Global `HTTPException` / `Exception` handlers
  return the same JSON envelope as everything else (no stack traces / HTML);
  raw-exception leaks in send-code and uploads replaced with generic messages.
  (`main.py`)
- **M7 — Security headers.** `X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy`, HSTS on every response. (`main.py`)

---

## Batch E — Testing & CI (`hardening/testing-ci`)

- **ruff** lint config (`pyproject.toml`, rules F/E9/B) — fixed all findings.
- **Coverage gate** in pytest (`--cov-fail-under=40`, baseline ~45%).
- **CI** (`.github/workflows/ci.yml`) installs `requirements-dev.txt`, runs
  `ruff check` then pytest. (CI is pytest-only — no deploy triggers.)
- iOS XCTest **not** wired (no shared Xcode scheme) — noted as follow-up.

---

## Batch C — Reliability (`hardening/reliability-efficiency`)

- **M4 — Embedding work no longer silently dropped.** Background embedding
  threads log failures instead of swallowing them.
- **SendGrid retry.** Bounded retry (3×) on transient 5xx/network errors,
  *not* on 4xx (bad key/recipient) — fails fast into the log fallback rather
  than hanging the request. (`services/auth_service.py`)

## Batch D — Efficiency (same branch)

- **M1 — N+1 reads batched.** `get_users_batch()` (`get_multi` + cache) replaces
  per-member user lookups in friend / pod / pod-invite enrichment.
- **M3 — No more full chat-history loads.** `get_last_chat_message()`
  (descending, limit 1) replaces loading 200 messages just to show a preview.
- Reused the module Datastore client in `_find_replacement`. (`models.py` +
  the four services)

> **Deferred (structural):** M2 (search / DM-conversation denormalization —
> needs a `Conversation` kind) and M8 (mission pagination — would break the
> current iOS `GET /missions` contract).

---

## Batch F — iOS accessibility & UX (`hardening/ios-a11y-ux`)

- **Dynamic Type.** New `.orbitFont(...)` (`@ScaledMetric`-backed) replaces ~85
  frozen `.font(.system(size:))` sites so text scales with the user's
  accessibility text size. One geometry-sized map label left fixed on purpose.
- **Reduce Motion.** New `.orbitAnimation(...)` skips the animation when Reduce
  Motion is on; adopted on the continuous decorative motion (Missions
  drift/spin, Voyage pulse, tile fade) and toast slide-ins.
- **VoiceOver labels** on high-traffic icon-only controls: DM send, Friends
  toolbar (inbox/add/profile), and accept/decline for friend requests & pod
  invites.
- **Error surfacing.** Primary-content load failures (DM, Discovery, Friends)
  now set `errorMessage` and show a state instead of a silent empty screen;
  Discovery got an error banner. Dropped a stray debug `print`.
- **M5 corrected** in `AUDIT.md`: the "aggressive polling" finding was mostly a
  false alarm (UI countdown/toast/debounce timers, not backend polls).

> ⚠️ **Build-unverified:** no local Xcode. Changes are additive and
> signature-compatible but should be built + run once. Follow-ups needing Xcode:
> run the 3 XCTest files, AA contrast-check `OrbitTheme` colors, sim-test at
> accessibility text sizes.

---

## Batch G — Analytics (`hardening/analytics`)

Datastore-only **v1** of `docs/analytics-and-metrics.md` (BigQuery/Pub/Sub
deferred — can't stand up infra or deploy here).

- **Pseudonymous ids** — `pseudonymize(user_id) = HMAC-SHA256(user_id,
  ANALYTICS_SALT)`. Raw `user_id`/email never enter the analytics store. Salt
  loads with the same prod fail-fast policy as `JWT_SECRET`.
  (`utils/analytics_id.py`)
- **Event stream** — `AnalyticsEvent` kind keyed by `event_id` so retries
  overwrite instead of double-counting (idempotent). `analytics_service.emit()`
  / `ingest_batch()` validate against the event catalog, stamp `received_ts`,
  and are **best-effort** (log + swallow — analytics can never break a flow).
- **Ingestion endpoint** — `POST /api/analytics/events` (auth, 60/min, batch
  cap, server-derived pseudo-id; client-supplied identity ignored).
- **Server-side authoritative events** — `signup_completed`, `mission_joined`
  (+`match_score`), `mission_left`, `survey_submitted`, `friend_request_sent`,
  `friend_accepted`.
- **Deletion cascade** — account deletion recomputes the user's pseudo-id and
  purges their events (GDPR/CCPA).
- **iOS client** — `AnalyticsService` buffers events and flushes on
  foreground/background; `app_opened` + `mission_viewed` wired.
- **Tests** — `tests/test_analytics.py` (pseudonymize, emit/ingest, endpoint,
  idempotency contract, deletion purge).

> **Deferred v2:** BigQuery + Pub/Sub streaming, rollup counters,
> `mission_completed`/`attendance_confirmed` emissions (need pod-lifecycle
> transition points), `mission_viewed.source`, `notification_opened`, and the
> BigQuery deletion step.

---

## What still needs *you* (owner actions)

1. **Rotate secrets before prod** — `JWT_SECRET`, SendGrid key, APNS key. These
   are your action; I never touch secret values.
2. **Set `ANALYTICS_SALT`** in the real `app.yaml` — a strong, *stable* value.
   The app fails fast in prod without it; rotating it re-anonymizes all history.
   (Placeholder added to `app.yaml.example`.)
3. **Remove the `"123456"` demo bypass** (`auth_service.py`) before launch —
   kept intentionally for now per your call; it lets anyone log in as any email.
4. **Build + run the iOS app** — Batch F and the Batch G client are
   build-unverified (no local Xcode).
5. **Deploy order for H3** — iOS app first, then the rotating backend.

## Deferred (tracked, not lost)

M2 (Conversation-kind denormalization), M8 (mission pagination — iOS-coupled),
iOS XCTest in CI, and the analytics v2 items above.

---

## Verification

Every batch ran `pytest` before and after and stopped for approval. Final
state on `hardening/analytics`: **400 passed, 11 skipped**, coverage **47%**,
**ruff clean**. CI runs the same lint + test gate on push/PR. No `gcloud`/deploy
command was ever run; no branch was pushed.
