# Orbit

A social activity discovery platform for college students. Orbit connects students through shared interests by combining scheduled events (set missions), spontaneous hangouts (flex missions), and small-group coordination through pods — all wrapped in a galaxy-themed interface.

## Features

### AI-Recommended Activities
The core discovery experience is powered by a hybrid AI recommendation engine. Each mission is scored against the user's profile using five signals — keyword matching, semantic similarity, collaborative filtering, behavioral history, and creator trust — producing a personalized match score displayed as a percentage badge. A recommendation bell on the home screen surfaces the highest-scored activities with explanations of why each was suggested (e.g. "Matches your interests: Hiking, Outdoors"). When the backend has no recommendations yet, a client-side fallback scores available missions by tag overlap with the user's interests.

### Voyage Mode (Infinite Exploration)
Voyage is a fullscreen, infinite 2D space that users can pan and pinch through to discover activities beyond their immediate feed. Activities are grouped into solar-system clusters scattered across a tile-based grid — each cluster has a glowing sun at its center with missions and flex missions orbiting as planets. The backend deterministically assigns activities to tiles using seeded shuffling so every user sees the same layout for a given coordinate.

Users can:

- Pan freely in any direction through an infinite star field with parallax scrolling, shooting stars, and drifting ships
- Tap a solar system cluster to zoom in and see its individual activities
- Tap an activity planet to open its detail sheet and join
- Pinch to zoom in or out of the tile grid
- Follow a home-direction indicator to navigate back to the origin

Tiles load dynamically as the user pans, with a 5x5 region fetched around the current position and distant tiles evicted to stay under memory limits. A heartbeat pings the server every 10 seconds with the user's current tile position.

### Set Missions (Scheduled Events)
Fixed-date community events like club meetings, concerts, hikes, or study sessions. Users can:

- Browse a discover feed of upcoming missions with tag filters (Hiking, Gaming, Music, etc.)
- View AI-suggested missions with personalized match scores and reasoning
- Create new missions with title, description, date/time, location, tags, and max group size
- Join missions, which automatically places the user into a pod

Mission cards display date, time, location, tags, available spots, and a color-coded match score badge.

### Flex Missions (Spontaneous Activities)
Informal "anyone down?" requests for immediate or near-term hangouts. Users can:

- Browse a discover feed of active flex missions from other students
- Create flex missions by choosing an activity category (Sports, Food, Movies, Hangout, Study, or Custom), setting group size preferences, selecting hourly availability windows, adding tags, and writing a description
- RSVP to flex missions from other users
- Coordinate timing through an availability grid where pod members mark their free hours and the leader confirms a time

Flex missions track status as pending (below minimum group size) or active (minimum met).

### Pods (Group Coordination)
Small groups formed around set or flex missions. Once in a pod, members can:

- **Chat** in real time with other pod members
- **Vote** on meeting times and places with structured polls
- **Schedule** via an availability grid (flex missions)
- **View members** and their profiles
- **Manage the pod** — rename it, confirm attendance, or leave
- **Kick voting** — members can vote to remove someone from the pod

Pods progress through statuses: forming, full, meeting confirmed, and completed. Pods expire 14 days after creation.

### Post-Activity Survey
After a pod's activity ends, members complete a survey:

- Rate enjoyment (1–5 stars), which feeds back into the recommendation engine
- Suggest new interest tags to add to their profile
- Upvote or downvote other pod members, adjusting trust scores

### Friends and Direct Messaging
- Search for other users by name or email
- Send, accept, or decline friend requests
- View friend profiles
- Direct message friends
- Share deep-link invitations via universal links

### Profile
User profiles include:

- Name, college year, and .edu email (verified)
- Profile photo and gallery (up to 6 photos)
- Bio (up to 250 characters)
- Interests (3–10 tags)
- Gender and MBTI type
- Social links (up to 3)

Profiles are set up during onboarding via a multi-section form and can be edited later from any tab.

## Architecture

### iOS App — MVVM + Services

```
OrbitApp/Orbit/
├── ContentView.swift             # App state routing (launch → auth → profile setup → home)
├── OrbitApp.swift                # Entry point, deep link handling
├── Models/                       # Data structs (Profile, Mission, Signal, Pod, ChatMessage, Vote, etc.)
├── ViewModels/                   # @MainActor ObservableObjects per feature
├── Services/                     # Networking layer (APIService + feature-specific services)
├── Views/
│   ├── Auth/                     # Email verification flow
│   ├── Discovery/                # Galaxy view and activity detail
│   ├── Missions/                 # Set and flex mission discovery, creation, and detail
│   ├── Pod/                      # Pod detail, chat, voting, scheduling
│   ├── Profile/                  # Profile display, setup, and editing
│   ├── Friends/                  # Friends list and friend requests
│   └── Voyage/                   # Voyage discovery clusters
├── Designs/                      # Custom UI components
└── Utils/                        # Constants, theme, keychain helper
```

Key patterns:

- **Custom tab bar** — `MainTabView` uses a ZStack (not TabView) so all four tabs stay alive and preserve state across switches
- **Unified mission model** — Both set and flex missions are represented by a single `Mission` struct with a `mode` field (`.set` or `.flex`). Flex missions are converted from the backend Signal entity via `Mission.fromSignal()`
- **Singleton services** — `APIService`, `AuthService`, `ProfileService`, `EventService`, `PodService`, `ChatService`, `FriendService`, `ScheduleService`, `VoyageService`
- **Token management** — Access and refresh tokens stored in Keychain; `APIService` automatically refreshes on 401
- **Image handling** — Photos are downscaled to 512px max dimension before upload via multipart/form-data

### Backend — Flask + Google Cloud Datastore

```
OrbitServer/
├── api/                          # Flask blueprints (REST endpoints)
│   ├── auth.py                   # Email verification, JWT tokens
│   ├── users.py                  # Profile CRUD, photo uploads
│   ├── missions.py               # Set mission endpoints
│   ├── signals.py                # Flex mission endpoints
│   ├── pods.py                   # Pod management, scheduling, voting
│   ├── chat.py                   # Pod chat messages
│   ├── friends.py                # Friend requests and management
│   ├── dm.py                     # Direct messaging
│   ├── notifications.py          # Push notification registration
│   └── voyage.py                 # Voyage discovery clusters
├── models/
│   └── models.py                 # Datastore entity definitions and CRUD operations
├── services/                     # Business logic layer
│   ├── auth_service.py
│   ├── user_service.py
│   ├── mission_service.py        # Set mission logic
│   ├── signal_service.py         # Flex mission logic
│   ├── pod_service.py
│   ├── chat_service.py
│   ├── ai_suggestion_service.py  # Hybrid recommendation engine
│   ├── embedding_service.py      # Semantic embeddings (BAAI/bge-small-en-v1.5)
│   ├── lightfm_service.py        # Collaborative filtering
│   ├── schedule_service.py       # Pod scheduling and polling
│   ├── friend_service.py
│   ├── pod_invite_service.py
│   ├── survey_service.py         # Post-activity surveys
│   └── storage_service.py        # Google Cloud Storage uploads
└── utils/
    ├── auth.py                   # @require_auth decorator
    ├── validators.py             # Input validation
    ├── responses.py              # Standardized JSON responses
    ├── cache.py                  # In-memory caching with TTL
    ├── rate_limit.py             # Flask-Limiter setup
    ├── helpers.py                # Utility functions
    └── profanity.py              # Content moderation
```

Key patterns:

- **Layered architecture** — Routes (blueprints) → Services (business logic) → Models (Datastore queries)
- **Standardized responses** — All endpoints return `{"success": true/false, "data": ..., "error": ...}`
- **Auth decorator** — `@require_auth` extracts the user ID from the JWT on protected routes
- **Transactional writes** — Signal RSVP and pod updates use Datastore transactions for atomicity
- **In-memory caching** — User, mission, and pod caches with TTL-based invalidation

## AI Recommendation Engine

Orbit uses a hybrid recommendation system that scores every mission for each user using five weighted signals:

| Signal | Weight | Description |
|--------|--------|-------------|
| TF-IDF cosine similarity | 30% | Keyword matching between user interests and mission title/description/tags |
| Semantic embeddings | 20% | Meaning-level similarity using BAAI/bge-small-en-v1.5 (local, no external API) |
| LightFM collaborative filtering | 25% | Patterns from what similar users have joined |
| Behavioral decay | 15% | User's join/skip history with exponential time decay (~14-day half-life) |
| Trust weight | 10% | Mission creator's reliability score |

Scores are rescaled to a 55–97% range for display. The post-activity survey creates a feedback loop: enjoyment ratings improve the collaborative filtering model, added interests refine the embedding and TF-IDF signals, and member votes adjust trust scores.

## Authentication

1. User enters a `.edu` email address
2. Server sends a 6-digit verification code via SendGrid
3. User enters the code to authenticate
4. Server returns access (15 min) and refresh (7 days) tokens
5. Tokens are stored in Keychain on the client
6. On 401, the app transparently refreshes the token and retries

## API

All iOS networking goes through `APIService.shared`, which provides a generic `request<T>()` method with automatic JSON encoding/decoding (snake_case conversion), token injection, and error handling.

**Endpoint groups:**
- `/auth/*` — Send code, verify code, refresh, logout
- `/users/me/*` — Profile CRUD, photo uploads, gallery management
- `/missions/*` — List, create, join, leave, skip; AI-suggested missions
- `/signals/*` — Discover, create, RSVP, update, delete (flex missions)
- `/pods/*` — Details, rename, leave, kick vote, confirm attendance
- `/pods/*/messages` — Chat messages
- `/pods/*/votes` — Vote creation and responses
- `/pods/*/schedule/*` — Availability grid and time confirmation (flex missions)
- `/friends/*` — List, send/accept/decline requests, remove
- `/dm/*` — Conversations and messages
- `/voyage/*` — Discovery clusters and heartbeat

## Design System

The app uses a consistent space/galaxy theme defined in `OrbitTheme`:

- **Colors:** Pink, Purple, Blue
- **Gradients:** Horizontal (pink → purple → blue) and diagonal variants
- **Components:** TagChip, TagFlowLayout, OrbitSectionHeader, ProfileAvatarView, CardPressStyle

Custom navigation icons are used for the tab bar, each with blank and color variants.

## Tech Stack

### iOS
- **SwiftUI** — Declarative UI framework
- **Combine** — Reactive state management via @Published
- **URLSession** — Networking
- **Keychain** — Secure token storage
- **XCTest** — Unit tests

### Backend
- **Flask** — Python web framework
- **Google Cloud Datastore** — NoSQL database
- **Google Cloud Storage** — Photo and file storage
- **Google App Engine** — Hosting with auto-scaling (1–3 instances)
- **SendGrid** — Email verification codes
- **APNS** — iOS push notifications
- **PyJWT** — Token generation and validation
- **scikit-learn** — TF-IDF vectorization for recommendations
- **fastembed** — Semantic embeddings (BAAI/bge-small-en-v1.5)
- **LightFM** — Collaborative filtering
- **Flask-Limiter** — Rate limiting
- **better-profanity** — Content moderation

## Requirements

- iOS 26+
- Xcode 26+
- Python 3.11 (backend)
- A `.edu` email address for authentication
