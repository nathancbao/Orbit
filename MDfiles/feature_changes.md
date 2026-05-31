# Orbit — Feature & Data Map

This doc inventories every data structure in Orbit, the screens that use them, and the visible parts of each screen — including elements that **don't yet have a real data source** (placeholders, hardcoded strings, or local-only state). Use it as a checklist when wiring features end-to-end, or as the source-of-truth when updating the README.

> Legend
> - 🟢 **Wired** — pulls from backend / persisted store
> - 🟡 **Local-only** — exists in client state but not in any datastore yet
> - 🔴 **Placeholder** — shown in UI but no backing data at all (e.g. literal `{Age}`)
> - 📷 *image slot* — leave space for screenshot when added

---

## 1. Data Structures (Models)

### 1.1 `Profile` — `Models/Profile.swift`
| Field | Type | Status | Backing |
|---|---|---|---|
| `name` | String | 🟢 | `User.name` (Datastore) |
| `collegeYear` | String (freshman / sophomore / junior / senior / grad) | 🟢 | `User.college_year` |
| `interests` | [String] (3–10 tags) | 🟢 | `User.interests` |
| `photo` | String? (URL) | 🟢 | `User.photo` (Cloud Storage) |
| `trustScore` | Double? (0.0–5.0) | 🟢 | `User.trust_score` (server-computed via survey upvotes) |
| `email` | String? (.edu) | 🟢 | `User.email` |
| `galleryPhotos` | [String] (URLs, up to 6) | 🟢 | `User.gallery_photos` |
| `bio` | String (≤250 chars) | 🟢 | `User.bio` |
| `links` | [String] (URLs, up to 3) | 🟢 | `User.links` |
| `gender` | String (male / female / non-binary / other) | 🟢 | `User.gender` |
| `mbti` | String (16-type) | 🟢 | `User.mbti` |
| `matchScore` | Double? | 🟢 | computed per-discover-call, not persisted on Profile |
| **age** | — | 🔴 | shown as literal `"{Age} Years Old"` on `ProfileDisplayView` — no birthdate column exists |
| **astral mascot** | — | 🔴 | the colored-star badge over the avatar is hardcoded `Image("coloredStar")`; mascot/avatar variation is a future feature |
| **habits sentence** | — | 🔴 | the "prefers larger group settings, in the morning" sentence in `habitsSentence` is hardcoded copy; habit inference is a planned feature |

### 1.2 `User` — `Models/User.swift`
Light wrapper used for the auth response. Contains `id`, `phoneNumber` (legacy — auth is now email), `profileComplete`, `createdAt`, optional embedded `Profile`. Notable: the field is still named `phoneNumber` but is **never written** by the current email auth flow — candidate for removal.

### 1.3 `Mission` — `Models/Event.swift` (file misnamed, struct is `Mission`)
The unified activity entity. Same struct represents both **Set** (fixed date/time) and **Flex** (group picks time) modes via the `mode` discriminator.

**Shared fields:**
- `id`, `title`, `description`, `tags`, `location`
- `creatorId`, `creatorType` (`user` | `seeded` | `ai_suggested`)
- `maxPodSize` (default 4)
- `status` (`open` | `completed` | `cancelled` | `pending` | `active`)
- `matchScore`, `suggestionReason` (AI recommendation fields)
- `userPodStatus` (`not_joined` | `in_pod` | `pod_full`), `userPodId`, `pods` — server-annotated for the requesting user
- `mode` (`set` | `flex`)

**Set-mode fields:** `date` (YYYY-MM-DD), `startTime`, `endTime` (HH:mm)

**Flex-mode fields:** `logo` (SF Symbol), `customActivityName`, `minGroupSize`, `availability` ([AvailabilitySlot]), `timeRangeStart`/`timeRangeEnd`, `links`, `signalStatus` (`pending` | `active`), `podId`, `scheduledTime`, `createdAt`, `utcOffset`

Backend stores Set as `Mission` kind and Flex as `Signal` kind — `Mission.fromSignal()` converts.

#### *NEW CHANGE* - Set and Flex distinction dissapearing

The difference will be whether a mission is still being scheduled (before a group vote on a specific time), or if it already is (time and date given)

During the mission creation page, you can either give it a time and place, or give it some days and time slots that work for you as the pod leader.

Thus when showing up in the missions page and the discovery page, you either see a calendar signal, saying theres a specific time and date, or slots that people have filled,

### 1.4 `Signal` — `Models/Signal.swift`
Internal decoding model for backend Flex entities. Carries everything `Mission` flex-mode does, plus `activityCategory` (the legacy enum: Sports, Food, Movies, Hangout, Study, Custom). New flex missions use `logo` (SF Symbol) instead; `activityCategory` is being phased out but is still required by the backend Signal schema.

### 1.5 `AvailabilitySlot` (in Signal.swift) & `TimeBlock`
Per-day availability container. Has two formats:
- **Legacy:** `timeBlocks: [TimeBlock]` (morning / afternoon / evening) — still decoded for old missions
- **Current:** `hours: [Int]` (24h integers) — what new flex creations write

`isHourly` discriminates which format is in use.

### 1.6 `Pod` / `PodMember` / `PodSummary` / `MemberPreview` / `PodScheduleData` — `Models/EventPod.swift`
The group formed around a mission/signal.

- `Pod` — full pod with `members`, `scheduleData` (when2meet entries), `confirmedAttendees`, `kickVotes`, `surveyCompletedBy`, `hasPendingSurvey`, etc.
- `PodSummary` — lightweight (`podId`, `memberCount`, `maxSize`, `status`, `memberPreviews`) used in mission cards
- `MemberPreview` — `userId`, `name`, `photo` (used for the overlapping-avatar stacks)
- `PodMember` — enriched member with `collegeYear`, `interests`
- 🟡 `confirmedTime`, `scheduleDeadline`, `leaderPickDeadline` — local-only fields on Pod, never decoded from API. TODO: migrate to backend.

### 1.7 `ScheduleGrid` — `Models/ScheduleGrid.swift`

When2meet-style scheduling structures for flex pods.

- `MemberColor` — 8 colors (pink, purple, blue, teal, orange, green, yellow, red) assigned **deterministically by join order**
- `FlexPodPhase` — enum state machine: `.forming` (1–2 members) → `.locked(hasOverlap)` (3+) → `.leaderPicking` / `.noOverlapCountdown` → `.scheduled` / `.dissolved`
- `TimeSlot` — single 1-hour slot (date + 9–21 hour); equality is calendar-day based
- `ScheduleEntry` — one member's selected slots + color + name
- `ScheduleGrid` — container with 10-day × 13-hour window. Methods: `overlapSlots()`, `nearOverlapSlots()`, `members(for:)`, `memberCount(for:)`.

### 1.8 `ChatMessage` & `Vote` — `Models/ChatMessage.swift`
- `ChatMessage` — pod chat or DM. `messageType`: `text` | `vote_created` | `vote_result` | `system`. DMs reuse the same entity with `podId = "dm_<a>_<b>"`.
- `Vote` — in-pod poll for time/place. `options: [String]`, `votes: {user_id_string → option_index}`, `status: open | closed`, `result: String?`.

#### *NEW CHANGE* - Allow up to 5 pinned messages, similar to Discord pinned messages

This can be set by any pod member, not just the pod leader



### 1.9 `FriendRequest` / `Friendship` / `FriendProfile` / `FriendStatus` — `Models/Friendship.swift`
- `FriendRequest` — pending/accepted/declined direction request, enriched with `fromUser`/`toUser` profiles
- `Friendship` — accepted bidirectional link (one entity per direction in datastore)
- `FriendProfile` — lightweight profile shown in friend rows (name, year, interests, photo, bio)
- `FriendStatus` — relationship check result: `none` | `pending_sent` | `pending_received` | `friends`

### 1.10 `PodInvite` / `PodInviteUser` — `Models/PodInvite.swift`
Invite to join a specific pod (from inside that pod's member-add flow). Status `pending` | `accepted` | `declined`. Shown in the Friends inbox.

### 1.11 `APIResponse<T>` / `AuthResponseData` / `ProfileResponseData` — `Models/APIResponse.swift`
Generic API envelope (`success`, `data`, `error`) and the auth/profile response payloads.

### 1.12 `VoyageTile` / `VoyageItem` (defined in `Services/VoyageService.swift`)
Server-deterministic cluster on the infinite voyage grid. Each tile has `x`, `y` coordinates and an `items` array (missions + signals scattered with seeded shuffling so every user sees the same layout).

---

## 2. Pages / Screens

### 2.1 Auth Flow — `Views/Auth/`
📷 *image slot — auth flow*

- **`LaunchView`** — splash with logo + start button
- **`AuthFlowView`** — controls the two-step flow:
  - **Email entry** — `.edu` email TextField, graduation cap icon, wavy-lines decoration, gradient arrow button. Pulls validation from `AuthViewModel.isEmailValid`.
  - **Verification** — 6-digit code TextField, envelope icon, "Change Email" button.
- **Data in/out:** writes `accessToken`, `refreshToken`, `orbit_user_id`, `orbit_user_name` to UserDefaults; calls `/auth/send-code` and `/auth/verify-code`.
- 🟡 The `PhoneEntryView.swift` and `VerificationView.swift` files exist but are stubs (15 lines each) — leftovers from when auth was SMS-based.

### 2.2 Quick Profile Setup — `Views/Profile/QuickProfileSetupView.swift`
📷 *image slot — profile setup*

Single-screen onboarding (also reused as Edit Profile).
- **Photo picker** — circle avatar, `PhotosUI` picker
- **Name** TextField
- **College year** picker (5 options)
- **Interests grid** — 20 preset tags + custom-tag TextField; 3–10 required (`Constants.Validation`)
- **Bio** TextField with 250-char counter
- **Gender** picker (4 options) → `Profile.gender`
- **MBTI** picker — 4 groups (Analysts, Diplomats, Sentinels, Explorers) × 4 types each → `Profile.mbti`
- **Links** — 3 URL fields
- **Gallery** — up to 6 photos, supports add + delete
- **Account permanence disclaimer** — copy explaining the .edu email tie
- **Delete Account** button (own profile only)
- *NEW CHANGE* - add a birthday field to calculate age

### 2.3 Profile Display — `Views/Profile/ProfileDisplayView.swift`
📷 *image slot — own profile and other-user profile*

Shows either your own profile or another user's (when `otherUserId` is passed).

**Top section:**
- Name (title)
- Gender label (subtitle, gradient text) — hidden if empty
- 150pt circular avatar with `coloredStar` badge mascot (🔴 mascot is hardcoded placeholder)
- Grade level (e.g. "Junior") in gradient
- 🔴 `"{Age} Years Old"` — literal placeholder, no birthdate field exists UNTILL *NEW CHANGE* is made

**Body sections (all conditional on data):**
- **Add Friend / Friends / Request Sent / Accept Request** button (only on other-user profile, via `FriendActionButton`)
- Bio (centered, semibold)
- **Interests** — grid of capsule chips with outlined stroke
- 🔴 **Habits sentence** — `"<First> prefers larger group settings, in the morning"` — hardcoded template, habits inference not built
- **Gallery** — `TabView` carousel with page indicator ("1/3")
- **Links** — list of tappable URLs
- **Log Out** button (own profile only, red gradient)

**Toolbar:**
- Close button (X)
- Edit (own) → opens `QuickProfileSetupView` with `initialProfile` filled
- Ellipsis menu (other-user) → Block / Report → 🔴 both stub-out with "Coming Soon" alert

*NEW CHANGE* - anything related to trust score will NOT be available to the user

- the trust score is only available to the admin, so ideally, it shouldnt even be pulled anywhere in the backend

### 2.4 Main Tab Bar — `Views/MainTabView.swift`
📷 *image slot — tab bar*

4 tabs, ZStack keeps every view alive so state persists across switches:
- **Discovery** — `safari` icon
- **Missions** — `flag` icon
- **Pods** — `hexagon` icon (red badge with unread pod chat count)
- **Friends** — `person.2` icon (red badge with unread DM count)

Custom tab bar (not SwiftUI's `TabView`) with filled-on-select state. Unread badges driven by `Notification.Name.unreadDMCountChanged` / `unreadPodCountChanged`.

### 2.5 Discovery (Galaxy / Landing) — `Views/Discovery/DiscoveryView.swift`
📷 *image slot — discovery view*

The flagship galaxy view. User profile at center, activities orbit as planets on priority rings.

**Layout & background:**
- `DiscoveryTheme.background` (#F8F9FC) full bleed
- Radial glow centered on user node
- `SquiggleDecorationView` — 2 decorative squiggle PNGs at low opacity
- `ImageStarFieldView` — 14–18 drifting black-star images, each with twinkle (sin animation), velocity drift, screen wrap
- `CometView` — single comet PNG streaks across every 12–25s
- `ConnectorLinesView` — dashed lines from center to each planet (color-matched per planet)

**Center node — `CenterNodeView`:**
- 90pt circle with user photo (or person.fill placeholder)
- Pulsating outer glow (scale 1.0↔1.15 over 2s)
- Slowly rotating angular-gradient ring
- Username label below

**Planet nodes — `PlanetNodeView`:**
Each activity planet shows:
- **Title** — mission title (or `displayTitle` for flex)
- **Subtitle** — `displayDate` (set) or "flex mission" (flex)
- **Activity icon** — SF Symbol from `Mission.logo` (creator's choice). Renders nothing if `logo == nil`.
- **Accent color** — picked from `DiscoveryTheme.missionColors` / `flexColors` / `templateColor` by `index % palette` (🟢 this is the "random/arbitrary color" you mentioned — actually deterministic by index in the priority ring, but reads as arbitrary)
- **State ring:**
  - 🟢 `hasScheduledTime` → rotating Saturn ring (tilted ellipse, 6s rotation)
  - 🟢 `isScheduling` (flex with no `scheduledTime` yet) → pulsating ring (1.2s repeat, opacity fades as it grows)
  - `isTemplate` → dashed-outline ring
- **Planet body** — radial-gradient sphere with shading layers (specular highlight, shadow side, atmospheric bands) for a 3D feel
- **Selection haze** — extra radial glow when tapped once
- 🔴 **"You created this" symbol** — *not present yet.* You mentioned this as a desired feature. Right now nothing on the planet indicates `mission.creatorId == currentUserId`. The data exists (`mission.creatorId` and `UserDefaults` `orbit_user_id`), it just isn't rendered. The hosted-mission category already places it on the innermost ring (priority 0), so the data is one comparison away.

**Priority rings (radius as fraction of half-screen):**
- 0 = hosted (you created it) — inner ring (0.42)
- 1 = joined — second ring (0.58)
- 2 = AI-recommended — third ring (0.70)
- 3 = discoverable / template — outer ring (0.82)
Max 7 planets shown; oval layout (vertical stretch 1.2); placement uses 3-phase collision avoidance.

**Planet tap:** first tap selects (haze + scale up, info label appears), second tap opens `MissionDetailView` (or `MissionCreateView` if template).

**Selected info card — `PlanetInfoLabel`:**
- Title (caption, semibold)
- Subtitle (caption2, muted)
- `MatchScoreBadge` if `matchScore` exists
- "Tap To Create" hint (template only)

**Top overlay:**
- Bell button (`RecommendationBellView`) — opens `RecommendationsSheet` with the priority-2 items. Badge dot appears 30s after AI suggestions load (`startBellTimer`).
- Profile avatar (right) — opens `ProfileDisplayView`
- `MotivationalBannerView` — capsule with rotating tagline ("EXPLORE your universe…" etc), 7 messages, cycles every 15s

**Bottom overlay:**
- **VOYAGE** capsule button — opens full-screen `VoyageView`

**Loading state:**
- `GalaxyLoadingView` — rotating black star + "Loading . . ." label

### 2.6 Missions (Discover Feed) — `Views/Missions/MissionsView.swift`
📷 *image slot — missions list*

List-based alternate view of the same data.

**Filters row** (horizontal scroll, `TagFilterChip`):
- All, Set, Flex, My Year (filters by user's `collegeYear`), plus 7 topic tags (Hiking / Gaming / Food / Sports / Study / Hangout / Other)

**Search bar** — fuzzy match on title.

**Recommended for You** strip (horizontal scroll of `SuggestedMissionCard`):
- AI reason ("picked for you"), title, SET/FLEX badge, date or "Flexible time", spots-left label.
- Pulls from `viewModel.suggestedMissions` (AI service). Only shown when search is empty.

**Mission list** (`MissionListCard`):
- Vertical accent bar (pink→blue gradient for set, white for flex)
- Title + SET/FLEX capsule badge
- Set: date / location / tags / `MissionSpotsLabel` / optional `MatchScoreBadge`
- Flex: scheduled time or "group picks time" / availability summary / tags / group-size label / `FlexStatusBadge`
- Member-avatar row (right-aligned, overlapping stack of 3, "X/Y" count)
- Whole card is dark-themed for flex missions (#1a1a24 background)

**FAB:** "+ Create" gradient capsule (bottom-right) → opens `MissionCreateView`.

**Toolbar:**
- Bell (recommendations sheet)
- Profile avatar (right)

**MissionCreateView** — segmented Set/Flex toggle with mode-specific forms:
- **Shared:** Logo picker (SF Symbol sheet), tag picker (max 3 from 7 presets, plus custom tags), location search (`LocationSearchView` using MapKit), description
- **Set:** title, date picker, start/end time pickers, max pod size stepper (2–10)
- **Flex:** title (optional), group size (min 3 / max 10 with steppers), time range picker, links (2 URLs), creator availability grid (`CreatorAvailabilityGridView` — 10-day × hour grid with drag to select)

### 2.7 Mission / Signal Detail — `Views/Discovery/EventDetailView.swift`
📷 *image slot — mission detail and flex detail*

Sheet shown when tapping a mission card or planet. Branches by `mission.isFlexMode`.

**Set content:**
- Title (largeTitle bold)
- "Mission completed!" banner with countdown if done
- Date + location row (gradient icons)
- Tags chips
- Description
- `MissionPodStatusSection` — list of pods with member counts, spots left, selectable when joining
- `MissionMemberSection` — horizontal scroll of avatars + names + years (tappable)
- Action button: "Join Pod →" / "Open Pod" (gradient capsule)
- Background includes a `BottomWavyLines` decoration

**Flex content:**
- Logo icon + title
- `FlexStatusBadge` (orange = pending / green = active)
- Group size label
- Tags chips
- Description
- Links (tappable)
- **Availability section** — per-day cards showing hour chips (legacy: morning/afternoon/evening with sunrise/sun/moon icons)
- `MissionMemberSection`
- Sticky bottom: "Join Pod →" / "Open Pod"

**Creator-only toolbar:** ellipsis menu → Edit / Delete (with confirmation alert).

**Member tap:** if you're in the pod, opens full `ProfileDisplayView`; otherwise opens limited `MemberPreviewSheet` (name, year, interests only).

### 2.8 Pods List — `Views/Pod/PodsView.swift`
📷 *image slot — pods list*

**Filter chips:** All / Leading / Scheduling / Scheduled / Done.
**Search bar** for pod name.

Unified list combines:
- `Pod` rows (`PodRowCard`) — accent bar (green-tinted if survey pending, else gradient), title, "X members", scheduled time, `PodStatusBadge` (scheduling / scheduled ✓ / done — exchange contacts! / Activity done! Fill out survey!), chat-bubble icon with red unread dot
- `Mission` rows for flex signals you've RSVP'd to but that haven't matched into a pod yet (`FlexMissionRsvpCard`) — dark theme, logo + title, group label, optional match-score badge, availability summary, `SignalStatusBadgeDark`

Tapping a pod with `hasPendingSurvey == true` opens `SurveyView` instead of the chat.

**Toolbar:** bell (recommendations), profile avatar.

### 2.9 Pod Detail / Chat — `Views/Pod/PodView.swift` (+ `FlexPodFormingView`)
📷 *image slot — pod chat and flex forming view*

**For SET pods** (and FLEX pods after `.scheduled`):
- Member strip (avatars, current-user highlighted, kick menu for leader)
- Chat scroll with `ChatBubble` (text messages) and inline `VoteCardView` for vote messages
- Action bar at bottom: text field + send button + popover with vote-create / schedule / invite actions
- Toolbar: rename pod, invite (`PodInviteSheet`), leave pod alerts

**For FLEX pods in forming/locked/leaderPicking/countdown phases** → `FlexPodFormingView` instead of chat:
- Member strip
- `StatusBanner` (phase-dependent: "Add your availability", "Overlap found!", "You're the leader!", countdown text, etc.)
- `ScheduleGridView` — When2meet grid with colored slot stacking by member, drag-to-select, overlap highlight
- Overlap summary chips (green)
- Near-overlap hints (orange, when not yet overlapping)
- Bottom action: Save Availability / Confirm Time / Waiting message

**`VoteCardView`** shows the option progress bars, vote counts, checkmark on user's vote, "Remove vote" link, result row when closed.

**`SurveyView`** — opens automatically when entering a pod with `hasPendingSurvey`:
- 5-star enjoyment rating
- Interest tag chips to add to your profile (`SurveyViewModel.availableTags`)
- Member voting: thumbs up/down per other member (drives `trust_score`)
- Submit button

### 2.10 Friends Tab — `Views/Friends/FriendsView.swift`
📷 *image slot — friends list and inbox*

- Search bar (filters friend list)
- `List` of `FriendRowCard` — avatar, name, college year, unread-dot DM button, remove button, chevron
- Tap row → `ProfileDisplayView` of friend
- DM button → `DMChatView`

**Toolbar:**
- `tray` icon — opens `FriendInboxView` (Pod Invites, Friend Requests Incoming, Sent Requests). Red badge with count.
- `person.badge.plus` — opens `FriendSearchView`
- Profile avatar

**`DMChatView`** — standard chat with text bubbles, polls every few seconds (cached via the `ChatService` cache mentioned in recent commits).

**`FriendInboxView`** sections:
- Pod Invites (`PodInviteCard`) with Accept / Decline
- Incoming Friend Requests (Accept / Decline)
- Outgoing Sent Requests (Cancel)

### 2.11 Voyage Mode — `Views/Voyage/VoyageView.swift`
📷 *image slot — voyage view and zoomed solar system*

Full-screen black-space exploration.

**Star field** (Canvas, deterministic):
- 200 stars with parallax factor (scroll-dependent drift)
- Twinkle (sin animation per-star)
- Stars stretch into streaks when panning fast (warp effect, threshold velocity 800px/s)
- 3 staggered shooting-star slots
- 2 staggered drifting-ship slots

**Tile content layer:**
- 7×7 grid of `VoyageClusterView` instances around the current tile
- Each tile = a mini solar system: glowing sun (color cycled from gold/orange/yellow palette by tile seed), orbit rings, planet bubbles
- Tile loading via `VoyageService.fetchClusters` (5×5 region pre-fetched around current position)
- Tile eviction when over 25 tiles in memory

**`VoyageClusterView`:**
- Sun radius = `10 + min(items.count, 6) × 1.5`
- Orbit rings drawn for each item
- Planets (`VoyageBubble`) orbit slowly; speed alternates direction by index, deterministic from tile seed
- Each bubble: glow + Saturn ring (set missions) + core circle + icon (calendar for mission, antenna for signal) + label (when zoomed)

**Interactions:**
- Pan with drag (DragGesture)
- Pinch to zoom (0.4×–3.0×)
- Tap a cluster → spring-animated zoom to expanded overlay (full-screen, planets become tappable)
- Tap planet in zoomed view → fetches detail, opens `MissionDetailView`
- `VoyageHomeIndicator` — arrow pointing back to origin when > 2 tiles away

**HUD:**
- Top capsule hint: "Tap on solar systems to explore more activities!"
- Bottom: "End Voyage" capsule button
- Loading: `VoyageRocketLoading` — animated rocket with exhaust particles and bobbing motion

**Heartbeat:** sends current `(tileX, tileY)` to server every 10s while voyage is active.

---

## 3. Cross-Cutting UI Patterns

| Pattern | Where defined | Used in |
|---|---|---|
| `OrbitTheme.gradient` / `gradientFill` (pink→purple→blue) | `Utils/OrbitTheme.swift` | Buttons, gradients, accent strokes throughout |
| `ProfileAvatarView` | Designs (search `ProfileAvatarView`) | Every screen with avatars |
| `BottomWavyLines` / `WavyLinesView` | Designs | Auth flow, mission detail backgrounds |
| `TagFilterChip` | `MissionsView.swift` | Missions filters, Pods filters |
| `MatchScoreBadge` (color: green ≥0.85 / orange ≥0.70 / gray) | `MissionsView.swift` | Mission cards, planet info label, suggestion cards |
| `MissionSpotsLabel` | `MissionsView.swift` | Mission cards, suggestion cards |
| `FlowLayout` / `TagFlowLayout` | `EventDetailView.swift` | Tag rows, hour chips, MBTI, interests grids |
| `OrbitSectionHeader` | OrbitTheme | All forms |
| `ChatBubble` | PodView area | Pod chat, DM chat |
| `MemberStripView` | PodView area | Pod chat header, FlexPodFormingView |

---

## 4. Known Gaps & Placeholders (single list)

These are everything currently shown in the UI that does **not** trace back to a real datastore field:

1. 🔴 **Profile age** — `ProfileDisplayView` line ~85: literal `"{Age} Years Old"`. No `birthdate` / `age` column on `User`.
2. 🔴 **Astral mascot badge** — `ProfileDisplayView` uses `Image("coloredStar")` hardcoded. No mascot-selection logic; one star for everyone.
3. 🔴 **Habits sentence** — `ProfileDisplayView.habitsSentence` is template copy ("prefers larger group settings, in the morning"). No habit inference engine, no `Profile.habits` field.
4. 🔴 **"You created this" marker on planets** — `DiscoveryView`/`PlanetNodeView` doesn't render any symbol for `mission.creatorId == currentUserId`. Data is present (hosted = priority-0 inner ring) but no per-planet badge.
5. 🔴 **Block / Report user** — `ProfileDisplayView` ellipsis menu actions both alert "Coming Soon".
6. 🟡 **Pod local-only fields** — `Pod.confirmedTime`, `scheduleDeadline`, `leaderPickDeadline` are decoded as `nil`; only the local client tracks them. Backend `Pod` has `scheduled_time` but the deadline fields are missing.
7. 🟡 **`User.phoneNumber`** — legacy field still on the model, never written by the email-only auth flow.
8. 🟡 **`PhoneEntryView` / `VerificationView`** — stub view files left from SMS auth.
9. 🟡 **`activityCategory` on Signal** — old enum still required by backend Signal schema but new flex missions use SF Symbol `logo` instead. Phase-out in progress.
10. 🟡 **`AvailabilitySlot.timeBlocks`** — legacy morning/afternoon/evening format still decoded for old signals; new ones write `hours: [Int]`.
11. 🟡 **`TrustScoreView`** — defined in `ProfileDisplayView.swift` but not currently mounted anywhere. The `trust_score` value is updated by the survey but never shown.
12. 🟡 **`Mission.utcOffset`** — written on create, used for deletion countdown, but no UI exposes it.

---

## 5. Data ↔ View Quick Lookup

| Model | Primary screens that consume it |
|---|---|
| `Profile` | Discovery (center node), MainTabView (toolbar avatar), ProfileDisplayView, QuickProfileSetupView, every tab toolbar |
| `Mission` (set) | DiscoveryView (planet), MissionsView (list card), MissionDetailView, MissionCreateView, VoyageBubble |
| `Mission` (flex) | DiscoveryView (planet with pulsing ring), MissionsView (dark card), MissionDetailView (flex branch), MissionCreateView (flex tab), PodsView (RSVP card), VoyageBubble |
| `Pod` | PodsView, PodView, FlexPodFormingView, MissionDetailView (pod selector), SurveyView |
| `PodSummary` / `MemberPreview` | MissionListCard (avatar stack), MissionPodStatusSection |
| `ScheduleGrid` | ScheduleGridView, FlexPodFormingView, MissionCreateView (creator availability) |
| `ChatMessage` | PodView (chat), DMChatView |
| `Vote` | PodView (inline cards), VoteCardView |
| `Friendship` / `FriendProfile` | FriendsView, FriendRowCard |
| `FriendRequest` | FriendInboxView |
| `PodInvite` | FriendInboxView, PodInviteSheet |
| `VoyageTile` / `VoyageItem` | VoyageView, VoyageClusterView |
| `AuthResponseData` | AuthFlowView (decoded → UserDefaults) |
| `Signal` | Decoded internally by `MissionService`, converted to `Mission` via `Mission.fromSignal()` before any view sees it |

---

## 6. Maintenance Notes

- **`Models/Event.swift` is misnamed** — the struct inside is `Mission`. Renaming the file would help discovery.
- **Two paths to flex detail** — `MissionDetailView` (used everywhere) and `SignalDetailView` (also defined in `EventDetailView.swift`, but appears unused now — confirm before deleting).
- **Color palettes are spread out** — `DiscoveryTheme`, `OrbitTheme`, `MemberColor`, plus per-view ad-hoc hex codes. Consolidating could simplify theming later.
- **AI recommendation explanation strings** — `Mission.suggestionReason` is shown in `SuggestedMissionCard` and `RecommendationsSheet`. Make sure backend always populates it; client fallback in `DiscoveryViewModel` synthesizes one from tag overlap when missing.
