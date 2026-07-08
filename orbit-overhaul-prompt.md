# Claude Code Prompt — Orbit Full Audit & Production-Hardening Overhaul

> Paste everything below the line into Claude Code from the root of the Orbit repo.
> This is a monorepo: the backend lives in `OrbitServer/` and the iOS app in
> `OrbitApp/`. Audit both folders; produce the shared deliverables (schema, feature
> list, `main.md`) at the repo root.

---

## Role & goal

You are acting as a senior staff engineer doing a production-readiness review of
**Orbit**, a space-themed social-activity iOS app for college students. Orbit was
built quickly ("vibecoded") and I want to take it from *startup prototype* to a
**reliable, secure, production-grade app**. Your job is to audit every layer,
report findings clearly, and — only after I approve — implement fixes.

**Stack (confirm against the actual code before trusting this):**
- Repo layout: single **monorepo** — `OrbitServer/` (backend) and `OrbitApp/` (Swift iOS)
- Backend: Python **Flask**, **Firestore**, **Google App Engine** (some ML/serving on **Cloud Run**)
- Auth: **JWT**, transactional email via **SendGrid**
- iOS client: **Swift / Xcode**
- CI: **GitHub Actions**
- Core domain: **Crews** (friend groups), **Missions** (activities), a galaxy-aesthetic **discovery** page

## How to work (read this carefully — it governs everything)

1. **Inventory first, change nothing yet.** Start by mapping the repo: entry
   points, routes/endpoints, data models, auth flow, deployment config
   (`app.yaml`, `cloudbuild`, Dockerfiles), Firestore usage, and the Swift app's
   networking + view layer. Produce a short architecture map.
2. **Audit → report → propose → implement, in that order.** Do not rewrite code
   before I've seen the findings. Group findings by severity
   (Critical / High / Medium / Low) with, for each: the file + line, the concrete
   risk, and the proposed fix.
3. **Work in small, reviewable increments.** Once I approve fixes, do them in
   logical batches on a branch (e.g. `hardening/security-pass-1`), one concern per
   commit, with a clear message. Never force-push or rewrite history.
4. **Never break working behavior silently.** Before and after changes, run the
   test suite (or tell me none exists). If you change behavior, say so explicitly.
5. **Never expose or commit secrets.** If you find hardcoded keys, tokens, or
   credentials, flag them, tell me to rotate them, and move them to environment
   variables / Secret Manager — do not print full secret values in output.
6. **Ask before anything destructive or irreversible** (schema migrations,
   deleting data, changing IAM, touching production config).
7. Keep me in the loop with a running summary at the end of each phase.

## Deployment & environments (safety-critical — read before running anything)

- **Do NOT deploy.** Never run `gcloud app deploy` or any deploy/release command.
  The GCP backend deploys manually via `gcloud app deploy` **straight to
  production** — there is no separate staging environment that I'm aware of, so an
  accidental deploy hits real users. First, verify this assumption: check
  `OrbitServer/app.yaml`, any `dispatch.yaml`, and the GCP project/service config
  for a staging service or version split. Report what you find; even if a staging
  target exists, don't deploy without asking.
- **Be careful what you push.** The iOS app is wired so that a push can trigger a
  **TestFlight** build going out to testers (likely via GitHub Actions / Fastlane or
  Xcode Cloud). **Before pushing anything**, inspect the CI workflows
  (`.github/workflows/`, `fastlane/`, or Xcode Cloud config) to learn exactly which
  branches/tags trigger a TestFlight release. Do all work on a feature branch that
  does **not** trigger a release, and never push to `main` or any release branch
  without my explicit say-so. Confirm the trigger rules back to me before your first
  push.
- **All testing is local.** Since there's no confirmed staging, run and test
  everything locally — Flask dev server, and the **Firestore emulator** for any
  data-layer work so you never read or write production data. Never test against
  prod.

## Scope — audit these buckets across BOTH backend (`OrbitServer/`) and iOS (`OrbitApp/`)

Walk the entire codebase against this checklist. For each item, state whether it's
**present / partial / missing / N-A**, then note what to do.

### Security
- Input validation & sanitization on every endpoint (injection, NoSQL/Firestore
  query injection, header/JSON injection, path traversal)
- AuthN/AuthZ: JWT signing algo & secret handling, token expiry/refresh, revocation,
  per-resource authorization checks (can user X actually touch Crew/Mission Y?)
- Session & token storage on iOS (Keychain, not UserDefaults; no tokens in logs)
- Secrets management (Secret Manager / env vars, nothing in source or `app.yaml`)
- HTTPS/TLS everywhere; App Transport Security enforced on iOS
- Rate limiting & abuse protection on auth and write endpoints
- Dependency scanning (`pip-audit`/`safety` for Python, SwiftPM/CocoaPods advisories)
- Firestore Security Rules — audit these specifically; a permissive ruleset is the
  single most common way apps like this leak all their data
- CORS config, security headers, SendGrid credential handling

### Data, privacy & compliance
- Multi-tenancy / data isolation between users and Crews
- PII inventory & data retention policy; minimize what's stored
- GDPR/CCPA basics: account deletion, data export, consent where applicable
- Audit logging for sensitive actions (auth, role changes, deletions)

### Testing & quality
- Unit / integration / end-to-end coverage; identify the biggest untested risk areas
- Regression tests around auth and data-access paths
- Load/stress considerations for the write-heavy paths (Missions/Crews joins)
- Coverage gate + linting in the GitHub Actions CI pipeline
- Flag anything that needs code review discipline

### Reliability at runtime
- Error handling & consistent error responses (no stack traces to clients)
- Retries, idempotency (esp. anything that writes or sends email), circuit breakers
  for external calls (SendGrid, any third-party APIs)
- Concurrency & race conditions in Firestore writes (use transactions/`FieldValue`
  where needed)
- Caching strategy for hot reads (discovery page)
- RTO/RPO thinking: backups, disaster recovery for Firestore, rollback plan

### Frontend & accessibility
- **iOS:** treat Apple's accessibility APIs as the implementation of WCAG's POUR
  principles — VoiceOver labels/traits, Dynamic Type, sufficient color contrast
  (the galaxy/dark theme is a real risk here), focus order, hit-target sizes,
  reduced-motion support. Audit against Apple's HIG accessibility guidance.
- **Any web surface** (admin panel, marketing site, in-app web views): apply
  **WCAG 2.2 AA** directly. Reference: https://accessible.org/wcag/
- General UX correctness: loading/empty/error states, offline handling.

### Architecture & process
- Produce/refresh architecture **diagrams** (a request-flow diagram and a
  data-flow diagram are enough to start).
- Write short **ADRs** (Architecture Decision Records) for any significant change
  you recommend, so future decisions are documented.

## Also do: efficiency pass

Wherever it applies, flag and (after approval) improve code/method efficiency —
N+1 Firestore reads, redundant queries, unbatched writes, unnecessary re-renders or
main-thread work on iOS, oversized payloads, missing pagination on discovery. Keep
correctness first; call out the perf win and the tradeoff for each.

## Also do: analytics, metrics & measurable success

I want Orbit's success to be **reportable and measurable**, not a gut feeling, and I
want to start collecting the behavioral data that a future ML layer will need to
find what's working and what isn't. Design and (after approval) implement a
lightweight but rigorous analytics layer.

- **Define the success metrics up front.** Propose a concrete metric set with clear
  definitions and how each is computed. At minimum: missions **joined**, missions
  **completed**, completion rate (completed/joined), **feedback surveys completed**,
  time-to-complete / mission duration, active users (DAU/WAU/MAU), and a
  join → complete → feedback funnel. For each metric, state the event(s) it derives
  from so it's auditable.
- **Instrument event tracking** across backend and iOS to capture those events plus
  useful context: event name, timestamp, (pseudonymous) user id, mission/crew id,
  durations ("how long stuff took"), and outcome. Use one consistent event schema /
  taxonomy so the data is clean and ML-ready later.
- **Store analytics data in the right place.** Raw event volume will grow, so don't
  bloat Firestore with it. Recommend an approach with tradeoffs — my default lean is
  streaming events to **BigQuery** (natural fit for GCP, cheap for analytical
  queries, and the obvious staging ground for future ML), while keeping only
  lightweight rollups/counters in Firestore for fast in-app reads. If you think a
  simpler Firestore-only start is better for now, make the case. Note the added
  storage/cost either way.
- **Privacy & legal are non-negotiable.** Collect only what's needed
  (data minimization); pseudonymize user identifiers where possible; set a retention
  policy; make sure account deletion / data-export requests cascade into the
  analytics store (GDPR/CCPA). List every field being collected so it can go into the
  privacy policy and ToS, and flag anything that could be considered sensitive so I
  can exclude it. Do **not** collect precise location, contents of private messages,
  or any special-category data without me explicitly opting in.
- **Make it queryable/reportable now, ML-ready later.** Structure events with
  consistent keys, timestamps, and stable IDs so the same data supports both current
  reporting (which the planned admin platform will surface) and future modeling.

## Deliverables (create these as files in the repo)

1. **`AUDIT.md`** — the full findings report, organized by the buckets above, each
   finding tagged with severity, location, risk, and recommended fix.
2. **`docs/firestore-schema.md`** — a clear schema of every Firestore data
   structure the app uses: each collection/subcollection, document shape with field
   names + types + whether required, relationships between them (Users ↔ Crews ↔
   Missions), and which indexes are needed. Derive this from the actual code, not
   assumptions, and note anywhere the code and Firestore Rules disagree.
3. **`docs/analytics-and-metrics.md`** — the analytics design: the success-metric
   definitions, the event taxonomy/schema, where data is stored (Firestore vs.
   BigQuery) and why, the exact fields collected (for the privacy policy), the
   retention policy, and how deletion cascades. This is the contract the admin
   platform and future ML will build on.
4. **`docs/future-features.md`** — a prioritized list of features I could add next,
   grounded in what already exists and in the hardening work above (e.g. the
   AI study-group formation / smart-scheduling ideas, plus infra features like
   proper observability, feature flags, push notifications done safely). For each:
   one-line value, rough effort (S/M/L), and any prerequisites.
5. **`main.md`** — a living status doc tracking the current state of the app, dated
   **2026-07-06** at the top. Before writing it, look at the other `.md` files in
   the repo and match their structure, tone, and formatting conventions. It should
   capture: current architecture summary, what's done, known issues/tech debt (link
   to `AUDIT.md`), and next steps. This is meant to be updated over time, so make it
   easy to append to.

## Output for this first turn

Do **only Phase 1** now: the architecture map + the `AUDIT.md` findings (no code
changes yet). End with a proposed, severity-ordered plan for the fix phases and
wait for my go-ahead before touching code.
