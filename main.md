# Orbit — Living Status

> **Last updated:** 2026-07-06
> **Purpose:** the single at-a-glance status doc for Orbit — current
> architecture, what's done, known issues, and next steps. Append-friendly:
> add a dated entry under **Changelog** each time state changes materially.

Orbit is a space-themed social-activity app for college students: users discover
**missions** (activities), get grouped into **pods** (small groups), meet up, and
give feedback. Built fast ("vibecoded"); this doc tracks the push to
production-grade.

---

## Architecture summary

| Layer | Stack |
|---|---|
| iOS client | Swift / SwiftUI, MVVM; `APIService` over URLSession (async/await); tokens in Keychain; HTTPS-only |
| Backend | Python **Flask** at repo root (`main.py`) + `OrbitServer/` package; 10 blueprints |
| Data | **Google Cloud Datastore** (Datastore mode — *not* Firestore); in-proc TTL cache |
| Hosting | Google App Engine (F2, gunicorn, autoscale 0–3); manual deploy, **prod only** |
| Auth | JWT HS256 (15-min access / 7-day refresh); email-code login via **SendGrid** |
| Storage | Google Cloud Storage (profile/mission photos) |
| ML | fastembed embeddings + LightFM recommender (`ai_suggestion_service`) |
| CI | GitHub Actions — pytest on push/PR to `main`. **No** deploy/TestFlight trigger |

Detailed data model: `docs/datastore-schema.md`. Request/data-flow diagrams:
`AUDIT.md`.

---

## What's done

- Core loop working end-to-end: discover → join → pod → schedule → confirm →
  post-activity survey.
- Missions unified into one `set`/`flex` kind (recent migration; see
  `MDfiles/`), flex reuses the pod scheduling system.
- Concurrency-safe writes via Datastore transactions (Feb 2026 race-condition
  pass — `MDfiles/ServerSideFixes.md`).
- Friends, DMs, pod chat with reactions/pins/votes, pod invites, voyage
  discovery, in-app notification inbox.
- Auth hardening basics: hashed refresh tokens, 3-strike code lockout, Keychain
  storage on iOS, single-retry 401→refresh flow.
- 364 passing pytest tests (API + service + validator + ML layers).

---

## Known issues / tech debt

Full findings with file:line and fixes are in **`AUDIT.md`**. Headlines:

- **Critical:** `JWT_SECRET` dev fallback (fail-fast fix planned). *The `"123456"`
  demo auth bypass is intentionally retained for now — **must** be removed before
  production launch. Secrets in `app.yaml` are gitignored/not leaked; relocate to
  Secret Manager pre-launch.*
- **High:** public profile endpoint leaks email; no rate limit on
  `verify-code`/`refresh` (and in-memory limiter); refresh tokens not rotated;
  raw exceptions returned to clients; near-zero iOS accessibility.
- **Medium:** N+1 Datastore reads; full-scan search/DM queries; aggressive iOS
  polling (1–5s); errors swallowed into `print()`; no pagination on discovery;
  fire-and-forget embedding threads.
- **Testing/CI:** pytest-only (no lint/coverage gate, XCTest not in CI); Datastore
  fully mocked (no emulator integration tests).

---

## Next steps

Severity-ordered fix phases (each a `hardening/*` branch, one concern per commit,
tests before/after, approval before each). Full table in `AUDIT.md`.

1. **Batch A — security pass 1:** remove auth bypass, fail-fast on secret,
   relocate secrets to Secret Manager (+ rotate), rate limits, refresh rotation.
2. **Batch B — authz & errors:** auth + PII fix on profile, generic errors +
   global handler, security headers.
3. **Batch E — testing/CI:** flip the auth test, auth/authz regression tests,
   ruff + coverage gate, wire XCTest.
4. **Batch C/D — reliability & efficiency:** embedding task queue, SendGrid
   retry/timeout, batch N+1, DM/conversation denormalization, pagination, polling
   backoff.
5. **Batch F — iOS a11y & UX:** Dynamic Type, VoiceOver, contrast, error/empty
   states.
6. **Batch G — analytics:** implement `docs/analytics-and-metrics.md`.

Beyond hardening: `docs/future-features.md` (observability, real APNS push, AI
group formation, admin platform).

---

## Changelog

- **2026-07-06** — First full production-readiness audit. Added `AUDIT.md`,
  `docs/datastore-schema.md`, `docs/analytics-and-metrics.md`,
  `docs/future-features.md`, and this status doc. No code changed yet; fix phases
  proposed and awaiting approval. Baseline: 364 pytest tests passing.
