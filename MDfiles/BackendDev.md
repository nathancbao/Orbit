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
