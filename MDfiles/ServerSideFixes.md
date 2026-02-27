# Server-Side Fixes — February 27, 2026

## Overview

Full audit of the OrbitServer Python/Flask backend. Found and fixed 6 bugs across 8 files, including race conditions, crash-causing type errors, and broken UI state.

---

## 1. Race Conditions (P1)

### The Problem

Multiple endpoints used a **read-modify-write** pattern on shared Datastore entities without any atomicity guarantees. When two requests hit the server at the same time, they could both read the same state, make their own changes, and then the last write would silently overwrite the first.

**Example — two users joining a pod simultaneously:**

```
Request A                          Request B
─────────────────────────────────────────────────────
Find pod with 3/4 members
                                   Find pod with 3/4 members
Read member_ids = [1,2,3]
                                   Read member_ids = [1,2,3]
Append user 4 → [1,2,3,4]
                                   Append user 5 → [1,2,3,5]
Save [1,2,3,4]
                                   Save [1,2,3,5]  ← overwrites!

Result: User 4 thinks they joined but got silently dropped.
```

### Where It Existed

| Operation | File | What could be lost |
|-----------|------|--------------------|
| `join_event` | `pod_service.py` | A user's pod membership |
| `leave_event` | `pod_service.py` | Another user's concurrent join |
| `vote_to_kick` | `pod_service.py` | A kick vote |
| `confirm_attendance` | `pod_service.py` | An attendance confirmation |
| `adjust_trust_score` | `models/models.py` | A trust score delta (+0.5 or -0.2) |
| `respond_to_vote` | `chat_service.py` | A user's vote response |

### The Fix

**Datastore transactions.** We added two transactional helper functions to `models.py`:

```python
def transactional_pod_update(pod_id, update_fn):
    """Atomically read-modify-write an EventPod."""
    with client.transaction():
        key = client.key('EventPod', str(pod_id))
        entity = client.get(key)
        if not entity:
            return None, None
        result = update_fn(entity)
        client.put(entity)
        return result, _entity_to_dict(entity)

def transactional_vote_update(vote_id, update_fn):
    """Atomically read-modify-write a Vote."""
    with client.transaction():
        key = client.key('Vote', str(vote_id))
        entity = client.get(key)
        if not entity:
            return None, None
        result = update_fn(entity)
        client.put(entity)
        return result, _entity_to_dict(entity)
```

Each service function now passes a closure that mutates the entity in place. The transaction guarantees that if another write happens between the read and the put, the transaction retries automatically.

`adjust_trust_score` was also wrapped in `with client.transaction():` directly.

### How `join_event` works now

```python
def _add_member(entity):
    member_ids = list(entity.get('member_ids') or [])
    if int(user_id) in member_ids:
        return 'already_joined'
    if len(member_ids) >= max_pod_size:
        return 'full'           # pod filled since our check — caller creates a new pod
    member_ids.append(int(user_id))
    entity['member_ids'] = member_ids
    entity['status'] = 'full' if len(member_ids) >= max_pod_size else 'open'
    return 'joined'

result, pod = transactional_pod_update(pod['id'], _add_member)
if result == 'full':
    pod = create_event_pod(event_id, max_size=max_pod_size, first_member_id=user_id)
```

---

## 2. Other Bugs Fixed

### `_annotate_pod_status` — new events show "pod_full" (P0)

**File:** `api/events.py`

When an event had zero pods (nobody joined yet), the old code reported `user_pod_status = "pod_full"` to Swift because `any(...)` over an empty list is `False`. But joining is totally possible since `join_event()` creates a new pod on demand.

**Fix:** `has_room = not pods or any(...)` — no pods means joinable.

### `verify_code` datetime crash (P0)

**File:** `services/auth_service.py`

`get_verification_code()` runs through `_entity_to_dict()` which converts `expires_at` from a `datetime` object to an ISO string like `"2026-02-27T12:00:00Z"`. Then the code did `if now > expires_at` — comparing a `datetime` to a `str`, which raises `TypeError` in Python 3. This was masked because demo code `"123456"` always bypasses verification.

**Fix:** Parse the string back to datetime before comparing:
```python
if isinstance(expires_at, str):
    expires_at = datetime.datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
```

### Behavioral decay `created_at` crash (P1)

**File:** `services/ai_suggestion_service.py`

Same root cause as above. `_decay_weight()` does datetime arithmetic on `created_at`, but after going through `_entity_to_dict()` it's a string. `datetime - str` crashes silently and the entire behavioral decay signal was always 0.0.

**Fix:** Parse ISO string back to datetime at the top of `_decay_weight()`.

### Stale embeddings on event update (P2)

**File:** `services/event_service.py`

When an event's title, description, or tags were updated, the old embedding stayed cached in memory and in Datastore. The recommendation engine would score the event based on outdated content.

**Fix:** `edit_event()` now calls `invalidate_cache(event_id)`, clears the Datastore embedding, and spawns a background thread to regenerate.

### Photo upload inaccessible (P2)

**File:** `services/storage_service.py`

`blob.make_public()` was commented out but the code returned a public GCS URL. The URL would 403 since the blob was private.

**Fix:** Uncommented `blob.make_public()`.

---

## Files Changed

| File | What changed |
|------|-------------|
| `OrbitServer/api/events.py` | Pod status annotation fix |
| `OrbitServer/models/models.py` | `transactional_pod_update`, `transactional_vote_update`, transactional `adjust_trust_score` |
| `OrbitServer/services/pod_service.py` | All pod mutations now use transactions |
| `OrbitServer/services/chat_service.py` | Vote response now uses transaction |
| `OrbitServer/services/auth_service.py` | `expires_at` string-to-datetime parsing |
| `OrbitServer/services/ai_suggestion_service.py` | `created_at` string-to-datetime parsing |
| `OrbitServer/services/event_service.py` | Embedding invalidation on event update |
| `OrbitServer/services/storage_service.py` | Uncommented `make_public()` |

---

## Future Prevention — How to Avoid Race Conditions

### Rule of Thumb

**Any time you read a value, modify it, and write it back — you need a transaction.** This applies to:
- Appending to a list (member_ids, confirmed_attendees, voters)
- Incrementing/decrementing a counter (trust_score, vote counts)
- Conditional updates ("add if not already present", "remove if exists")

### Patterns to Watch For

```python
# DANGEROUS — read-modify-write without transaction
entity = client.get(key)
entity['list_field'].append(new_item)
client.put(entity)

# SAFE — wrapped in transaction
with client.transaction():
    entity = client.get(key)
    entity['list_field'].append(new_item)
    client.put(entity)
```

### When Writing New Endpoints

1. **Ask: "Does this endpoint modify a shared entity?"** If yes, use a transaction.
2. **Ask: "Could two users trigger this at the same time?"** Pod joins, votes, and chat are all concurrent by nature.
3. **Use the helper functions.** `transactional_pod_update(pod_id, update_fn)` and `transactional_vote_update(vote_id, update_fn)` handle the boilerplate. Just pass a closure that mutates the entity.
4. **Keep transactions short.** Don't do API calls, file I/O, or slow work inside a `with client.transaction():` block. Read, mutate, write — that's it.
5. **Handle contention gracefully.** If a transaction fails because the entity changed, Datastore retries automatically (up to a limit). For very hot entities, consider a queue-based approach instead.

### The `_entity_to_dict` / `_deep_convert` Gotcha

Any value that goes through `_entity_to_dict()` has its datetimes converted to ISO strings. If you later need to do math on those values (comparisons, timedelta arithmetic), you must parse them back first. When in doubt, work with raw Datastore entities inside service functions rather than the converted dicts.
