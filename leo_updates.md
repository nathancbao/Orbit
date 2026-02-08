# AI Integration Updates — Leo

## Overview

Integrated the Jaccard similarity matching engine from `Orbit_AI_Features/` into both the backend and the iOS app. The discover flow now computes and displays match scores between users based on shared interests.

**Algorithm — Jaccard Similarity:**
```
score = |A ∩ B| / |A ∪ B|
```
Example: User A likes [Hiking, Coffee, Gaming], User B likes [Hiking, Gaming, Music]
→ Shared = 2, Union = 4 → Score = 0.5 (50% match)

---

## Changes

### 1. Backend — Jaccard Similarity in Matching Service

**File:** `OrbitServer/services/matching_service.py`

- `suggested_users()` now uses Jaccard similarity instead of simple interest overlap count
- Each returned profile includes a `match_score` field (float, 0.0–1.0)
- Results are sorted by score descending (best matches first)
- Division-by-zero safe: if both users have no interests, score = 0.0

### 2. iOS — Profile Model Update

**File:** `OrbitApp/Orbit/Models/Profile.swift`

- Added `var matchScore: Double?` with CodingKey `match_score`
- Optional field — only present on profiles returned by the discover endpoint
- All existing code that constructs `Profile` is unaffected (defaults to `nil`)

### 3. iOS — New MatchingService (Client-Side)

**File (new):** `OrbitApp/Orbit/Services/MatchingService.swift`

Adapted from `Orbit_AI_Features/MatchingEngine.swift` to work with the app's `Profile` model and `[String]` interests.

- `computeMatchScore(between:and:)` — Jaccard similarity between two profiles
- `rankProfiles(_:against:)` — sorts profiles by match score; respects backend-provided scores as a fallback

### 4. iOS — DiscoverView UI Updates

**File:** `OrbitApp/Orbit/Views/Discover/DiscoverView.swift`

- `DiscoverView` now accepts a `userProfile` parameter for client-side score computation
- **Planet size scales with match score** — ranges from 60pt (low match) to 90pt (high match)
- **Match percentage badge** on each planet — color-coded green (≥50%), orange (≥25%), gray (<25%)
- **Match score bar** in `ProfileDetailSheet` — shows "X% Match" with a progress bar at the top of the profile detail view

**File:** `OrbitApp/Orbit/Views/MainTabView.swift`

- Passes the user's profile through to `DiscoverView`

---

## Repo Cleanup

Removed stale/duplicate directories that accumulated from team development:

| Removed | Reason |
|---------|--------|
| `Orbit/` | Stale copy of iOS app — `OrbitApp/` is the active one |
| `OrbitApp.xcodeproj` (root) | Old Xcode project — active one is `OrbitApp/Orbit.xcodeproj` |
| `OrbitAppTests/` | Test target for old project |
| `Orbit_Auth/` | Older copies of auth files already in OrbitApp |
| `Orbit_AI_Features/` | Now integrated into OrbitApp via MatchingService.swift |
| `api/`, `models/`, `services/`, `utils/` (root) | Leftover `__pycache__` dirs from pre-OrbitServer reorganization |
| `OrbitApp/ContentView.swift.bak` | Backup file |

---

## What's NOT Integrated Yet

The following features from the original AI folder are **not yet integrated** (per team decision to defer):

- **EventSuggester** — suggests events based on interest tags (waiting on events/missions feature)
- **MLEventRecommender** — online gradient descent model that learns from like/dislike feedback
- **GroupManager** — auto-creates groups from shared interests (waiting on crews/groups feature)
