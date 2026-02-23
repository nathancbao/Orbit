# Orbit — Codebase Base Reference

> Last updated after the events-first rework. Use this as the source of truth for what exists, where it lives, and how the pieces connect.

---

## Product Overview

Orbit is a friend-finding app for college students. The core philosophy: **meet people through activities, not profiles.**

**Flow:**
1. Sign up with a `.edu` email → verify with a 6-digit code
2. Quick profile setup (<30 seconds): name, college year, 3–10 interests, optional photo
3. Browse events on the Discover screen
4. Join an event → get placed into a small pod (3–4 people) with compatible attendees
5. Chat with your pod, vote on an exact time and place
6. Meet up IRL → confirm attendance → earn trust points
7. Chat deletes 48h after the event

---

## Repo Structure

```
Orbit/
├── main.py                   # Flask app entry point
├── requirements.txt
├── OrbitServer/              # Python/Flask backend
│   ├── api/                  # Route blueprints
│   ├── models/               # Datastore CRUD layer
│   ├── services/             # Business logic
│   └── utils/                # Auth, validators, responses, profanity filter
├── OrbitApp/                 # iOS app (Swift/SwiftUI)
│   └── Orbit/
│       ├── Models/           # Codable data models
│       ├── Services/         # API call layer
│       ├── ViewModels/       # @ObservableObject state
│       ├── Views/            # SwiftUI screens
│       └── Utils/            # Constants, Keychain, OrbitTheme
└── MDfiles/                  # Project documentation
```

---

## Backend

### Stack
- **Python 3 / Flask**
- **Google Cloud Datastore** (NoSQL, schemaless)
- **Google Cloud Storage** for profile photos
- **JWT auth** (HS256, 15-min access / 7-day refresh tokens)
- Deployed to **Google App Engine** (`orbit-app-486204.wl.r.appspot.com`)

### API Blueprints (`OrbitServer/api/`)

| File | Prefix | Purpose |
|------|--------|---------|
| `auth.py` | `/api/auth` | Send code, verify code, refresh token, logout |
| `users.py` | `/api/users` | Get/update profile, upload photo |
| `events.py` | `/api/events` | List, create, join/leave, skip, AI-suggested |
| `pods.py` | `/api/pods` | Get pod + members, kick vote, confirm attendance |
| `chat.py` | `/api/pods/<id>/messages` + `/votes` | Messages, vote creation, vote responses |

### Data Models (`OrbitServer/models/models.py`)

**Profile**
```
user_id, name, college_year, interests[], photo, trust_score, email,
created_at, updated_at
```
- `college_year`: `freshman | sophomore | junior | senior | grad`
- `trust_score`: float 0.0–5.0, default 3.0
- Profile complete = has name + college_year + ≥3 interests

**Event** (replaces old Mission)
```
id, title, description, tags[], location, date (YYYY-MM-DD),
creator_id, creator_type (user|seeded|ai_suggested),
max_pod_size (default 4), status (open|completed|cancelled),
created_at, updated_at
```

**EventPod**
```
id (UUID), event_id, member_ids[], max_size,
status (open|full|meeting_confirmed|completed|cancelled),
scheduled_time, scheduled_place, confirmed_attendees[],
kick_votes {target_user_id: [voter_ids]},
created_at, expires_at
```

**ChatMessage**
```
id (UUID), pod_id, user_id, content,
message_type (text|vote_created|vote_result|system),
created_at
```

**Vote**
```
id (UUID), pod_id, created_by, vote_type (time|place),
options[], votes {user_id: option_index},
status (open|closed), result, created_at, closed_at
```

**UserEventHistory**
```
id, user_id, event_id, pod_id,
action (joined|browsed|skipped),
attended, points_earned, created_at
```

**Auth entities:** `User`, `RefreshToken`, `VerificationCode`

### Key Services

| File | Responsibility |
|------|---------------|
| `auth_service.py` | Token creation, email verification, demo mode |
| `user_service.py` | Profile formatting, completeness check, photo upload |
| `event_service.py` | Event CRUD, score-sorted listing |
| `pod_service.py` | Pod assignment on join, kick logic, attendance confirmation |
| `chat_service.py` | Message send (w/ profanity filter), vote creation + auto-close |
| `ai_suggestion_service.py` | Jaccard scoring on interests + history, suggestion reasons |

### Pod Assignment Logic (`pod_service.py → join_event`)
1. Check if user already in a pod for this event → return it
2. Find any `open` pod with `len(member_ids) < max_size`
3. If found: add user, set status `full` if now at cap
4. If none: create a new pod with user as first member
5. Record `joined` action in `UserEventHistory`

### Auth — Demo Mode
- Email must end in `.edu`
- Code `123456` is accepted for **any** email (demo bypass, no SendGrid needed)
- Set `DEMO_MODE=false` and configure SendGrid env vars for production

### Profanity Filter (`utils/profanity.py`)
Simple word-list check on chat message content. Returns `400` with `"Message contains prohibited content"` if triggered. Extend with a library when ready.

---

## iOS App

### Stack
- **Swift / SwiftUI**
- **async/await** throughout
- **Keychain** for token storage (`KeychainHelper`)
- **UserDefaults** for `orbit_user_id` (used in pod/chat views)

### App State Flow (`ContentView.swift`)
```
.launch  →  .auth  →  .profileSetup  →  .home
```
- New users: auth → profileSetup → home
- Returning users: auth → home (profile loaded from server)
- Edit profile: home → profileSetup (with cancel button)

### Navigation — 3 Tabs (`MainTabView.swift`)
| Tab | View | Description |
|-----|------|-------------|
| Discover | `EventDiscoverView` | AI suggestions strip + full event list |
| My Events | `MyEventsView` | Pods the user has joined |
| Profile | `ProfileDisplayView` | Name, year, interests, trust score |

### Key Views

**`QuickProfileSetupView`** (`Views/Profile/`)
- Single screen, <30 seconds
- Fields: name, college year (picker), interests (chip grid + custom input), optional photo
- Disclaimer: *"Your account is permanently tied to your school email. Choose your profile and behavior wisely."*
- Calls `ProfileService.updateProfile()` then `ProfileService.uploadPhoto()` if photo provided

**`EventDiscoverView`** (`Views/Discover/`)
- Horizontal "Suggested for you" strip (AI-scored events with reason labels)
- Vertical all-events list with interest tag filter chips
- "My Year" toggle (passes `?year=` query param)
- Pull-to-refresh
- Taps open `EventDetailView` sheet

**`EventDetailView`** (`Views/Discover/`)
- Full event info, pod slots summary
- "Join Pod" button → `POST /events/<id>/join` → opens `PodView`
- If already in pod: "Open your pod" button

**`PodView`** (`Views/Pod/`)
- Member strip (name + year badges, long-press → kick)
- Action bar: Vote on Time | Vote on Place | Add to Calendar | Confirm Attendance
- Chat bubbles (gradient for current user, gray for others)
- System messages (vote opened, vote closed, etc.)
- Inline `VoteCardView` for open/closed votes
- Google Calendar deep link (no SDK, URL scheme)

**`VoteCardView`** (`Views/Pod/`)
- Shows options with vote counts + progress bar
- User's selection highlighted with gradient border
- Auto-shows result when vote closes

### Models (`Models/`)

| File | Types |
|------|-------|
| `Profile.swift` | `Profile` — name, collegeYear, interests, photo, trustScore |
| `Event.swift` | `Event`, `PodSummary` |
| `EventPod.swift` | `EventPod`, `PodMember` |
| `ChatMessage.swift` | `ChatMessage`, `Vote` |
| `APIResponse.swift` | `APIResponse<T>`, `AuthResponseData`, `ProfileResponseData` |

### Services (`Services/`)

| File | Calls |
|------|-------|
| `APIService.swift` | Generic `request<T>()` — handles auth header, snake_case decode, error parsing |
| `AuthService.swift` | send-code, verify-code (saves tokens + userId), refresh, logout |
| `ProfileService.swift` | GET/PUT `/users/me`, multipart photo upload |
| `EventService.swift` | list, suggested, get, create, join, leave, skip |
| `PodService.swift` | get pod, kick, confirm attendance |
| `ChatService.swift` | get messages, send message, get votes, create vote, respond to vote |

### Design System (`Utils/OrbitTheme.swift`)
All new views use `OrbitTheme` instead of hardcoded color literals.

```swift
OrbitTheme.pink       // Color(red: 0.9,  green: 0.6,  blue: 0.7)
OrbitTheme.purple     // Color(red: 0.7,  green: 0.65, blue: 0.85)
OrbitTheme.blue       // Color(red: 0.45, green: 0.55, blue: 0.85)
OrbitTheme.gradient   // Horizontal pink→purple→blue (text accents, borders, icons)
OrbitTheme.gradientFill // Diagonal blue→pink (filled buttons, FABs)
OrbitTheme.cardGradient // Dark card background (future dark mode cards)
```

Reusable components also in `OrbitTheme.swift`:
- `TagChip` — pill chip with optional remove button, supports dark background
- `TagFlowLayout` — wrapping flow layout for tag chips
- `OrbitSectionHeader` — title + gradient underline capsule
- `CardPressStyle` — scale-down press animation for card buttons

---

## What's NOT Built Yet

| Feature | Notes |
|---------|-------|
| Push notifications | Backend triggers planned; iOS `UNUserNotificationCenter` hooks stubbed in `PodView` |
| Chat deletion cron | 48h after pod expires; needs a Cloud Scheduler job calling a cleanup endpoint |
| `/users/me/pods` endpoint | `MyEventsView` currently has a placeholder loader — needs a backend endpoint that returns all pods the user is in |
| Kick replacement logic | `_find_replacement()` in `pod_service.py` is a stub; returns `None` |
| Trust score penalties | `apply_no_show_penalties()` exists in `pod_service.py` but needs to be called by a cron job |
| College year filter (backend) | Query param `?year=` is accepted but not yet filtered in `list_events()` |
| AI learning from history | `UserEventHistory` is recorded on join; `ai_suggestion_service.py` uses it partially (tag boost is a TODO) |
| EventSuggester notifications | AI can score suggestions; push delivery not wired up |
| Event seeding | No seeded catalog yet — events must be user-created |

---

## Environment Variables (Backend)

| Var | Description |
|-----|-------------|
| `JWT_SECRET` | Secret for signing JWTs (default: `dev-secret-change-me`) |
| `GOOGLE_CLOUD_PROJECT` | GCP project ID for Datastore |
| `GCS_BUCKET` | GCS bucket for photos (default: `orbit-app-photos`) |
| `SENDGRID_API_KEY` | Email sending (not needed in demo mode) |
| `DEMO_MODE` | `true` = skip SendGrid, accept `123456` for any code |
