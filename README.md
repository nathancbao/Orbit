# Orbit

A social activity discovery platform for college students, built with SwiftUI. Orbit connects students through shared interests by combining scheduled events, spontaneous hangouts, and small-group coordination — all wrapped in a galaxy-themed interface.

## Features

### Discovery (Galaxy View)
The home screen presents activities as planets orbiting around the user in a visual galaxy layout. Activities are arranged in concentric priority rings:

- **Ring 0** — Activities you host (missions & signals you created)
- **Ring 1** — Activities you've joined
- **Ring 2** — AI-recommended activities based on your interests
- **Ring 3** — Discoverable activities & templates generated from your interests

Each node is styled by type: missions appear as Saturn-like planets with rings, signals pulse with radiating rings, and templates show dashed outlines inviting creation. The view includes animated twinkling stars, a floating comet, and a recommendation bell that surfaces AI-curated suggestions.

### Missions (Scheduled Events)
Fixed-date community events like club meetings, concerts, hikes, or study sessions. Users can:

- Browse a discover feed of upcoming missions with tag filters (Hiking, Gaming, Music, etc.)
- View AI-suggested missions with personalized match scores and reasoning
- Create new missions with title, description, date/time, location, and max group size
- Join missions, which automatically places the user into a Pod

Mission cards display date, time, location, tags, available spots, and a color-coded match score badge.

### Signals (Spontaneous Activities)
Informal "anyone down?" requests for immediate or near-term hangouts. Users can:

- Browse a discover feed of active signals from other students
- Create signals by choosing an activity category (Sports, Food, Movies, Hangout, Study, or Custom), setting group size preferences, selecting hourly availability windows, and adding a description
- RSVP to signals from other users
- Track signal status: Pending (below minimum group size) or Active (minimum met)

### Pods (Group Coordination)
Small groups formed around missions or signals. Once in a pod, members can:

- **Chat** in real time with other pod members
- **Vote** on meeting times and places with structured polls
- **View members** and their profiles
- **Manage the pod** — rename it, confirm attendance, or leave

Pods progress through statuses: forming, full, meeting confirmed, and completed.

### Profile
User profiles include:

- Name, college year, and .edu email (verified)
- Profile photo and gallery (up to 6 photos)
- Bio (up to 250 characters)
- Interests (3–10 tags)
- Gender and MBTI type
- Social links (up to 3)
- Trust score (0–5, server-computed)

Profiles are set up during onboarding via a multi-section form and can be edited later from any tab.

## Architecture

The app follows an **MVVM + Services** pattern:

```
OrbitApp/Orbit/
├── ContentView.swift             # App state routing (launch → auth → profile setup → home)
├── OrbitApp.swift                # Entry point
├── Models/                       # Data structs (Profile, Mission, Signal, Pod, ChatMessage, Vote)
├── ViewModels/                   # @MainActor ObservableObjects per feature
├── Services/                     # Networking layer (APIService + feature-specific services)
├── Views/
│   ├── Auth/                     # Email verification flow
│   ├── Discovery/                # Galaxy view
│   ├── Missions/                 # Mission discover feed & creation
│   ├── Signals/                  # Signal discover feed & creation
│   ├── Pod/                      # Pod detail, chat, voting
│   └── Profile/                  # Profile display & setup
└── Utils/                        # Constants, theme, keychain helper
```

### Key Patterns

- **Custom tab bar** — MainTabView uses a ZStack (not TabView) so all four tabs stay alive and preserve state across switches
- **Singleton services** — APIService, AuthService, ProfileService, MissionService, SignalService, PodService, ChatService
- **Token management** — Access and refresh tokens stored in Keychain; APIService automatically refreshes on 401
- **Image handling** — Photos are downscaled to 512px max dimension before upload via multipart/form-data

## Authentication

1. User enters a `.edu` email address
2. Server sends a 6-digit verification code
3. User enters the code to authenticate
4. Access and refresh tokens are stored in Keychain
5. On 401, the app transparently refreshes the token and retries

## API

All networking goes through `APIService.shared`, which provides a generic `request<T>()` method with automatic JSON encoding/decoding (snake_case conversion), token injection, and error handling.

**Base URL:** Configured in `Constants.swift` (supports local and production endpoints)

**Endpoint groups:**
- `/auth/*` — Send code, verify code, refresh, logout
- `/users/me/*` — Profile CRUD, photo uploads, gallery management
- `/missions/*` — List, create, join, leave, skip; suggested missions
- `/signals/*` — Discover, create, RSVP, delete
- `/pods/*` — Details, rename, leave, kick, confirm attendance
- `/pods/*/messages` — Chat messages
- `/pods/*/votes` — Vote creation and responses

## Design System

The app uses a consistent space/galaxy theme defined in `OrbitTheme`:

- **Colors:** Pink, Purple, Blue
- **Gradients:** Horizontal (pink → purple → blue) and diagonal variants
- **Components:** TagChip, TagFlowLayout, OrbitSectionHeader, ProfileAvatarView, CardPressStyle

Custom navigation icons are used for the tab bar (discovery, mission, signal, pods — each with blank and color variants).

## Tech Stack

- **SwiftUI** — Declarative UI framework
- **Combine** — Reactive state management via @Published
- **URLSession** — Networking
- **Keychain** — Secure token storage
- **XCTest** — Unit tests for models and view models

## Requirements

- iOS 26+
- Xcode 26+
- A `.edu` email address for authentication
