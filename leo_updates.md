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

## Multi-Signal Compatibility Scoring

**File:** `OrbitApp/Orbit/Features/AI/weights.py`

Replaced the single-signal (interests-only) scoring with a weighted multi-signal compatibility function that uses all profile data we already collect.

**Scoring breakdown:**

| Signal | Weight | Method |
|--------|--------|--------|
| Interests | 30% | Jaccard similarity (`\|A ∩ B\| / \|A ∪ B\|`) |
| Personality | 30% | Inverted normalized Euclidean distance across the 3 trait sliders (`introvert_extrovert`, `spontaneous_planner`, `active_relaxed`) |
| Social Preferences | 20% | Average of: ordinal distance for group size, ordinal distance for meeting frequency, Jaccard overlap on preferred times |
| Friendship Goals | 20% | Jaccard similarity on goal lists |

- `compatibility(profile_a, profile_b)` now takes two full profile dicts and returns a 0–1 score
- Gracefully handles missing/sparse profiles by falling back to neutral defaults
- Removed the old `Level` enum and hardcoded personality stub

---

## Dynamic Compatibility Weights via Vibe Check Quiz

**File:** `OrbitApp/Orbit/Features/AI/compatibility.py`

The four compatibility weights were previously hardcoded at 0.30/0.30/0.20/0.20. The personality score only compared 3 basic slider traits, ignoring the 8-dimension Vibe Check quiz data entirely. This meant two users who both took the 22-question quiz got the same shallow personality comparison as users who skipped it.

### What Changed

**Conviction score** (`_conviction`): New helper that measures how far from neutral (0.5) a user's quiz answers are across all 8 dimensions. A user who answers strongly (values near 0 or 1) gets a high conviction; someone who answers all-neutral gets ~0.

**Dynamic weight interpolation** (`_get_weights`): When both users have quiz data, the average conviction of both users blends between base and boosted weight tables:

| Category    | Base (no quiz) | Boosted (decisive quiz answers) |
|-------------|----------------|----------------------------------|
| Personality | 0.30           | up to 0.40                       |
| Interest    | 0.30           | down to 0.25                     |
| Social      | 0.20           | 0.20                             |
| Goals       | 0.20           | down to 0.15                     |

If either user hasn't taken the quiz, the original base weights are used unchanged.

**8-dimension personality scoring**: `personality_score` now accepts optional `vibe_check_a`/`vibe_check_b` params. When both are present it compares all 8 quiz dimensions (`introvert_extrovert`, `spontaneous_planner`, `active_relaxed`, `adventurous_cautious`, `expressive_reserved`, `independent_collaborative`, `sensing_intuition`, `thinking_feeling`) instead of only the 3 basic slider traits. Uses the same inverted normalized Euclidean distance method, just with `sqrt(8)` as the max distance instead of `sqrt(3)`.

### Reasoning

- Users who invest time in the quiz should get better matches from it — the extra data should actually improve their score accuracy.
- The weight shift is gradual, not a hard switch. Two users with wishy-washy neutral quiz answers get almost no weight change. Two users with strong, decisive answers get the full personality boost.
- Backward compatible: no behavior change for users without quiz data.

---

## Profile Edit Bug Fixes

### 1. Fix 400 Error When Saving Edited Profile

**File:** `OrbitApp/Orbit/ViewModels/ProfileViewModel.swift`

When editing an existing profile, the Vibe Check quiz data was being silently dropped on save. The `buildProfile()` method only included `vibeCheck` if `isVibeCheckComplete` was true — which checks that all 22 `quizAnswers` are filled. But in edit mode, only the computed results (`vibeCheckPersonality` dictionary and `derivedMBTI`) are loaded from the existing profile; `quizAnswers` stays empty since the user isn't retaking the quiz.

This meant the PUT request sent `vibe_check: null` for a user who previously had quiz data, likely causing the server's 400 response.

**Fix:** Changed the condition in `buildProfile()` to also accept pre-loaded vibe check data:
```swift
// Before
if isVibeCheckComplete && !derivedMBTI.isEmpty {
// After
if (isVibeCheckComplete || !vibeCheckPersonality.isEmpty) && !derivedMBTI.isEmpty {
```

### 2. Add Cancel Button to Profile Edit Screen

**Files:** `OrbitApp/Orbit/Views/Profile/ProfileSetupView.swift`, `OrbitApp/Orbit/ContentView.swift`

Previously, tapping "Edit" on the profile set `appState = .profileSetup` with no way to return without completing all 6 steps again. Users who accidentally tapped Edit were stuck.

- Added `onCancel` callback and `isEditMode` flag to `ProfileSetupView`
- When in edit mode, an "X Cancel" button appears at the top of the screen
- `ContentView` passes an `onCancel` handler that returns to `.home` state
- New users (no existing profile) don't see the cancel button — they must complete setup

---

## Demo Flow: Skip Survey → See Scores → Take Survey → See Scores Change

Added the ability to skip the Vibe Check quiz during onboarding, then take it later from the Profile tab to demonstrate how personality data improves match scores.

### 1. Skippable Vibe Check During Onboarding

**Files:** `OrbitApp/Orbit/Features/PersonalityQuiz/Views/VibeCheckView.swift`, `OrbitApp/Orbit/Views/Profile/ProfileSetupView.swift`, `OrbitApp/Orbit/ViewModels/ProfileViewModel.swift`

- Added `onSkip` callback and "Skip for Now" button (top-right) to `VibeCheckView`
- Added `vibeCheckSkipped` flag to `ProfileViewModel`
- Step 2 validation now passes if quiz is complete **or** skipped
- Skip callback auto-advances to the Interests step

### 2. Weighted Blend Matching (Interests + Personality)

**File:** `OrbitApp/Orbit/Services/MatchingService.swift`

Previously the client-side `MatchingService` only used Jaccard similarity on interests. Now uses a weighted blend:

| Signal | Weight | Method |
|--------|--------|--------|
| Interests | 60% | Jaccard similarity (unchanged) |
| Personality | 40% | 1 − avg absolute difference across all 8 vibe check dimensions |

When either user lacks vibe check data (e.g. they skipped the quiz), falls back to 100% interest-only matching. This means taking the quiz **visibly shifts** the compatibility percentages — exactly what we need for the demo.

### 3. "Take Vibe Check" Banner on Profile Tab

**Files:** `OrbitApp/Orbit/Views/Profile/ProfileDisplayView.swift`, `OrbitApp/Orbit/Views/MainTabView.swift`, `OrbitApp/Orbit/ContentView.swift`

- When `profile.vibeCheck == nil`, a styled banner appears on the Profile tab: "Take the Vibe Check — Unlock personality-based matching"
- Tapping it opens the full 22-question quiz as a fullscreen cover
- After completion, the "Done" button saves the updated profile to the server and updates `completedProfile` in `ContentView`
- Since `completedProfile` is `@State` on `ContentView`, changing it recreates `MainTabView` → `DiscoverView` re-runs `.task` → `rankProfiles()` recomputes scores with the new personality data
- The banner disappears once vibe check data exists

### Demo Script

1. Create new user → fill basic info, personality sliders
2. At Vibe Check → tap **"Skip for Now"** → continue with interests, preferences, photos
3. Go to **Discover tab** → see compatibility % (interest-only, 100% weight)
4. Go to **Profile tab** → tap **"Take the Vibe Check"** banner → complete the 22 questions
5. Return to **Discover tab** → scores have changed (now 60% interests + 40% personality blend)

---

## What's NOT Integrated Yet

The following features from the original AI folder are **not yet integrated** (per team decision to defer):

- **EventSuggester** — suggests events based on interest tags (waiting on events/missions feature)
- **MLEventRecommender** — online gradient descent model that learns from like/dislike feedback
- **GroupManager** — auto-creates groups from shared interests (waiting on crews/groups feature)
