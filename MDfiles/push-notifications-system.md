# Push Notifications & Smart Notification System — Design

> Companion to `docs/future-features.md` (Tier 2). This document explains what
> the notification system looks like end-to-end: the **backend**, the **iOS
> client**, the **GCP** pieces (cron, scheduling, queues), the **TestFlight /
> Apple** pieces, and how larger companies structure this so we can copy the
> parts that matter. Written 2026-07-10.

---

## 0. TL;DR / mental model

There are **three distinct notification channels**, and conflating them is the
main thing that makes people build this wrong:

| Channel | Who wakes the phone | Shows when app is… | Example |
|---|---|---|---|
| **Remote push (APNS)** | Our server → Apple → device | closed / backgrounded | "Your pod meets in 1h" |
| **Foreground / in-app banner** | The app itself | open, in front of the user | New chat message arrives while you're on another tab |
| **In-app inbox** | Server writes a row; client reads it | any time (it's a list) | "The pod you were in was deleted" |

Orbit **already has channel 3** (the `Notification` Datastore kind +
`/api/notifications` inbox). We are missing channels 1 and 2. The APNS config
already lives in `app.yaml`; what's missing is (a) storing device tokens, (b) an
APNS *send* path on the server, and (c) OS-level registration + handling on iOS.

The rest of this doc is: **transactional (event-driven) pushes first**, then a
**scheduled/cron layer** for digests and reminders, and the client work to
receive all of it.

---

## 1. Where we are today (grounded in the code)

**Server (`OrbitServer/`, Flask on App Engine, Datastore):**
- `models.py` → `create_notification / list_notifications / mark_notifications_read`. The `Notification` kind is an **in-app inbox row only** — it never leaves the server as a push.
- `api/notifications.py` → `GET /api/notifications`, `POST /api/notifications/read`, and `GET /api/notifications/suggested` (returns an AI mission suggestion *shaped like* a push payload, but delivered over HTTP — the client has to ask for it).
- `services/ai_suggestion_service.py` → the hybrid recommender (`get_suggested_missions`). This is the "what should we tell the user about" brain. It already exists.
- `app.yaml` carries `APNS_KEY_PATH / APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID / APNS_USE_SANDBOX`. **No code reads these yet.**
- `cron.yaml` has exactly one job today: a daily `/api/tasks/cleanup`, gated by the `X-Appengine-Cron: true` header (App Engine strips that header from external callers, so only real cron can hit it). This is the pattern every future scheduled job will copy.

**iOS (`OrbitApp/`, SwiftUI):**
- `OrbitApp.swift` already wires an `AppDelegate` via `@UIApplicationDelegateAdaptor` (currently only used to lock orientation) and already tracks `scenePhase` for analytics. Both are exactly the hooks we need.
- `NotificationService.swift` only fetches the in-app inbox. There is **no** `UNUserNotificationCenter`, no `registerForRemoteNotifications`, no permission prompt.
- `Orbit.entitlements` has associated-domains (for deep links) but **no `aps-environment` / Push Notifications capability**.

So the gap is narrow and well-defined. Good news: the hard, finicky part (APNS auth key, recommender) is done.

---

## 2. Backend design

### 2.1 Store device tokens (new)

A push is "send this payload to these device tokens." So first we need to know a
user's tokens. Add a Datastore kind and one endpoint.

**New kind `DeviceToken`** (`models.py`):
```
DeviceToken
  key            = the APNS token string (so re-registering overwrites, idempotent)
  user_id        int
  platform       "ios"
  environment    "sandbox" | "production"   # must match how the build was signed
  app_version    string
  created_at / last_seen_at
  active         bool     # flip false on 410 Gone from APNS
```
Keying by the token itself means a device that re-registers just overwrites its
own row — no duplicates. One user can have many tokens (iPhone + iPad, or the
same phone after a reinstall).

**New endpoint** `POST /api/notifications/register-token` (auth required):
```json
{ "token": "<hex>", "environment": "production", "app_version": "1.4.0" }
```
Writes/updates the `DeviceToken` row for `g.user_id`. Called by the client every
launch after it gets a token (tokens can rotate; treat "register on every launch"
as normal and cheap).

Also add `POST /api/notifications/unregister-token` for logout, so a shared
device doesn't keep pushing the previous user's alerts.

### 2.2 The APNS send path (new)

Add `services/push_service.py`. Use **token-based auth (.p8 key)** — which is
exactly what `app.yaml` is already configured for (key id / team id / bundle id).
Token auth is stateless and doesn't expire like certificates, which is why big
apps use it.

Recommended library: **`apns2`** or **`aioapns`** (HTTP/2 to
`api.push.apple.com`, or `api.sandbox.push.apple.com` for dev builds — chosen by
the token's `environment`, *not* a global flag).

```python
def send_push(user_id, title, body, data=None, collapse_id=None):
    tokens = active_tokens_for_user(user_id)
    for t in tokens:
        payload = {
            "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
                "badge": unread_count(user_id),
                "thread-id": data.get("thread_id") if data else None,
            },
            **(data or {}),   # custom keys: mission_id, pod_id, type, deep_link
        }
        resp = apns_client.send(t.token, payload, topic=BUNDLE_ID,
                                collapse_id=collapse_id, environment=t.environment)
        if resp.status == 410:      # Unregistered / uninstalled
            deactivate_token(t.token)
```

Key details that matter:
- **`collapse_id`** (a.k.a. `apns-collapse-id`): APNS replaces an undelivered
  notification with the same id instead of stacking 5 "new message" alerts.
- **410 handling**: APNS tells you a token is dead. If you don't prune, your
  send volume and error rate creep up forever. Flip `active=false`.
- **Every send is best-effort and off the request path** — see the queue note in 2.4.
- Wrap it so that writing the **in-app inbox row** (`create_notification`) and
  **sending the push** happen together in one helper, e.g. `notify(user_id, ...)`
  → writes the inbox row *and* fires the push. That keeps the two channels in
  sync (the user sees it in the app list *and* got a banner).

### 2.3 Two kinds of triggers

This is the single most important design distinction, and it's how every large
app organizes notifications:

**A. Transactional / event-driven** — fired *inline* when something happens.
These are the high-value ones and should ship **first**. They're just a
`notify(...)` call added to code paths that already exist:
- Someone joins your pod / your pod fills up / a pod forms → `pod_service.py`
- New chat or DM message while you're not in that thread → `chat_service.py`, `dm.py`
- A friend request / accept → `friend_service.py`
- Your mission got a survey / "rate your last mission"
- Pod meeting starts soon (this one is *scheduled*, see below)

**B. Scheduled / batch** — fired by **cron**, not by a user action:
- "Pod meeting in 1 hour" reminders (needs a clock, so it's cron-driven)
- A daily/twice-daily **digest**: "3 new missions match you" using
  `get_suggested_missions()` you already have
- Re-engagement: "you haven't opened Orbit in 5 days, here's something near you"

### 2.4 GCP: cron and why you also want a queue

**Yes — scheduled notifications require a scheduler.** Two options on GCP:

1. **App Engine cron (`cron.yaml`)** — you already use this. Simplest. Add jobs:
   ```yaml
   cron:
     - description: "Pod meeting reminders (T-1h)"
       url: /api/tasks/pod-reminders
       schedule: every 15 minutes
     - description: "Morning mission digest"
       url: /api/tasks/digest
       schedule: every day 09:00
       timezone: America/Los_Angeles
   ```
   Same security model as cleanup: gate each endpoint on
   `request.headers.get('X-Appengine-Cron') == 'true'`.

2. **Cloud Scheduler** — the standalone product (survives if you ever leave App
   Engine, supports finer cron, retries, and can target Pub/Sub or HTTP). If you
   stay on App Engine, `cron.yaml` is enough; reach for Cloud Scheduler when you
   outgrow it.

**The queue problem.** A digest cron that loops over every user and calls APNS
inline will (a) blow the 60s request timeout and (b) retry the *entire* batch if
it fails halfway. The grown-up pattern — and it's already flagged as a Tier 1
item in `future-features.md` ("Cloud Tasks queue for embeddings & deferred
work") — is **fan-out**:

```
cron  ──hits──▶  /api/tasks/digest   (the "planner": decides WHO to notify)
                      │  enqueues one Cloud Task per user (or per 100 users)
                      ▼
              Cloud Tasks queue  ──▶  /api/tasks/send-digest  (the "worker")
                                          builds payload + calls APNS for ONE user
```
Benefits: each unit is tiny and retried independently, you get rate limiting for
free, and a single user's failure doesn't nuke the batch. Transactional pushes
should *also* go through Cloud Tasks so an APNS hiccup never slows the user's
actual request (joining a pod shouldn't wait on Apple's servers).

**Short version:** cron decides *when/who*, Cloud Tasks does the *sending*, APNS
is the *transport*.

### 2.5 The "smart" layer (timing, dedup, preferences)

"Smart notifications" ≠ "send more." It means **send the right thing, once, at a
tolerable time.** Minimum viable smartness:

- **User preferences** — a `NotificationPrefs` kind (or fields on `User`): master
  on/off, plus per-category toggles (chat, pods, digests, marketing). Apple will
  reject/again users churn if you can't turn categories off. Check prefs inside
  `notify()`.
- **Quiet hours** — never push 2am. Hold non-urgent pushes until, say, 9am local.
  This needs the user's timezone (capture it at registration or from the device).
- **Frequency capping** — e.g. "≤1 digest/day, ≤N transactional/hour." Store a
  small per-user counter (Datastore or Memorystore/Redis) and check it in `notify()`.
- **Dedup / collapse** — `collapse_id` on the APNS side; on the server side, don't
  send "new message" for each of 10 messages — debounce to "3 new messages."
- **Don't notify what they're looking at** — if the user is *in* the pod chat,
  the server shouldn't push "new message." Big apps track presence; a cheap proxy
  is "was this user active in the last N seconds" (you already have session/analytics
  signals from `AnalyticsService`).

---

## 3. iOS / client design

### 3.1 Capability & entitlement (Xcode + Apple)

- In Xcode → target → **Signing & Capabilities → + Push Notifications**. This
  adds `aps-environment` to `Orbit.entitlements` (`development` for Xcode builds,
  `production` for TestFlight/App Store — Xcode manages this automatically).
- Optionally add **Background Modes → Remote notifications** if you want silent
  content-available pushes to refresh data (this is what could eventually replace
  the client polling that `future-features.md` M5 complains about).
- No new provisioning headache for the *server*: the `.p8` **APNS Auth Key** is
  already generated (`AuthKey_DSPV6J64KX.p8`, referenced in `app.yaml`). One key
  works for all your apps and never expires. Keep it out of git (it's a secret —
  this ties into the Batch A secret-rotation work in the hardening audit).

### 3.2 Registration flow (client)

```
App launches
   └─ ask permission at the RIGHT moment (not on first launch — see §3.4)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge])
   └─ if granted → UIApplication.shared.registerForRemoteNotifications()
        └─ AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
             └─ hex-encode token → POST /api/notifications/register-token
        └─ didFailToRegister → log, retry next launch
```
`AppDelegate` already exists in `OrbitApp.swift` — you extend it with the two
`didRegister…` callbacks and make it the `UNUserNotificationCenterDelegate`.

### 3.3 Receiving — the three cases

Implement `UNUserNotificationCenterDelegate`:

- **App in background/closed:** iOS shows the banner automatically. When the user
  **taps** it → `didReceive response` fires → read your custom `data` keys
  (`mission_id`, `pod_id`, `deep_link`) and route to that screen. You already have
  deep-link routing in `OrbitApp.swift` (`deepLinkFriendId`) — generalize that
  same mechanism (a routing `@State` / router object) so a tapped push can push
  any screen.

- **App in foreground (channel 2):** by default iOS suppresses the banner. Implement
  `willPresent notification` and return `[.banner, .sound, .badge]` if you *do*
  want a banner over the app, **or** return `[]` and instead show your own in-app
  toast/badge. Most polished apps show a custom in-app banner here so it matches
  the app's look and can be tapped to navigate. This is the "while the person is
  using the app, should they get notifications?" question — **yes**, and it's this
  callback that controls it.

- **In-app inbox (channel 3):** unchanged — keep fetching `/api/notifications`.
  A push and its inbox row are two views of the same event.

### 3.4 When to ask for permission (this matters a lot)

**Do not** call `requestAuthorization` on first launch. iOS only lets you ask
**once** — if they say no, you're done forever (short of sending them to Settings).
The industry-standard pattern:
1. Show a **pre-permission priming screen** ("Get notified when your pod is ready
   to meet") — a soft ask you fully control and can re-show.
2. Only when they tap "Turn on" do you fire the real iOS prompt.
3. Best moment: right after a **completed action** that creates an expectation of
   a reply — e.g. after joining their first pod, or after sending a chat message.
   Acceptance rates roughly double vs. asking cold on launch.

### 3.5 Badges

Server owns the badge number (unread count) and sends it in the `aps.badge`
field, so it's correct even when the app is closed. Clear it when the user opens
the relevant screen (`UIApplication.shared.applicationIconBadgeNumber = 0` or the
newer `setBadgeCount`).

---

## 4. GCP checklist

- [ ] `DeviceToken` kind + `index.yaml` entry (query by `user_id`, filter `active`). You already maintain composite indexes for `Notification` — copy that block.
- [ ] `push_service.py` with the `.p8` key loaded from a **secret** (Secret Manager), *not* a plaintext `app.yaml` env var — folds into Batch A rotation.
- [ ] New cron endpoints in `api/tasks.py` (`/pod-reminders`, `/digest`), each gated on `X-Appengine-Cron`.
- [ ] `cron.yaml` entries for those jobs (with `timezone:`).
- [ ] Cloud Tasks queue for fan-out sending (recommended before any batch/digest job goes live to real user volume).
- [ ] Optional: **Memorystore (Redis)** for frequency-cap counters and presence, if Datastore counters get hot.
- [ ] Observability: log every send + APNS response code; a spike in 410s or 400s is your early warning (ties to the Sentry/Cloud Logging Tier 1 item).

## 5. iOS / TestFlight checklist

- [ ] Add **Push Notifications** capability (writes `aps-environment` to entitlements).
- [ ] (Optional) **Background Modes → Remote notifications** for silent refresh.
- [ ] `UNUserNotificationCenter` registration + `AppDelegate` token callbacks + `POST register-token`.
- [ ] `UNUserNotificationCenterDelegate` for foreground (`willPresent`) and tap (`didReceive`).
- [ ] Priming screen before the real permission prompt.
- [ ] Settings screen with per-category toggles → `NotificationPrefs` endpoint.
- **TestFlight gotcha (important):** TestFlight builds are **signed for production
  APNS** — they use `api.push.apple.com`, *not* the sandbox gateway. So
  `APNS_USE_SANDBOX="false"` in `app.yaml` is correct **for TestFlight**, while a
  build you run from Xcode onto a device is **sandbox** and needs the sandbox
  gateway. This is why per-token `environment` (§2.1) beats a single global flag:
  the same server can serve both your Xcode test phone and TestFlight users at once.
- **Silent pushes are throttled** by iOS (a few per hour, and not at all in Low
  Power Mode) — never rely on them for anything time-critical like a meeting reminder.
  Time-critical → visible alert push.

## 6. How larger companies do it (and what to copy)

- **Transactional vs. scheduled split** (§2.3) is universal. Transactional (a
  reply, a like, a match) is fired inline by the service that owns the event.
  Scheduled/marketing (digests, re-engagement) runs through a separate batch
  pipeline with heavy targeting and frequency caps. **Copy this split now** — it's
  free and keeps the two from stepping on each other.
- **A central Notification Service.** Instead of each service talking to APNS,
  they emit an event ("pod.filled") to one service that owns: user preferences,
  channel selection (push vs. email vs. SMS vs. in-app), quiet hours, frequency
  caps, dedup, localization, and delivery/receipt logging. For Orbit, the
  small-scale version of this is the single `notify()` helper (§2.2) — resist
  scattering raw `send_push` calls across the codebase; route everything through
  one function so prefs/caps are enforced in exactly one place.
- **Fan-out through a queue** (Cloud Tasks / SQS / Kafka). Nobody loops over
  millions of users in a cron request. §2.4.
- **Send-time optimization.** Mature systems learn *per user* when they open pushes
  and schedule delivery into that window (ML model over each user's open history).
  You don't need this on day one — but note that your `AnalyticsService` funnel is
  exactly the training data for it later (it's the Tier 2 "smart timing" item).
- **Frequency capping & a global "notification budget."** Big apps cap total
  notifications/user/day across *all* categories, because over-notifying is the #1
  cause of disable+uninstall. Even a crude cap beats none.
- **Preferences + one-tap unsubscribe**, and honoring OS-level opt-out. Also a
  compliance requirement (App Store) and it's in your `docs/tos.md` orbit.

## 7. Cadence — what should *Orbit* actually send, and how often

Your literal question was "twice a day, on login, etc." Here's the opinionated
answer for a small social/matchmaking app:

**Tier 1 — event-driven, send immediately (ship first).** These are wanted and
self-limiting because they only fire when something real happens:
- Pod formed / pod filled / someone joined your mission
- New chat/DM (debounced + collapsed, and suppressed if you're in that thread)
- Friend request / accepted
- "Your pod meets in 1 hour" (cron-scheduled but user-specific and expected)

**Tier 2 — one scheduled nudge, opt-outable.** A **single daily** mission digest
in the morning (9–10am local) via `get_suggested_missions()` — *only if the user
has ≥1 fresh, well-matched mission*, otherwise skip that day (silence beats a
low-quality push). **Start at once/day, not twice** — twice/day is where uninstalls
begin for an app this size. You can add an evening slot later *if* the data says
opens are high and disables are low.

**Tier 3 — re-engagement, rare.** If a user hasn't opened in ~5–7 days, one
"here's what's happening near you" push. Hard-cap these.

**On login:** don't push *on* login (they're already in the app — that's a
foreground/in-app banner at most). Instead, **register/refresh the device token
on every launch**, and use login as a good *moment to run the priming permission
ask* (after they've done something, per §3.4).

**Rule of thumb:** every push should pass "would the user thank me for
interrupting them right now?" Transactional almost always passes. A generic
"come back!" almost always fails. When unsure, don't send.

---

## 8. Suggested build order

1. **Client registration + `DeviceToken` + `register-token` endpoint.** No sends
   yet — just prove tokens arrive and store. (S)
2. **`push_service.py` + `notify()` helper** and wire **one** transactional event
   (new DM is a good first one — easy to test end-to-end). (M)
3. Roll `notify()` into the rest of the transactional events. (S each)
4. **Foreground handling** (`willPresent`) + tap-to-deep-link routing. (M)
5. **Preferences** kind + settings UI + enforce in `notify()`. (M)
6. **Cron + Cloud Tasks** fan-out, then the **daily digest** and **pod reminders**. (M–L)
7. Later: send-time optimization, silent-push refresh to kill client polling.

Do 1–3 behind the existing secret-rotation (Batch A) since the `.p8` key needs to
move to Secret Manager first.
