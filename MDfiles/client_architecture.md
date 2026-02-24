# Orbit Client Architecture

## Overview

Orbit is an iOS app that helps college students meet people through **shared activities** (events). The core loop is: browse events → join a pod (small group) → coordinate with pod-mates via chat + voting → show up and confirm attendance.

Authentication is via `.edu` email with a 6-digit verification code (demo bypass: `123456`).

### Tech Stack

| Component | Technology |
|-----------|------------|
| Platform | iOS 17+ |
| Language | Swift |
| UI Framework | SwiftUI |
| Architecture | MVVM (Model-View-ViewModel) |
| Networking | URLSession with `async/await` |
| Auth Storage | iOS Keychain |
| State | `@StateObject` / `ObservableObject` |

---

## Project Structure

```
OrbitApp/Orbit/
├── OrbitApp.swift                      # @main app entry point
├── ContentView.swift                   # Root navigation coordinator (AppState)
│
├── Models/
│   ├── APIResponse.swift               # Generic wrapper + AuthResponseData, ProfileResponseData
│   ├── Event.swift                     # Event, PodSummary
│   ├── EventPod.swift                  # EventPod, PodMember
│   ├── ChatMessage.swift               # ChatMessage, Vote
│   ├── Mission.swift                   # Mission (activity request), ActivityCategory,
│   │                                   # TimeBlock, AvailabilitySlot, MissionStatus
│   ├── Profile.swift                   # Profile (name, college_year, interests, photo, trust_score)
│   └── User.swift                      # User (auth identity)
│
├── Services/
│   ├── APIService.swift                # Base HTTP client (singleton)
│   ├── AuthService.swift               # .edu email auth, JWT token management
│   ├── EventService.swift              # Events CRUD + join/leave/skip
│   ├── PodService.swift                # Pod detail, kick vote, confirm attendance
│   ├── ChatService.swift               # Pod chat messages + voting
│   └── ProfileService.swift            # Profile CRUD + photo upload
│
├── Utils/
│   ├── Constants.swift                 # Base URL, all API endpoints, Keychain keys
│   ├── KeychainHelper.swift            # Secure token read/write/delete
│   └── OrbitTheme.swift                # Shared SwiftUI styles / colors
│
├── ViewModels/
│   ├── AuthViewModel.swift             # Email entry + code verification flow
│   ├── EventDiscoverViewModel.swift    # Loads suggested + all events, filter state
│   ├── MissionsViewModel.swift         # Mission list (currently mock data)
│   ├── PodViewModel.swift              # Pod detail, chat, voting
│   └── ProfileViewModel.swift          # Profile display + edit
│
└── Views/
    ├── MainTabView.swift               # Tab bar (Discover / Missions / Profile)
    │
    ├── Auth/
    │   ├── AuthFlowView.swift          # Email entry + code verification UI
    │   ├── LaunchView.swift            # App splash / launch screen
    │   ├── PhoneEntryView.swift        # (unused placeholder)
    │   └── VerificationView.swift      # (unused placeholder)
    │
    ├── Discover/
    │   ├── EventDiscoverView.swift     # Card-stack event browser
    │   ├── EventDetailView.swift       # Full event detail + join/leave
    │   └── MyEventsView.swift          # Events the user has joined
    │
    ├── Discovery/
    │   └── DiscoveryView.swift         # (legacy placeholder)
    │
    ├── Missions/
    │   ├── MissionsView.swift          # List of user's missions (activity requests)
    │   └── MissionFormView.swift       # Create-mission form
    │
    ├── Pod/
    │   ├── PodView.swift               # Pod chat + member list + voting
    │   └── VoteCardView.swift          # Inline vote card component
    │
    └── Profile/
        ├── ProfileDisplayView.swift    # View own profile
        └── QuickProfileSetupView.swift # Profile creation / edit form
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEWS                               │
│                    (SwiftUI Views)                          │
│  Display UI, capture user input, observe ViewModel state    │
└─────────────────────────┬───────────────────────────────────┘
                          │ @StateObject / @ObservedObject
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      VIEWMODELS                             │
│              (ObservableObject, @MainActor)                 │
│  Handle UI logic, transform data, drive async/await calls   │
└─────────────────────────┬───────────────────────────────────┘
                          │ singleton service calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       SERVICES                              │
│             (Singletons via .shared)                        │
│  Encode requests, decode responses, attach Bearer token     │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTPS (URLSession)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      FLASK API                              │
│      orbit-app-486204.wl.r.appspot.com/api                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Models

### Event

```swift
struct Event: Codable, Identifiable {
    var id: String              // Stringified Datastore int ID ("5629499534213120")
    var title: String
    var description: String
    var tags: [String]
    var location: String
    var date: String            // "YYYY-MM-DD"
    var creatorId: Int?         // "creator_id"
    var creatorType: String?    // "user" | "seeded" | "ai_suggested"
    var maxPodSize: Int         // "max_pod_size"
    var status: String          // "open" | "completed" | "cancelled"
    var matchScore: Double?     // "match_score" – server-computed
    var suggestionReason: String?  // "suggestion_reason" – AI explanation
    var userPodStatus: String?  // "user_pod_status": "not_joined" | "in_pod" | "pod_full"
    var userPodId: String?      // "user_pod_id" – UUID of user's pod if in_pod
    var pods: [PodSummary]?     // present on GET /events/<id> only
}
```

### EventPod

```swift
struct EventPod: Codable, Identifiable {
    var id: String              // UUID string
    var eventId: Int            // "event_id"
    var memberIds: [Int]        // "member_ids"
    var maxSize: Int            // "max_size"
    var status: String          // "open" | "full" | "meeting_confirmed" | "completed" | "cancelled"
    var scheduledTime: String?  // "scheduled_time" – set by vote result
    var scheduledPlace: String? // "scheduled_place" – set by vote result
    var confirmedAttendees: [Int]  // "confirmed_attendees"
    var members: [PodMember]?   // enriched, only on GET /pods/<id>
}
```

### Mission (Activity Request)

```swift
struct Mission: Codable, Identifiable {
    let id: String
    let activityCategory: ActivityCategory   // "activity_category"
    let customActivityName: String?          // "custom_activity_name"
    let minGroupSize: Int                    // "min_group_size"
    let maxGroupSize: Int                    // "max_group_size"
    let availability: [AvailabilitySlot]
    let status: MissionStatus               // "pending_match" | "matched"
    let creatorId: Int                       // "creator_id"
    let createdAt: String?                   // "created_at"
}

enum ActivityCategory: String, Codable {
    case pickleball, basketball, cafeHopping, restaurant, studySession,
         hiking, gym, running, yoga, boardGames, movies, custom
}

struct AvailabilitySlot: Codable {
    let date: Date                // ISO 8601 (encoded with .iso8601 strategy)
    let timeBlocks: [TimeBlock]   // ⚠ No CodingKeys yet — server returns "timeBlocks" (camelCase)
                                  //   Add CodingKeys("time_blocks") when API is wired up
}

enum TimeBlock: String, Codable { case morning, afternoon, evening }
```

> **Note:** `MissionsViewModel` currently uses **local mock data only** — no API calls are made yet. When the API integration is implemented, `AvailabilitySlot` will need `CodingKeys` to map `"time_blocks"` → `timeBlocks`.

### Profile

```swift
struct Profile: Codable, Identifiable {
    var name: String
    var collegeYear: String    // "college_year": freshman | sophomore | junior | senior | grad
    var interests: [String]
    var photo: String?         // GCS URL
    var trustScore: Double?    // "trust_score": server-computed, 0.0–5.0
    var email: String?
    var matchScore: Double?    // "match_score": server-computed during discovery
}
```

### ChatMessage / Vote

```swift
struct ChatMessage: Codable, Identifiable {
    var id: String;  var podId: String;  var userId: Int
    var content: String;  var messageType: String  // text | vote_created | vote_result
    var createdAt: String
}

struct Vote: Codable, Identifiable {
    var id: String;  var podId: String;  var createdBy: Int
    var voteType: String        // "time" | "place"
    var options: [String]
    var votes: [String: Int]    // userId_string → option_index
    var status: String          // "open" | "closed"
    var result: String?
    var createdAt: String
}
```

---

## API Endpoints (from Constants.swift)

| Endpoint | Method | Service |
|----------|--------|---------|
| `/auth/send-code` | POST | AuthService |
| `/auth/verify-code` | POST | AuthService |
| `/auth/refresh` | POST | AuthService |
| `/auth/logout` | POST | AuthService |
| `/users/me` | GET/PUT | ProfileService |
| `/users/me/photo` | POST | ProfileService (multipart) |
| `/events` | GET | EventService (tag?, year?) |
| `/events/suggested` | GET | EventService |
| `/events/<id>` | GET | EventService |
| `/events` | POST | EventService |
| `/events/<id>/join` | POST | EventService → returns EventPod |
| `/events/<id>/leave` | DELETE | EventService |
| `/events/<id>/skip` | POST | EventService |
| `/pods/<id>` | GET | PodService (enriched members) |
| `/pods/<id>/kick` | POST | PodService |
| `/pods/<id>/confirm-attendance` | POST | PodService |
| `/pods/<id>/messages` | GET/POST | ChatService |
| `/pods/<id>/votes` | GET/POST | ChatService |
| `/pods/<id>/votes/<vid>/respond` | POST | ChatService |
| `/missions` | GET/POST | (future — MissionsViewModel mocked) |
| `/missions/<id>` | DELETE | (future) |

All authenticated endpoints send: `Authorization: Bearer <access_token>`

---

## Services Layer

### APIService (base client)

```swift
class APIService {
    static let shared = APIService()
    private let baseURL = "https://orbit-app-486204.wl.r.appspot.com/api"

    // Generic request; all other services call through this
    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,   // manually snake_cased by caller
        authenticated: Bool = false
    ) async throws -> T
}
```

- Request bodies are `[String: Any]` dicts encoded with `JSONSerialization` (snake_case keys written manually)
- Responses decoded with `JSONDecoder` using `.iso8601` date strategy (no key conversion)
- Response envelope: `{ "success": true, "data": <T> }` or `{ "success": false, "error": "..." }`
- 401 → throws `NetworkError.unauthorized`

### AuthService

Sends/verifies 6-digit codes to `.edu` addresses. On success stores `access_token` + `refresh_token` in Keychain and `user_id` in UserDefaults.

### EventService / PodService / ChatService / ProfileService

Each is a thin singleton that calls `APIService.shared.request(...)` with the right endpoint and body. ProfileService has a separate multipart upload path for photos.

---

## Navigation Flow

```
App Launch
    │
    ▼
ContentView (AppState enum)
    ├── .auth         → AuthFlowView (.edu email entry + code verification)
    │                      │
    │               on success
    │                      ├── isNewUser=true → .profileSetup
    │                      └── profile complete → .home
    │
    ├── .profileSetup → QuickProfileSetupView (name, year, interests)
    │                      │
    │               on save → .home
    │
    └── .home         → MainTabView
                            ├── Discover tab → EventDiscoverView
                            │                    └── EventDetailView (sheet)
                            ├── Missions tab → MissionsView
                            │                    └── MissionFormView (sheet)
                            └── Profile tab  → ProfileDisplayView
```

### MainTabView Tabs

| Tab | Root View | Purpose |
|-----|-----------|---------|
| Discover | `EventDiscoverView` | Browse & join events; see suggested events |
| Missions | `MissionsView` | Post activity requests (mock data) |
| Profile | `ProfileDisplayView` | View/edit own profile |

---

## ViewModels

| ViewModel | Drives | Key Async Calls |
|-----------|--------|-----------------|
| `AuthViewModel` | AuthFlowView | `sendVerificationCode`, `verifyCode` |
| `EventDiscoverViewModel` | EventDiscoverView | `suggestedEvents()`, `listEvents()`, `skipEvent()` |
| `MissionsViewModel` | MissionsView, MissionFormView | **local mock only** (no API calls yet) |
| `PodViewModel` | PodView | `getPod`, `getMessages`, `sendMessage`, `getVotes`, vote ops |
| `ProfileViewModel` | ProfileDisplayView, QuickProfileSetupView | `getProfile`, `updateProfile`, `uploadPhoto` |

---

## Error Handling

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)  // message from server's { "error": "..." }
    case unauthorized         // 401 → prompt re-login
    case networkError(Error)  // URLSession underlying error
}
```

ViewModels catch errors and publish them as `errorMessage: String?` for the view to display.

---

## Key Constants

```swift
enum Constants {
    enum API {
        static let baseURL = "https://orbit-app-486204.wl.r.appspot.com/api"
        // Local testing: "http://localhost:8080/api"
    }
    enum Keychain {
        static let accessToken  = "access_token"
        static let refreshToken = "refresh_token"
    }
    enum Validation {
        static let verificationCodeLength = 6
        static let minInterests = 3
        static let maxInterests = 10
    }
}
```
