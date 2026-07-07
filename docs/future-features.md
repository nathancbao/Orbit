# Orbit Future Features — 2026-07-06

> A prioritized backlog grounded in what already exists in the codebase and in the
> hardening work in `AUDIT.md`. Effort: **S** ≈ ≤1 day, **M** ≈ few days, **L** ≈
> 1–2+ weeks. "Prereq" names what must land first.

## Tier 1 — infrastructure the product needs to be trustworthy

| Feature | Value | Effort | Prereq |
|---|---|---|---|
| **Observability** (structured logging + error tracking, e.g. Cloud Logging + Sentry) | See failures before users report them; the swallowed `except: pass` blocks (M4) become visible | M | — |
| **Real analytics pipeline** | Turn the funnel in `docs/analytics-and-metrics.md` into live dashboards; makes success measurable | L | Batch A (secrets), analytics design approval |
| **Admin platform** (read-only web dashboard over BigQuery rollups) | You can see DAU, completion rate, funnel without a query console | L | analytics pipeline; WCAG 2.2 AA for the web surface |
| **Feature flags** (simple Datastore-backed flag service) | Ship risky changes dark; kill switches for polling/ML | S–M | — |
| **Cloud Tasks queue** for embeddings & deferred work | Fixes the fire-and-forget thread reliability bug (M4); foundation for no-show cron | M | — |

## Tier 2 — real push notifications (the APNS config already exists)

| Feature | Value | Effort | Prereq |
|---|---|---|---|
| **APNS push notifications** | `app.yaml` already carries APNS key/team/bundle and there's a `Notification` inbox kind + `/notifications/suggested`; only the OS-level registration and the APNS send path are missing | M | Batch A (rotate/relocate APNS key); iOS push entitlement + `UNUserNotificationCenter` registration |
| **Smart notification timing** | Use the analytics funnel to send "your pod is meeting soon" / "rate your last mission" at the right moment | M | push + analytics |
| **Digest instead of polling** | Replace the 1–5s client polling (M5) with server-pushed updates for chat/schedule | L | push |

## Tier 3 — AI / matching (extends the existing rec engine)

| Feature | Value | Effort | Prereq |
|---|---|---|---|
| **AI study-group formation** | `_find_best_pod_for_user` already does Jaccard interest matching + LightFM exists; extend to actively *form* balanced groups from the join pool rather than first-fit | M | — |
| **Smart scheduling** | The flex-mission availability grid (`schedule_data`, `availability` slots) is already collected; add an optimizer that proposes the best meeting time automatically | M | — |
| **Outcome-trained recommender** | Move from interest-overlap heuristic to a model trained on `mission_completed` + `enjoyment_rating` labels | L | analytics pipeline (labels) |
| **Personalized discovery ranking** | Replace the "score all missions in Python, sort" path (M8) with a ranked, paginated feed | M | pagination (Batch D) |

## Tier 4 — product surface

| Feature | Value | Effort | Prereq |
|---|---|---|---|
| **Pod meeting reminders + calendar export** | Add `.ics` / calendar deep-link from a confirmed pod | S | — |
| **Richer profiles / verification badges** | Trust score already exists; surface it and add `.edu` verification badge | S | — |
| **Report / block** | Safety baseline for a social app meeting strangers; ties into the existing kick-vote + trust system | M | — |
| **Web landing + real download link** | The friend deep-link page (`main.py`) has a "coming soon" download link; ship the actual App Store link and a marketing page | S | WCAG 2.2 AA |
| **Group DMs / pod-independent chat** | ChatMessage already backs both pod chat and DMs; generalize to arbitrary group threads | M | — |

## Sequencing note

Do **Batch A/B security** and **observability** before anything user-facing —
they're cheap insurance and unblock safe iteration. Analytics is the highest-
leverage Tier 1 item because almost every Tier 2–3 feature (smart timing, trained
recs, admin reporting) depends on the event stream existing. Push notifications
are the best "big visible win" once secrets are relocated, since the hard config
(APNS keys) is already in place.
