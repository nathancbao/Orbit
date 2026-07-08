# Backend Development Notes

A living document tracking backend concepts, tools, and patterns — from student project to industry-level engineering.

---

## Orbit's Current State

**What's already done well**
- Rate limiting (`rate_limit.py`)
- In-memory caching (`mission_cache`, `pod_cache`, `user_cache`)
- Transactional writes (`transactional_pod_update`, `transactional_signal_rsvp`) — prevents race conditions
- Warmup handler (`/_ah/warmup`) — reduces cold start latency
- Hard deletes — correct choice for Orbit's "things disappear" philosophy

**Current gaps**
- Most API files (`chat.py`, `signals.py`, `dm.py`, `users.py`) have zero logging
- Some files use Python's `logging` module but without JSON structure
- A few leftover `print` statements in `auth_service.py`
- In-memory cache is per-instance — breaks across multiple App Engine instances
- No error monitoring (you won't know about bugs unless users report them)
- Chat likely uses polling instead of a persistent connection

---

## Priority Improvements (in order)

### 1. Structured JSON Logging + Request Middleware
Python's `logging` module outputs plain text by default. Structured JSON lets GCP Logging parse fields so you can query things like "all 500 errors in the last hour" or "all requests from user 42."

A single middleware in `main.py` should log every request:
```json
{ "method": "POST", "path": "/api/missions", "status": 200, "duration_ms": 43, "user_id": 91 }
```

### 2. Sentry
Catches unhandled exceptions in production and alerts you. Without it, bugs are invisible until a user reports them. Free tier, ~10 minutes to integrate with Flask. Used by essentially every startup.

### 3. Redis (Shared Cache)
Current caches are in-memory and per-instance. With `max_instances: 3`, you can have 3 App Engine instances each with a different cache state. Redis is a single shared cache all instances talk to. Also enables proper distributed rate limiting.

### 4. Cloud Tasks (Scheduled Deletion)
Instead of a nightly cron sweep, enqueue "delete mission X at timestamp T" the moment it's created. More precise, more scalable. Directly relevant to Orbit's expiry philosophy.

### 5. WebSockets / Firebase for Chat
Current chat almost certainly polls (`GET /pods/<id>/messages` on an interval). Real-time chat needs a persistent connection. Firebase Realtime Database or socket.io are the common choices at Orbit's scale.

---

## Core Backend Concepts

### Scheduled Work & Async Processing
- **Cron jobs** (`cron.yaml` on App Engine) — industry standard for cleanup, digest emails, data aggregation. Deploy alongside your app with `gcloud app deploy cron.yaml`.
- **Task queues** (Cloud Tasks, AWS SQS, Celery + Redis) — instead of "run cleanup at 1am," you enqueue individual jobs with specific execution times. More precise and more scalable than cron at high volume.
- **Message queues / event-driven** (Kafka, RabbitMQ) — publish events like `MissionExpired`, and other services subscribe and react independently. Decouples services. Relevant at scale; overkill for Orbit right now.

### Databases
- **SQL (Postgres, MySQL)** — relational data, strong consistency, most common default. Instagram runs on Postgres. Best default choice for new projects.
- **NoSQL (Datastore, DynamoDB, MongoDB)** — flexible schemas, horizontal scale, eventual consistency tradeoffs. Orbit uses Datastore.
- **Redis** — in-memory key-value store. Used for caching, session storage, rate limiting, pub/sub, leaderboards. Not a primary database.
- **Key lesson** — most startups that switched from NoSQL back to Postgres did it because joins and transactions are hard to replace. Pick boring tech.

### Soft Deletes vs Hard Deletes
- **Hard delete** — remove the row entirely. Orbit's correct choice given the "things disappear" philosophy.
- **Soft delete** — set `deleted_at = now`, keep the row. Easier recovery from bugs, audit trails, analytics. Downside: DB grows forever, every query needs `WHERE deleted_at IS NULL`.

### Observability (Logging, Metrics, Traces)
The three pillars that separate production systems from hobby projects:
- **Logs** — structured JSON, aggregated in GCP Logging, Datadog, or Grafana
- **Metrics** — counters and timers on every operation (requests/sec, error rate, DB query latency)
- **Traces** — following a single request across multiple services to find where it's slow

### API Design Patterns
- **REST** — what Orbit uses. Standard, widely understood, good default.
- **GraphQL** — invented by Facebook for mobile apps that need flexible data shapes. Useful when different screens need different subsets of the same data.
- **gRPC** — binary protocol used for internal service-to-service calls. Much faster than JSON/HTTP. Used when you have multiple backend services talking to each other.

### Scaling Patterns
- **Horizontal scaling** — add more instances (what App Engine's `automatic_scaling` does)
- **Vertical scaling** — give each instance more CPU/memory (changing `instance_class` in `app.yaml`)
- **Read replicas** — route read queries to a copy of the database, writes go to the primary. Reduces load on the main DB.
- **Sharding** — split data across multiple databases by some key (e.g., by user ID range). Relevant at very high scale.

---

## Tools Reference

| Tool | What it does | When to use |
|---|---|---|
| Redis | Shared cache, pub/sub, rate limiting | When you have multiple server instances |
| Sentry | Exception monitoring and alerting | As soon as you have real users |
| Cloud Tasks | Enqueue jobs with specific run times | Scheduled deletions, async work |
| Kafka | High-volume event streaming | Millions of events/sec across many services |
| Firebase Realtime DB | WebSocket-based real-time sync | Chat, live presence features |
| gRPC | Fast binary RPC between services | Internal microservice communication |
| Datadog / Grafana | Metrics dashboards and alerting | Monitoring production health |

---

## The Senior Dev Mindset

- **Reliability over cleverness** — boring, well-understood tech outperforms clever solutions that are hard to debug at 2am.
- **Observability first** — if you can't see what your system is doing, you can't fix it.
- **Don't design for hypothetical scale** — Facebook didn't start with Kafka and distributed tracing. They started with PHP and MySQL. Add complexity only when you have the problem.
- **Measure twice, cut once** — understand the failure mode before you pick the solution.

---

## Notification System

This is the design notebook for Orbit's notifications. The single most important idea up front: **notifications are not one system, they're two.** Treating them as one is the mistake that burns both your gcloud credits and your users' patience.

### The two classes of notification

| | **Transactional (event-driven)** | **Recommendation (AI / discretionary)** |
|---|---|---|
| Examples | New chat message, someone joined your mission, friend request, RSVP to your event | "You might like: Hiking at Lake Berryessa", "3 missions near you tonight" |
| Trigger | A real thing happened in the DB | *We* decided to reach out |
| Cost | ~free (the work already happened) | Expensive — runs the recommender, costs CPU/credits |
| User tolerance | High — they expect it | Low — too many and they disable notifications entirely |
| Question to answer | *Who do I tell?* | *Should I send anything at all, and to whom, and when?* |

Almost all the hard thinking — spacing, dynamic frequency, "save credits" — is about the **second** class only. The first class is cheap and should fire immediately. Don't accidentally apply recommendation throttling to a chat message; that just makes your app feel broken.

### How Orbit is wired today

You already have the recommendation half half-built, and it's pull-based:
- `GET /api/notifications/suggested` → `ai_suggestion_service.get_suggested_missions(user_id, limit=1)` → returns one mission formatted as a notification payload.
- The hybrid scorer (`ai_suggestion_service.py`) already produces a `match_score` in [0,1] from TF-IDF + semantic + LightFM + behavioral + trust. **That score is the gate** you'll use to decide whether a recommendation is worth a push.
- The client currently has to *ask*. That's actually a good starting point — see "Pull vs push" below.

So the missing pieces are: (1) transactional triggers for chat/joins, (2) a delivery channel (APNs), and (3) the policy layer that decides *when* a recommendation is allowed to be sent.

---

### Part 1 — Structuring the transactional trigger

Don't sprinkle `send_notification(...)` calls all over your route handlers. The clean pattern is a thin **notification service** that the rest of the code calls with intent, not mechanics:

```
chat_service.post_message()      ─┐
mission_service.join_mission()   ─┼─→ notification_service.notify(event_type, actor, recipients, payload)
friend_service.send_request()    ─┘                       │
                                                          ├─ build payload (title/body/deep-link)
                                                          ├─ check recipient preferences (muted? DND hours?)
                                                          ├─ dedupe / collapse (see below)
                                                          └─ enqueue delivery (APNs)
```

Three rules that matter even at startup scale:

1. **Fire-and-forget, off the request path.** The user who sent the chat message shouldn't wait for the recipient's push to be delivered. Enqueue it (Cloud Tasks, or even a thread) and return. A failed push must never fail the API call that triggered it.
2. **Collapse / debounce.** If someone sends 5 messages in 10 seconds, the recipient wants *one* "3 new messages in Lake Trip" notification, not five. Key notifications by `(recipient, thread)` and coalesce within a short window. This is the single biggest "feels professional vs feels spammy" lever for transactional notifications.
3. **Respect a preference + DND check in one place.** Per-user mute, per-mission mute, quiet hours (e.g. 10pm–8am). Putting it in the service means you can't forget it on some route.

A `Notification` record in Datastore is worth having even if delivery is push-only — it gives you an in-app inbox, lets you mark read/unread, and is your audit trail for "did we actually send this."

---

### Part 2 — The recommendation policy (the part you actually asked about)

The question "how often should I space AI recommendations" is really four smaller questions. Answer them as independent gates — a recommendation must pass **all** of them to be sent.

**Gate A — Is there anything good enough to send? (quality gate)**
You already have `match_score`. Set a floor. Below it, send nothing — silence is a feature.
- Start with something like `match_score >= 0.70`. Tune from data later.
- This alone solves "should it only be on high match": **yes, gate on the score you already compute.** A mediocre recommendation costs you a credit *and* a bit of the user's trust; both are worse than not sending.

**Gate B — Is it time-sensitive? (urgency boost)**
A high-match mission happening *tonight* is worth interrupting someone for; the same mission three weeks out is not. Fold time-to-event into the send decision, not just the ranking:
- Effective priority ≈ `match_score * urgency_multiplier`, where urgency rises as the event approaches (e.g. ×1.0 for >1 week out, ×1.3 for <48h, ×1.6 for <12h).
- This is exactly your "random events happening soon" intuition, made concrete. "Soon + good match" is your best notification; "soon + mediocre" still shouldn't fire.

**Gate C — Have we sent too much recently? (frequency cap)**
This is the hard ceiling that protects credits *and* retention. Per user:
- A **max sends per day/week** (e.g. ≤1/day, ≤4/week for recommendations).
- A **minimum gap** between recommendation pushes (e.g. ≥18h).
- Track `last_recommendation_sent_at` and a rolling count on the user record. Cheap to check, and it's the thing that actually caps your gcloud bill.

**Gate D — Will this person even care? (dynamic frequency — your engagement question)**
This is where "someone who interacts more gets more" comes in. Don't hand-build a per-user schedule; derive the cap from behavior:
- Compute a lightweight **engagement score** per user: opens, mission joins, notification taps vs dismissals, recency of last active session. You already log `UserHistory` — that's most of the raw material.
- Map engagement → frequency cap as a small ladder, not a continuous function:

  | Engagement tier | Signal | Rec cap |
  |---|---|---|
  | Dormant | no opens in 14d | 1 / week (a "we miss you" nudge) |
  | Casual | opens occasionally, rarely taps notifs | 2 / week |
  | Active | regular opens, joins missions | 1 / day |
  | Power | daily, taps recommendations | up to 2 / day |

- **Close the loop:** if a user dismisses/ignores N recommendations in a row without tapping, demote them a tier automatically. If they tap, promote. This negative-feedback loop is what keeps you from training users to ignore you — and it's the genuinely "dynamic" part.

**Putting the gates together:**
```
candidate = best_unsent_mission(user)
if candidate.match_score < QUALITY_FLOOR:            return  # Gate A
priority = candidate.match_score * urgency(candidate)# Gate B
if now - user.last_rec_sent_at < user.min_gap:       return  # Gate C
if user.recs_today >= tier_cap(user.engagement):     return  # C + D
send(candidate); record_sent(user)
```

---

### Part 3 — Pull vs push, and *when* to compute (where the credits actually go)

Two distinct cost levers, often confused:

**1. Computation cost — when do you run the recommender?**
Don't score on every request. Options, cheapest first:
- **Precompute on a schedule.** A nightly/few-times-daily cron (you already use `cron.yaml`, and LightFM already has a `retrain()` cron hook) computes each active user's top candidate and stores it. Sending is then a near-free lookup. This is the right default for Orbit.
- **Compute lazily on the pull.** Your current `/suggested` endpoint computes on demand. Fine while small, but cache the result (Redis, short TTL) so a client polling every few minutes doesn't re-run the scorer each time.
- **Event-triggered recompute.** Only re-score a user when something changed (they joined a mission, a new mission near them was created). Most efficient but more plumbing — a later optimization.

**2. Delivery cost — pull vs push.**
- **Pull (today):** client calls `/suggested` on app open / background fetch. Zero server-initiated infra, but you can't re-engage a user who isn't opening the app — which is the whole point of recommendations.
- **Push (APNs):** server decides and sends. APNs itself is free; the cost is the *computation* behind deciding to send, which Gates A–D and precomputation already bound.
- **Pragmatic combo for Orbit:** transactional events → real push (APNs) immediately. Recommendations → precomputed nightly, delivered as a single capped push at a good local time (see send-time below), *and* surfaced in-app on open so engaged users see them without a push being "spent."

---

### How big tech does it

The gates above are a simplified version of what large consumer apps run:

- **It's an ML ranking + a "should-send" model, not a rule.** Meta/LinkedIn/Twitter don't ask "is this above a threshold" so much as predict **P(user engages | we send this now)** and only send when expected value beats a cost. The cost term explicitly includes *long-term* harm — sending too much measurably increases app uninstalls, so the model is penalized for it. Your Gate A threshold is the startup-sized stand-in for that model.
- **Frequency capping is a hard, separate layer.** Even with a great ranker, there's an independent cap service that enforces "no more than X/day." Exactly your Gate C.
- **Send-time optimization (STO).** They learn *when each user opens the app* and queue notifications for that window (LinkedIn published on this). A poor-but-well-timed notification beats a great-but-3am one.
- **Volume control / "notification budget" per user** that adapts to engagement — directly your Gate D, just learned rather than laddered.
- **Holdout groups.** They permanently keep a small % of users who get *no* discretionary notifications, to measure whether notifications actually help retention or just annoy. Sobering and worth knowing.

The throughline: **the constraint is the user's attention, not the server's capacity.** Every send spends trust. They optimize the *whole sequence* of notifications over a user's lifetime, not each one in isolation.

### What you should actually do (small startup)

Resist building the ML "should-send" model now. In order:

1. **Split the two classes.** Transactional fires immediately (with collapse + DND); recommendations go through the policy gates. This one decision gets you 80% of the quality.
2. **One notification service + a `Notification` Datastore record.** Single place for preferences, DND, dedupe, and an in-app inbox.
3. **Gate A + C first** — a `match_score` floor and a hard daily/weekly cap with a min-gap. Two constants, biggest bang, directly caps your bill.
4. **Precompute recommendations on a cron**, reuse your existing LightFM retrain cadence. Sending becomes a cheap lookup.
5. **Add Gate B (urgency)** next — you have event times already; it's a multiplier.
6. **Add Gate D (engagement ladder) last**, starting with the dumbest version: a tap promotes, repeated ignores demote. Don't build a model; build the feedback loop.
7. **Defer:** send-time optimization, holdout groups, a learned send-propensity model. Revisit when you have enough notification-tap data to train on (thousands of sends), not before.

Rule of thumb to hold onto: **a recommendation you're not sure about is a recommendation you shouldn't send.** The default is silence; the recommender's job is to occasionally earn an interruption.

---

## What is "cron"?

It keeps coming up (LightFM `retrain()`, scheduled deletion, recommendation precompute), so here's the whole thing in one place.

**A cron job is just "run this command automatically on a schedule."** That's the entire concept. "At 2am every day, run the cleanup script." "Every 15 minutes, retrain the model." You write the schedule once; the system runs the job forever without anyone touching it.

**What it stands for:** the name comes from **Chronos** (χρόνος), the Greek word for *time* — same root as "chronology" and "chronometer." It originated as a daemon (a background program) in early Unix in the 1970s. "Cron" is the program; a single scheduled task it runs is a "cron job"; the file listing those tasks is the "crontab" (cron table).

**The thing that confuses everyone — the cron expression.** Schedules are written as five fields, which look cryptic until you know the slots:

```
┌───────── minute        (0–59)
│ ┌─────── hour          (0–23)
│ │ ┌───── day of month  (1–31)
│ │ │ ┌─── month         (1–12)
│ │ │ │ ┌─ day of week   (0–6, Sunday = 0)
│ │ │ │ │
* * * * *   ← "every minute"
```
A `*` means "every value." Examples:
- `0 2 * * *` → at 02:00, every day (classic nightly cleanup)
- `*/15 * * * *` → every 15 minutes
- `0 9 * * 1` → 09:00 every Monday (weekly digest email)
- `0 0 1 * *` → midnight on the 1st of each month

(Note: App Engine's `cron.yaml`, which is what *Orbit* uses, takes plain-English schedules like `every 24 hours` or `every monday 09:00` instead of the five-field syntax — but it's the same concept, and the five-field form is what you'll see everywhere else.)

### Where "cron" shows up — the contexts

The word travels far beyond the original Unix daemon. When someone says "cron," they could mean any of these:

| Context | What it actually is |
|---|---|
| **Classic Unix/Linux `cron`** | The original daemon on a server. Edit with `crontab -e`. Runs shell commands on a schedule. |
| **App Engine `cron.yaml`** (Orbit) | GCP's managed version — it pings a URL in your app on a schedule, instead of running a shell command. Deploy with `gcloud app deploy cron.yaml`. |
| **Cloud Scheduler** (GCP), **EventBridge Scheduler** (AWS) | Fully managed, standalone cron-as-a-service. Triggers HTTP endpoints, pub/sub messages, or functions. |
| **Kubernetes `CronJob`** | A k8s object that spins up a container on a schedule. |
| **CI/CD scheduled runs** | GitHub Actions `on: schedule:` uses cron syntax to run a workflow nightly, etc. |
| **App-level schedulers** | Libraries like `node-cron`, Python's `APScheduler`, or Celery Beat run scheduled jobs inside your app process. |

The common thread: a **schedule** + a **job**. The thing that differs is *where* the scheduler lives and *what* it triggers (a shell command, an HTTP request, a container, a function).

### Cron vs. the alternatives

- **Cron** answers "do this *on a clock*" — recurring, time-based, fine if "around 2am" is good enough. It does **not** know whether the last run finished, and a job that overruns can overlap with the next tick.
- **Task queue** (Cloud Tasks, Celery) answers "do this *specific job* at *this specific time*, once." Better when timing is precise or per-item (e.g. "delete mission #482 exactly when it expires" rather than "sweep all expired missions nightly"). This is the upgrade path noted earlier for Orbit's deletions.
- **Event-driven** answers "do this *when X happens*" — no clock at all. (See the recommendation recompute options above.)

Rule of thumb: reach for **cron** for periodic maintenance (cleanup, retraining, digests, aggregation) where exact timing doesn't matter; reach for a **task queue** when each job has its own deadline or you need per-item precision.
