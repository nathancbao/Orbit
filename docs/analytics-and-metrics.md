# Orbit Analytics & Metrics Design — 2026-07-06

> **Status:** design/contract only — no instrumentation is implemented yet. This
> is the spec the future admin platform and ML layer build on. Implementation is
> **Batch G** in `AUDIT.md`, gated on your approval.
>
> **Design principle:** measure the core loop — **discover → join → complete →
> feedback** — with a clean, stable event taxonomy so the same data serves
> today's reporting and tomorrow's modeling. Collect the minimum needed; keep raw
> event volume out of Datastore.

---

## 1. Success metrics

Every metric is defined by the events it derives from, so it is auditable.

| Metric | Definition | Derived from |
|---|---|---|
| **Missions joined** | count of `mission_joined` | `mission_joined` |
| **Missions completed** | count of `mission_completed` (pod reached ≥50% confirmed) | `mission_completed` |
| **Completion rate** | completed ÷ joined, per cohort/time window | `mission_joined`, `mission_completed` |
| **Feedback surveys completed** | count of `survey_submitted` | `survey_submitted` |
| **Feedback rate** | surveys ÷ completions | `survey_submitted`, `mission_completed` |
| **Time-to-complete** | `mission_completed.ts − mission_joined.ts` for the same user+pod | join/complete pair |
| **Mission duration** | scheduled end − start (set) or actual window (flex) | mission fields at completion |
| **DAU / WAU / MAU** | distinct `user_id` with any event in 1/7/30 days | all events |
| **Activation funnel** | `signup → profile_completed → first_join → first_complete → first_survey` | those 5 events |
| **Core funnel** | `mission_viewed → mission_joined → mission_completed → survey_submitted` | those 4 events |

**Guardrail / health metrics:** join→leave churn (`mission_left` ÷ joined),
no-show rate (members not in `confirmed_attendees` at expiry), kick rate,
median enjoyment rating.

---

## 2. Event taxonomy

One flat event schema, `snake_case` event names, past-tense. Every event shares a
common envelope; event-specific fields go in `properties`.

### Common envelope (every event)

| Field | Type | Notes |
|---|---|---|
| `event_name` | string | e.g. `mission_joined` |
| `event_id` | UUID | idempotency key (dedupe retries) |
| `ts` | ISO-8601 UTC | client event time |
| `received_ts` | ISO-8601 UTC | server ingest time |
| `user_pseudo_id` | string | **pseudonymous** — HMAC(user_id, server salt), not the raw int |
| `session_id` | UUID | per app-foreground session |
| `platform` | string | `ios` |
| `app_version` | string | client build |
| `properties` | map | event-specific (below) |

### Event catalog

| Event | Key `properties` | Fires when |
|---|---|---|
| `app_opened` | — | app foregrounded |
| `signup_completed` | `college_year` | first verify-code success (new user) |
| `profile_completed` | `interest_count` | profile passes completeness check |
| `mission_viewed` | `mission_id`, `mode`, `tags`, `source` (feed/suggested/voyage) | detail opened |
| `mission_joined` | `mission_id`, `pod_id`, `mode`, `match_score` | join succeeds |
| `mission_left` | `mission_id`, `pod_id` | leave succeeds |
| `mission_skipped` | `mission_id` | skip tapped |
| `pod_meeting_confirmed` | `pod_id`, `time_to_confirm_s` | pod reaches `meeting_confirmed` |
| `attendance_confirmed` | `pod_id`, `mission_id` | confirm-attendance |
| `mission_completed` | `pod_id`, `mission_id`, `duration_s`, `confirmed_count` | pod → `completed` |
| `survey_submitted` | `pod_id`, `enjoyment_rating`, `added_interest_count` | survey POST |
| `signal_created` / `signal_rsvped` | `signal_id`, `category` | signal actions |
| `friend_request_sent` / `friend_accepted` | `target_pseudo_id` | friend actions |
| `chat_message_sent` | `pod_id`, `is_dm` (bool) | message send (**no content**) |
| `notification_opened` | `type` | inbox item tapped |

**Durations** ("how long stuff took") are computed server-side from event pairs,
not trusted from the client: `time_to_confirm_s`, `duration_s`,
`time_to_complete_s` are derived in the ETL, not sent raw.

---

## 3. Where the data lives

**Recommendation: stream events to BigQuery; keep only rollups in Datastore.**

| Store | Holds | Why |
|---|---|---|
| **BigQuery** (`orbit_analytics.events`) | raw event stream, partitioned by `DATE(received_ts)`, clustered on `event_name`, `user_pseudo_id` | cheap columnar analytics, natural GCP fit, the obvious staging ground for ML feature extraction; keeps high-volume rows out of Datastore |
| **Datastore** (`MetricRollup` kind) | small daily/user counters (joins, completions, DAU flags) | fast in-app reads (e.g. "you've completed 3 missions") without querying BigQuery per request |

**Ingestion path:** backend emits events → a lightweight `analytics_service.emit()`
→ buffered → **Pub/Sub topic** → BigQuery streaming insert (or the direct
`insertAll` streaming API for a simpler v1). iOS sends a batched
`POST /api/analytics/events` array on foreground/background transitions; the
server stamps `received_ts`, pseudonymizes, and forwards. `event_id` makes the
whole path idempotent.

**Tradeoffs / cost:** BigQuery streaming inserts are ~$0.01–0.05/GB ingested plus
cheap storage; at Orbit's current scale this is dollars/month. A
**Datastore-only v1** is viable to start (write events to an `AnalyticsEvent`
kind, aggregate with scheduled queries) and avoids standing up Pub/Sub — but it
bloats Datastore, makes ad-hoc analytical queries painful (no GROUP BY at scale),
and you'll migrate to BigQuery anyway once volume grows. **Recommend starting
directly on BigQuery** given GCP is already the platform; the added infra is one
topic + one table.

---

## 3a. Data modeling: separate kind, not a field on `User`

Behavioral events belong in a **dedicated append-only kind** (extend the existing
`UserHistory`, or add a sibling `AnalyticsEvent` kind) — **never** as a growing
list field on the `User` entity. Datastore-specific reasons:

- **1 MB entity cap:** a per-user event list grows unbounded and eventually
  exceeds Datastore's max entity size, at which point writes fail.
- **Write contention / lost updates:** appending to a list on `User` is a
  read-modify-write of the whole entity on every event; Datastore sustains ~1
  write/sec per entity, and concurrent events clobber each other without a
  transaction (which serializes the user's activity).
- **Cross-user queries:** funnels, DAU, completion rate aggregate *across* users;
  data trapped in per-user lists can't be queried without scanning every user.
- **Precedent:** `UserHistory` already models one row per interaction — this is
  the same shape.

**Exception — rollup counters on `User` are fine:** a small, bounded set of
current-state fields (`missions_completed_count`, `last_active_at`,
`survey_count`) can live on the `User` row for fast in-app reads, updated
transactionally when the corresponding event fires. Rule of thumb: **unbounded
history → its own kind; bounded current-state → a field.**

For a lean "for now" start, a Datastore-only `AnalyticsEvent` kind + a few `User`
rollup fields is a reasonable v1; migrate the raw stream to BigQuery (§3) once
volume or query needs grow.

---

## 4. Privacy, retention, deletion (non-negotiable)

**Fields collected — the exhaustive list for the privacy policy** is exactly the
envelope + `properties` fields in §2. Notable choices:

- **Pseudonymous IDs only.** `user_pseudo_id = HMAC-SHA256(user_id, ANALYTICS_SALT)`.
  Raw `user_id` and `email` are **never** written to the analytics store. The
  salt lives in Secret Manager (same rotation policy as other secrets).
- **No sensitive / special-category data.** Never collected: precise location,
  **contents of chat messages or DMs** (only `chat_message_sent` counts), gender,
  MBTI, bio text, health/political/etc. `added_interest_count` is a count, not the
  interests themselves.
- **Data minimization:** IDs and counts, not payloads. Mission `tags` are
  retained because they're non-personal and load-bearing for recs.

**Retention:**
- Raw BigQuery events: **14 months** (covers year-over-year), then table-partition
  expiration auto-deletes.
- Datastore rollups: kept while the account is active.

**Deletion cascade (GDPR/CCPA):** when a user deletes their account
(`delete_user_account`, `users.py:42`), the cascade must additionally:
1. delete their `MetricRollup` entities in Datastore, and
2. enqueue a BigQuery `DELETE FROM events WHERE user_pseudo_id = @id` (or tombstone
   for the next scheduled purge).
Because analytics is pseudonymized, this requires deriving the same
`user_pseudo_id` from the user's id at deletion time — deterministic HMAC makes
that a single computed value. **Data export** ("download my data") reads the same
`user_pseudo_id` slice.

---

## 5. ML-readiness

The event stream is structured so the recommender can later train on real
outcomes rather than the current interest-overlap heuristic:

- stable `mission_id` / `user_pseudo_id` join keys,
- explicit outcome labels (`mission_completed`, `enjoyment_rating`) tied to the
  join that produced them,
- `match_score` logged at join time so predicted-vs-actual can be evaluated,
- `tags` + `source` context for feature extraction.

This directly feeds the existing `UserHistory`/`SurveyResponse` signals (see
`docs/datastore-schema.md`) that `lightfm_service` and `ai_suggestion_service`
already consume — analytics becomes the richer, queryable superset.
