● All 312 pass. The incremental-fetch change is done and verified. Here's the summary, then your architecture question.

  What I changed (server + client)

  Server — incremental fetch at the shared layer (benefits both pod and DM chat):
  - models.py → list_chat_messages(pod_id, limit=100, since=None) — adds a created_at > filter when since is given. Covered by your existing ChatMessage(pod_id + 
  created_at) index, so no index.yaml change.
  - chat_service.py → new _parse_since() helper (parses the ISO created_at cursor → naive UTC datetime, falls back to full fetch on bad input); get_messages and  
  get_dm_messages accept since.
  - chat.py / dm.py → both GET endpoints read ?since= from the query string.

  Client (Swift):
  - ChatService → getMessages/getDMMessages take an optional URL-encoded since.
  - DMChatViewModel → polling now calls a new poll() that sends the latest message's createdAt as since, then appends + dedupes by id instead of replacing the    
  whole array. Interval relaxed 3s → 5s.

  Effect: an idle DM poll now returns 0 rows ≈ 1 Datastore read instead of up to 100. That's the ~99% reduction — chat goes from the dominant line item to        
  negligible. (Pod chat already loaded once per open, but now also fetches lean if you ever add polling there.)

  One thing I did not change: each DM poll still does a find_friendship read for the membership check. That's 1 read/poll — fine, but tell me if you want it      
  cached.

  ---
  Is Datastore the right store for chat messages?

  For your scale (hundreds of DAU): yes, keep it. Datastore is fine for chat and the incremental fetch removes the cost problem. Don't migrate — it'd be effort   
  for no benefit at this size. But here's the honest picture of the trade-offs and the cheaper/faster levers:

  Where Datastore is weak for chat specifically:
  - Cost model is per-operation, not per-byte. Storage is dirt cheap ($0.18/GB/mo — a million text messages is maybe 100–200 MB ≈ pennies). Your cost was never   
  storage; it was reads. So "reduce storage to save money" isn't the lever — reducing reads is, which we just did.
  - No native real-time push. Datastore can't notify clients of new messages, which is why you poll. Polling is the root inefficiency.

  Cheaper/faster options, roughly in order of effort vs. payoff:

  1. Use APNs push you already have configured (best bang for buck). Push a silent/visible notification on new message; only poll while the chat is foregrounded, 
  and stop polling on background. This kills idle polling almost entirely. Low effort, big win — recommended next step.
  2. Cloud Firestore (native mode, not Datastore mode) — this is the "purpose-built for chat" answer. It has real-time listeners: clients subscribe and get pushed
   only new docs, no polling at all. Same Google project, similar pricing, but billing is still per-read so the listener model is what saves you. Downside: it's a
   meaningful rewrite (different SDK on both server and iOS) and you'd run it alongside Datastore. Worth it only if chat becomes a core, high-volume feature.     
  3. Memorystore (Redis) for recent messages — keep the last N messages of each active pod in Redis, fall back to Datastore for history. Very fast, cheap reads.  
  But Memorystore has a fixed ~$35/mo+ minimum instance cost, so it only pays off at real scale — not yet.
  4. Message storage hygiene (minor): content is already exclude_from_indexes (good — saves index writes). If you ever want to cut storage/old-message reads, add 
  a TTL policy to auto-delete messages older than X months. Negligible savings now, but free housekeeping.

  My recommendation: stay on Datastore, and when you want the next improvement, do #1 (APNs-driven polling) — it's low-effort, uses infrastructure you've already 
  set up, and eliminates most of the remaining polling. Save Firestore (#2) for if/when chat volume justifies a real-time rewrite.

  Want me to wire up the APNs-on-new-message + foreground-only polling next, or leave it here?

*claude --resume f49bb60d-b716-4d9a-86ea-c36f85c585a1*

I dug into the actual code, and the answer has a twist: for 300 daily users the instance setup is fine — but instances won't be your main cost. Chat polling 
  will be, and it's worth fixing before you call this "prod."

  What I found

  Your chat client polls every 3 seconds while a chat is open (DMChatViewModel.swift:48). Each poll calls GET /api/pods/<id>/messages, which runs:

  list_chat_messages(pod_id, limit=100)   # models.py:385 — fetches up to 100 entities

  There's no since/cursor param and no cache — so every poll re-reads the entire message list (up to 100 ChatMessage entities) from Datastore. In
  Datastore/Firestore, a query that returns N entities bills as N reads. That's the cost engine, and it scales with how many chats are open, not with your        
  instance class.

  Cost breakdown for ~300 DAU

  Datastore (Firestore mode) pricing: $0.06 per 100k reads, with 50k reads/day free.

  ┌─────────────────────────────────────────────┬────────────────────────────────────────────────────────────────┬──────────────┐
  │                 Cost source                 │                             Driver                             │ Est. monthly │
  ├─────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┼──────────────┤
  │ Chat-poll Datastore reads                   │ open chats × 20 polls/min × messages/poll                      │ ~$30–200 ⚠️  │
  ├─────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┼──────────────┤
  │ Instance-hours (F2)                         │ polling keeps ~1 instance warm ~14h/day; scales to 0 overnight │ ~$5–15       │
  ├─────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┼──────────────┤
  │ Datastore writes (messages, votes, RSVPs)   │ low volume                                                     │ ~$1–5        │
  ├─────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┼──────────────┤
  │ Network egress (full message list every 3s) │ inflated by polling                                            │ ~$3–8        │
  ├─────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┼──────────────┤
  │ Cloud Storage (photos)                      │ small                                                          │ ~$1–3        │
  └─────────────────────────────────────────────┴────────────────────────────────────────────────────────────────┴──────────────┘

  The chat-read range is wide because it depends on two things I had to assume:
  - Concurrent open chats (I used ~10–30 at peak)
  - Messages per pod (I used 10–50; capped at 100)

  To make it concrete: 10 open chats averaging 30 messages each, over 14 active hours ≈ 5M reads/day ≈ ~$90/month — just for chat polling. Bump activity up and it
   climbs past $200. The instance class change we made (F4→F2) saves a few dollars; this dwarfs it.

  Will the current setup support 300 DAU? — Capacity: yes, easily

  - 300 DAU generates only a few requests/sec, even at peak. Chat polling at ~30 concurrent open chats ≈ 10 req/s, each ~50–100ms = roughly 1 request in flight.  
  - Your capacity is ~2 workers × 4 threads × up to 3 instances ≈ 24 concurrent requests. You're nowhere near it. max_instances: 3 is plenty for 300 DAU.

  So it'll run fine. The issue is purely that the polling design makes it cost more than it should and the cost grows linearly with engagement — exactly backwards
   from what you want in prod.

  The high-impact fix (≈99% cheaper chat)

  Add incremental fetching so a poll only returns new messages:

  1. Server: accept ?since=<timestamp or message_id> on GET .../messages, add a created_at > filter. Idle polls then return 0 rows ≈ 1 read each instead of up    
  to 100.
  2. Client: track the last message timestamp, send it as since, append results.
  3. Cheap extras: raise the poll interval 3s → 5–8s, and stopPolling() when the app backgrounds (you already have stopPolling).
  4. Best long-term: you already have APNs configured — push a notification on new message and only poll while the chat is actively foregrounded. Eliminates idle 
  polling entirely.

  That combination would take the chat line from ~$30–200/mo down to a few dollars, making total prod cost for 300 DAU realistically ~$10–25/month.