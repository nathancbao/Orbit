# Orbit Client Architecture

## Overview

Orbit is an iOS app that helps users find friends through AI-powered matching, small group formation (Crews), and real-world events (Missions).

### Tech Stack

| Component | Technology |
|-----------|------------|
| Platform | iOS 17+ |
| Language | Swift 5.9 |
| UI Framework | SwiftUI |
| Architecture | MVVM (Model-View-ViewModel) |
| Networking | URLSession with async/await |
| Auth Storage | Keychain |
| Preferences | UserDefaults |

---

## Project Structure

```
Orbit/
├── OrbitApp.swift              # App entry point
├── ContentView.swift           # Root view (auth check)
│
├── Models/                     # Data structures
│   ├── User.swift
│   ├── Profile.swift
│   ├── Crew.swift
│   ├── Mission.swift
│   └── APIResponse.swift
│
├── Views/                      # SwiftUI views
│   ├── Auth/
│   │   ├── PhoneEntryView.swift
│   │   ├── VerificationView.swift
│   │   └── ProfileSetupView.swift
│   │
│   ├── Home/
│   │   └── HomeView.swift
│   │
│   ├── Discover/
│   │   ├── DiscoverView.swift
│   │   ├── UserCardView.swift
│   │   └── UserDetailView.swift
│   │
│   ├── Crews/
│   │   ├── CrewsListView.swift
│   │   ├── CrewDetailView.swift
│   │   └── CreateCrewView.swift
│   │
│   ├── Missions/
│   │   ├── MissionsListView.swift
│   │   ├── MissionDetailView.swift
│   │   └── CreateMissionView.swift
│   │
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── EditProfileView.swift
│   │
│   └── Components/             # Reusable UI components
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       ├── ProfilePhotoView.swift
│       └── InterestTagView.swift
│
├── ViewModels/                 # View logic
│   ├── AuthViewModel.swift
│   ├── HomeViewModel.swift
│   ├── DiscoverViewModel.swift
│   ├── CrewsViewModel.swift
│   ├── MissionsViewModel.swift
│   └── ProfileViewModel.swift
│
├── Services/                   # API & business logic
│   ├── APIService.swift
│   ├── AuthService.swift
│   ├── UserService.swift
│   ├── CrewService.swift
│   ├── MissionService.swift
│   └── DiscoveryService.swift
│
└── Utils/                      # Helpers
    ├── KeychainHelper.swift
    ├── Constants.swift
    └── Extensions.swift
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEWS                                │
│                    (SwiftUI Views)                           │
│  Display UI, capture user input, observe ViewModel state     │
└─────────────────────────┬───────────────────────────────────┘
                          │ @StateObject / @ObservedObject
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      VIEWMODELS                              │
│                  (@Observable classes)                       │
│  Handle UI logic, transform data, manage view state          │
└─────────────────────────┬───────────────────────────────────┘
                          │ async/await calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       SERVICES                               │
│                    (Static methods)                          │
│  Make API calls, handle auth, manage local storage           │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP requests
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      FLASK API                               │
│               (orbit-app.appspot.com)                        │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Example

```
User taps "Join Crew" button
        │
        ▼
View calls: viewModel.joinCrew(crewId)
        │
        ▼
ViewModel calls: await CrewService.join(crewId)
        │
        ▼
Service makes: POST /api/v1/crews/{id}/join
        │
        ▼
API returns success
        │
        ▼
ViewModel updates: @Published var crews
        │
        ▼
View automatically re-renders
```

---

## Main Components

### 1. Views Layer (`Views/`)

Views are SwiftUI structs that display UI and respond to state changes. They contain no business logic.

| Folder | Purpose |
|--------|---------|
| `Auth/` | Login, verification, profile setup screens |
| `Home/` | Main landing screen after login |
| `Discover/` | Browse suggested users, swipe interface |
| `Crews/` | List, detail, and create crew screens |
| `Missions/` | List, detail, and create mission screens |
| `Profile/` | View and edit own profile |
| `Components/` | Reusable UI pieces |

**Example:**
```swift
struct CrewsListView: View {
    @StateObject private var viewModel = CrewsViewModel()

    var body: some View {
        List(viewModel.crews) { crew in
            NavigationLink(destination: CrewDetailView(crew: crew)) {
                CrewRowView(crew: crew)
            }
        }
        .task {
            await viewModel.loadCrews()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

---

### 2. ViewModels Layer (`ViewModels/`)

ViewModels handle all logic for their associated views. They call services, manage state, and expose data for the view to display.

| ViewModel | Responsibility |
|-----------|---------------|
| `AuthViewModel` | Phone verification, login state, profile setup |
| `HomeViewModel` | Home screen data, quick stats |
| `DiscoverViewModel` | Load suggestions, handle swipe actions |
| `CrewsViewModel` | List crews, join/leave, create |
| `MissionsViewModel` | List missions, RSVP, create |
| `ProfileViewModel` | Load/update profile, upload photos |

**Example:**
```swift
@Observable
class CrewsViewModel {
    var crews: [Crew] = []
    var isLoading = false
    var showError = false
    var errorMessage = ""

    func loadCrews() async {
        isLoading = true
        do {
            crews = try await CrewService.getMyCrews()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    func joinCrew(_ crewId: String) async {
        do {
            try await CrewService.join(crewId)
            await loadCrews() // Refresh list
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

---

### 3. Services Layer (`Services/`)

Services are stateless classes with static methods. They handle all communication with the API and local storage.

| Service | Responsibility |
|---------|---------------|
| `APIService` | Base HTTP client, token injection, error handling |
| `AuthService` | Send code, verify, refresh tokens, logout |
| `UserService` | Get/update profile, upload photos |
| `CrewService` | CRUD crews, join/leave |
| `MissionService` | CRUD missions, RSVP |
| `DiscoveryService` | Get suggested users, crews, missions |

**Example:**
```swift
class CrewService {
    static func getMyCrews() async throws -> [Crew] {
        let response: APIResponse<CrewsData> = try await APIService.get("/crews")
        return response.data.crews
    }

    static func join(_ crewId: String) async throws {
        let _: APIResponse<MessageData> = try await APIService.post("/crews/\(crewId)/join")
    }

    static func create(_ crew: CreateCrewRequest) async throws -> Crew {
        let response: APIResponse<Crew> = try await APIService.post("/crews", body: crew)
        return response.data
    }
}
```

---

### 4. Models Layer (`Models/`)

Models are simple Codable structs that match API response shapes.

---

## Key Data Models

### User & Profile

```swift
struct User: Codable, Identifiable {
    let id: String
    let phoneNumber: String
    let profileComplete: Bool
    let createdAt: Date
    let profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case profileComplete = "profile_complete"
        case createdAt = "created_at"
        case profile
    }
}

struct Profile: Codable {
    var name: String
    var age: Int
    var location: Location
    var bio: String
    var photos: [String]
    var interests: [String]
    var personality: Personality
    var socialPreferences: SocialPreferences
    var friendshipGoals: [String]

    enum CodingKeys: String, CodingKey {
        case name, age, location, bio, photos, interests, personality
        case socialPreferences = "social_preferences"
        case friendshipGoals = "friendship_goals"
    }
}

struct Location: Codable {
    var city: String
    var state: String
    var coordinates: Coordinates?
}

struct Coordinates: Codable {
    var lat: Double
    var lng: Double
}

struct Personality: Codable {
    var introvertExtrovert: Double
    var spontaneousPlanner: Double
    var activeRelaxed: Double

    enum CodingKeys: String, CodingKey {
        case introvertExtrovert = "introvert_extrovert"
        case spontaneousPlanner = "spontaneous_planner"
        case activeRelaxed = "active_relaxed"
    }
}

struct SocialPreferences: Codable {
    var groupSize: String
    var meetingFrequency: String
    var preferredTimes: [String]

    enum CodingKeys: String, CodingKey {
        case groupSize = "group_size"
        case meetingFrequency = "meeting_frequency"
        case preferredTimes = "preferred_times"
    }
}
```

### Crew & Membership

```swift
struct Crew: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let interestTags: [String]
    let memberCount: Int
    let maxMembers: Int
    let createdAt: Date
    let createdBy: String?
    let lastActivityAt: Date?
    let members: [CrewMember]?
    let previewMembers: [MemberPreview]?
    let upcomingMissions: [MissionPreview]?
    let isMember: Bool?
    let myRole: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, members
        case interestTags = "interest_tags"
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case lastActivityAt = "last_activity_at"
        case previewMembers = "preview_members"
        case upcomingMissions = "upcoming_missions"
        case isMember = "is_member"
        case myRole = "my_role"
    }
}

struct MissionPreview: Codable, Identifiable {
    let id: String
    let title: String
    let date: Date
}

struct CrewMember: Codable, Identifiable {
    let id: String
    let name: String
    let photo: String?
    let role: String
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, photo, role
        case joinedAt = "joined_at"
    }
}

struct MemberPreview: Codable, Identifiable {
    let id: String
    let name: String
    let photo: String?
}
```

### Mission & RSVP

```swift
struct Mission: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let date: Date
    let location: MissionLocation
    let interestTags: [String]
    let crewId: String?
    let crewName: String?
    let host: MemberPreview
    let attendees: [MissionAttendee]?
    let rsvpCount: Int
    let maxAttendees: Int?
    let myRsvp: String?
    let isHost: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, description, date, location, host, attendees
        case interestTags = "interest_tags"
        case crewId = "crew_id"
        case crewName = "crew_name"
        case rsvpCount = "rsvp_count"
        case maxAttendees = "max_attendees"
        case myRsvp = "my_rsvp"
        case isHost = "is_host"
    }
}

struct MissionAttendee: Codable, Identifiable {
    let id: String
    let name: String
    let photo: String?
    let rsvp: String
}

struct MissionLocation: Codable {
    let name: String
    let address: String?
    let coordinates: Coordinates?
}

enum RSVPStatus: String, Codable {
    case going
    case maybe
    case notGoing = "not_going"
}
```

### API Response Wrappers

```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
}

struct APIError: Codable, Error {
    let code: String
    let message: String
}

struct APIErrorResponse: Codable {
    let success: Bool
    let error: APIError
}

// Common response data types
struct MessageData: Codable {
    let message: String
}

struct CrewsData: Codable {
    let crews: [Crew]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case crews
        case nextCursor = "next_cursor"
    }
}

struct MissionsData: Codable {
    let missions: [Mission]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case missions
        case nextCursor = "next_cursor"
    }
}
```

### Discovery Response Models

```swift
// User suggestions
struct UserSuggestionsData: Codable {
    let suggestions: [SuggestedUser]
}

struct SuggestedUser: Codable, Identifiable {
    var id: String { user.id }
    let user: DiscoverUserProfile
    let compatibility: Compatibility
}

struct DiscoverUserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let age: Int
    let photo: String?
    let bio: String?
    let interests: [String]
}

// Crew suggestions
struct CrewSuggestionsData: Codable {
    let suggestions: [SuggestedCrew]
}

struct SuggestedCrew: Codable, Identifiable {
    var id: String { crew.id }
    let crew: Crew
    let compatibility: CrewCompatibility
}

struct CrewCompatibility: Codable {
    let score: Double
    let matchingInterests: [String]
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
        case score, reasons
        case matchingInterests = "matching_interests"
    }
}

// Mission suggestions
struct MissionSuggestionsData: Codable {
    let suggestions: [SuggestedMission]
}

struct SuggestedMission: Codable, Identifiable {
    var id: String { mission.id }
    let mission: Mission
    let compatibility: MissionCompatibility
}

struct MissionCompatibility: Codable {
    let score: Double
    let reasons: [String]
}

// Shared compatibility struct for user matching
struct Compatibility: Codable {
    let score: Double
    let sharedInterests: [String]
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
        case score, reasons
        case sharedInterests = "shared_interests"
    }
}
```

---

## Services Layer Detail

### APIService (Base Networking)

Handles all HTTP communication, token injection, and error parsing.

```swift
class APIService {
    static let baseURL = "https://orbit-app.uc.r.appspot.com/api/v1"

    static func get<T: Codable>(_ path: String) async throws -> T {
        return try await request(path, method: "GET")
    }

    static func post<T: Codable, B: Codable>(_ path: String, body: B? = nil) async throws -> T {
        return try await request(path, method: "POST", body: body)
    }

    private static func request<T: Codable, B: Codable>(
        _ path: String,
        method: String,
        body: B? = nil
    ) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let token = KeychainHelper.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(code: "NETWORK_ERROR", message: "Invalid response")
        }

        if httpResponse.statusCode >= 400 {
            let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw errorResponse.error
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
```

### AuthService

```swift
class AuthService {
    static func sendCode(phoneNumber: String) async throws {
        struct Request: Codable { let phone_number: String }
        let _: APIResponse<MessageData> = try await APIService.post(
            "/auth/send-code",
            body: Request(phone_number: phoneNumber)
        )
    }

    static func verifyCode(phoneNumber: String, code: String) async throws -> (user: User, isNewUser: Bool) {
        struct Request: Codable { let phone_number: String; let code: String }
        struct Response: Codable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
            let is_new_user: Bool
            let user: User
        }

        let response: APIResponse<Response> = try await APIService.post(
            "/auth/verify-code",
            body: Request(phone_number: phoneNumber, code: code)
        )

        // Store tokens
        KeychainHelper.saveAccessToken(response.data.access_token)
        KeychainHelper.saveRefreshToken(response.data.refresh_token)

        return (user: response.data.user, isNewUser: response.data.is_new_user)
    }

    static func logout() {
        KeychainHelper.deleteTokens()
    }

    static var isLoggedIn: Bool {
        return KeychainHelper.getAccessToken() != nil
    }
}
```

---

## Navigation Structure

### App Entry Flow

```
App Launch
    │
    ▼
┌─────────────┐
│ ContentView │ ── Checks auth state
└──────┬──────┘
       │
       ├─── Not logged in ───▶ AuthFlow
       │                           │
       │                     PhoneEntryView
       │                           │
       │                     VerificationView
       │                           │
       │                     ProfileSetupView (if new user)
       │                           │
       └─── Logged in ───────▶ MainTabView
```

### Main Tab Bar

```
┌─────────────────────────────────────────────────────────┐
│                      MainTabView                         │
├───────┬───────┬───────┬───────┬───────┬────────────────┤
│ Home  │Discover│ Crews │Missions│Profile│                │
└───┬───┴───┬───┴───┬───┴───┬───┴───┬───┘                │
    │       │       │       │       │                     │
    ▼       ▼       ▼       ▼       ▼                     │
  HomeView  │   CrewsList  │   ProfileView                │
            │       │      │                              │
       DiscoverView │  MissionsList                       │
            │       │      │                              │
       UserDetail CrewDetail MissionDetail                │
                    │      │                              │
              CreateCrew CreateMission                    │
└─────────────────────────────────────────────────────────┘
```

### Screen Inventory

| Tab | Screens | Purpose |
|-----|---------|---------|
| **Home** | HomeView | Dashboard with quick stats and recent activity |
| **Discover** | DiscoverView, UserDetailView | Browse/swipe suggested users |
| **Crews** | CrewsListView, CrewDetailView, CreateCrewView | Manage friend groups |
| **Missions** | MissionsListView, MissionDetailView, CreateMissionView | Browse and create events |
| **Profile** | ProfileView, EditProfileView | View and edit own profile |

---

## State Management

### Auth State (App-Wide)

```swift
@Observable
class AppState {
    static let shared = AppState()

    var isLoggedIn: Bool = AuthService.isLoggedIn
    var currentUser: User?

    func login(user: User) {
        self.currentUser = user
        self.isLoggedIn = true
    }

    func logout() {
        AuthService.logout()
        self.currentUser = nil
        self.isLoggedIn = false
    }
}
```

### Using in Views

```swift
@main
struct OrbitApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isLoggedIn {
            MainTabView()
        } else {
            AuthFlowView()
        }
    }
}
```

### ViewModel State Pattern

```swift
@Observable
class MissionsViewModel {
    // Data
    var missions: [Mission] = []

    // UI State
    var isLoading = false
    var showError = false
    var errorMessage = ""

    // Filters
    var selectedFilter: MissionFilter = .upcoming

    enum MissionFilter {
        case upcoming, myRsvp, myCrews
    }
}
```

---

## Error Handling

### Standard Pattern

```swift
// In ViewModel
func loadData() async {
    isLoading = true
    errorMessage = ""

    do {
        data = try await SomeService.fetch()
    } catch let error as APIError {
        errorMessage = error.message
        showError = true
    } catch {
        errorMessage = "Something went wrong. Please try again."
        showError = true
    }

    isLoading = false
}
```

### In Views

```swift
struct SomeView: View {
    @StateObject var viewModel = SomeViewModel()

    var body: some View {
        ZStack {
            // Main content
            List(viewModel.items) { item in
                ItemRow(item: item)
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingView()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
            Button("Retry") {
                Task { await viewModel.loadData() }
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

### Reusable Error View

```swift
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

## Constants

```swift
// Utils/Constants.swift
enum Constants {
    enum API {
        static let baseURL = "https://orbit-app.uc.r.appspot.com/api/v1"
        static let timeoutInterval: TimeInterval = 30
    }

    enum Keychain {
        static let accessTokenKey = "orbit_access_token"
        static let refreshTokenKey = "orbit_refresh_token"
    }

    enum Validation {
        static let minNameLength = 2
        static let maxNameLength = 50
        static let minAge = 18
        static let maxAge = 99
        static let maxBioLength = 500
        static let maxInterests = 20
    }

    enum Crew {
        static let minMembers = 3
        static let maxMembers = 15
    }
}
```
