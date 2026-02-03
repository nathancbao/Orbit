# Orbit Client Architecture

## Overview

Orbit is an iOS app that helps college students find friends through interest-based matching. Users authenticate with a .edu email, set up a detailed profile, and discover other users through a space-themed cosmos interface.

### Tech Stack

| Component | Technology |
|-----------|------------|
| Platform | iOS 17+ |
| Language | Swift |
| UI Framework | SwiftUI |
| Architecture | MVVM (Model-View-ViewModel) |
| Networking | URLSession with async/await |
| Auth Storage | iOS Keychain |

---

## Project Structure

```
Orbit/
├── models/                        # Data structures (shared with server repo)
│   ├── APIResponse.swift          # API response wrappers
│   ├── Profile.swift              # Profile, Location, Personality, etc.
│   └── User.swift                 # User model (currently unused by client)
│
├── services/                      # Networking layer (shared with server repo)
│   ├── APIService.swift           # Base HTTP client (singleton)
│   ├── AuthService.swift          # Email auth, token management
│   ├── ProfileService.swift       # Profile CRUD
│   └── DiscoverService.swift      # Suggested profiles (uses mock data)
│
├── utils/                         # Helpers (shared with server repo)
│   ├── Constants.swift            # API URLs, endpoints, validation rules
│   └── KeychainHelper.swift       # Secure token storage
│
└── orbitApp/                      # Main app target
    ├── OrbitApp.swift             # @main app entry point
    ├── ContentView.swift          # Root navigation coordinator
    │
    ├── ViewModels/
    │   ├── AuthViewModel.swift    # Email verification flow
    │   └── ProfileViewModel.swift # 5-step profile setup form
    │
    └── Views/
        ├── MainTabView.swift      # Tab bar (Discover + Profile)
        │
        ├── Auth/
        │   ├── AuthFlowView.swift       # Email entry + code verification
        │   ├── PhoneEntryView.swift      # Placeholder (unused)
        │   └── VerificationView.swift    # Placeholder (unused)
        │
        ├── Discover/
        │   └── DiscoverView.swift       # Space-themed cosmos interface
        │
        └── Profile/
            ├── ProfileSetupView.swift   # 5-step profile creation form
            └── ProfileDisplayView.swift # Profile card with photo carousel
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEWS                               │
│                    (SwiftUI Views)                           │
│  Display UI, capture user input, observe ViewModel state    │
└─────────────────────────┬───────────────────────────────────┘
                          │ @StateObject / @State
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      VIEWMODELS                             │
│              (@Observable / ObservableObject)                │
│  Handle UI logic, transform data, manage view state         │
└─────────────────────────┬───────────────────────────────────┘
                          │ async/await calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       SERVICES                              │
│                    (Singletons)                              │
│  Make API calls, handle auth, manage Keychain tokens        │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP requests (URLSession)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      FLASK API                              │
│       (orbit-app-486204.wl.r.appspot.com/api)               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Example

```
User completes profile setup form
        │
        ▼
View calls: viewModel.saveProfile()
        │
        ▼
ViewModel builds Profile struct via buildProfile()
        │
        ▼
ViewModel calls: ProfileService.shared.updateProfile(profile)
        │
        ▼
Service makes: PUT /api/users/me (authenticated)
        │
        ▼
API returns ProfileResponseData (profile + profile_complete)
        │
        ▼
ViewModel updates state, navigates to home
        │
        ▼
View automatically re-renders
```

---

## Main Components

### 1. Views Layer (`orbitApp/Views/`)

Views are SwiftUI structs that display UI and respond to state changes.

| Folder | Views | Purpose |
|--------|-------|---------|
| `Auth/` | AuthFlowView | .edu email entry and 6-digit code verification |
| `Discover/` | DiscoverView | Space-themed cosmos with orbiting user planets |
| `Profile/` | ProfileSetupView, ProfileDisplayView | 5-step profile creation and profile card display |
| Root | MainTabView | Tab bar with Discover and Profile tabs |

**AuthFlowView** handles both email entry and code verification in a single view, switching between states based on `AuthViewModel.authState`. Uses a dark blue gradient background.

**DiscoverView** renders a space-themed interface where the current user appears as a central "YOU" planet and other users appear as orbiting planets. Tapping a planet opens a profile detail sheet. Uses a star field background with pulsing animations.

**ProfileSetupView** is a multi-step form with 5 steps:
1. **BasicInfoStep** - Name, age, city, state, bio
2. **PersonalityStep** - 3 personality sliders (introvert/extrovert, spontaneous/planner, active/relaxed)
3. **InterestsStep** - Predefined interest chips + custom interests (min 3, max 10)
4. **SocialPreferencesStep** - Group size, meeting frequency, preferred times
5. **PhotoUploadStep** - Up to 6 photos from Photos library or Files

**ProfileDisplayView** shows a profile card with a photo carousel (swipeable), name/age/location header, bio, interests as tags, personality bars, and social preferences. Includes an edit button to re-enter profile setup.

---

### 2. ViewModels Layer (`orbitApp/ViewModels/`)

| ViewModel | Responsibility |
|-----------|---------------|
| `AuthViewModel` | .edu email validation, send/verify code flow, auth state management |
| `ProfileViewModel` | 5-step form data, step validation, interest management, photo selection, profile save |

**AuthViewModel** manages an `AuthState` enum (`.emailEntry`, `.verification`, `.authenticated`) and handles the complete auth flow. Validates that emails end in `.edu`. Supports demo bypass with code `"123456"`.

**ProfileViewModel** manages all form fields across the 5 setup steps. Key features:
- Step validation (each step must be valid before proceeding)
- Predefined interest categories with an option to add custom interests
- Photo selection from both Photos picker and Files
- `buildProfile()` converts form state into a `Profile` struct
- `saveProfile()` sends the profile to the server
- Can be pre-populated with existing profile data for editing

---

### 3. Services Layer (`services/`)

Services are singletons accessed via `.shared`.

| Service | Responsibility |
|---------|---------------|
| `APIService` | Generic HTTP request handler with JSON encoding/decoding, auth token injection |
| `AuthService` | Send verification code to email, verify code, refresh token, logout, check login state |
| `ProfileService` | Get and update user profile (supports mock data mode) |
| `DiscoverService` | Fetch suggested profiles (currently uses mock data) |

**APIService** is the foundation all other services use. Key features:
- Singleton pattern (`APIService.shared`)
- Generic `request<T: Codable>()` method for all HTTP calls
- Automatic snake_case encoding via `JSONEncoder.keyEncodingStrategy`
- Bearer token injection from Keychain when `authenticated: true`
- Decodes server responses from `{ "success": true, "data": {...} }` wrapper
- Custom `NetworkError` enum for error handling

**AuthService** sends `.edu` email and code to the server, saves returned tokens (access + refresh) to Keychain on successful verification.

**ProfileService** has a `useMockData` flag (currently `false`) for development without a server. Sends profile updates via `PUT /api/users/me` and retrieves profile via `GET /api/users/me`.

**DiscoverService** has a `useMockData` flag (currently `true`) and provides 5 hardcoded mock profiles for testing. The real API call targets `GET /api/discover/users`.

---

### 4. Models Layer (`models/`)

Models are Codable structs that match the API response shapes.

---

## Key Data Models

### API Response Wrappers

```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}

struct MessageData: Codable {
    let message: String
}

struct AuthResponseData: Codable {
    let accessToken: String       // "access_token"
    let refreshToken: String      // "refresh_token"
    let expiresIn: Int            // "expires_in" (900 seconds)
    let isNewUser: Bool           // "is_new_user"
    let userId: Int               // "user_id" (numeric Datastore ID)
}

struct ProfileResponseData: Codable {
    let profile: Profile
    let profileComplete: Bool     // "profile_complete"
}
```

### Profile

```swift
struct Profile: Codable, Identifiable {
    var id: String { name }       // Uses name as identifier
    var name: String
    var age: Int
    var location: Location
    var bio: String
    var photos: [String]          // GCS public URLs
    var interests: [String]
    var personality: Personality
    var socialPreferences: SocialPreferences   // "social_preferences"
    var friendshipGoals: [String]              // "friendship_goals"
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
    var introvertExtrovert: Double    // "introvert_extrovert" (0.0–1.0)
    var spontaneousPlanner: Double    // "spontaneous_planner" (0.0–1.0)
    var activeRelaxed: Double         // "active_relaxed" (0.0–1.0)
}

struct SocialPreferences: Codable {
    var groupSize: String             // "group_size" e.g. "Small groups (3-5)"
    var meetingFrequency: String      // "meeting_frequency" e.g. "Weekly"
    var preferredTimes: [String]      // "preferred_times" e.g. ["Weekends"]
}
```

### User (defined but not actively used by client auth flow)

```swift
struct User: Codable, Identifiable {
    let id: String
    let phoneNumber: String       // "phone_number" (legacy field name)
    let profileComplete: Bool     // "profile_complete"
    let createdAt: Date           // "created_at"
    let profile: Profile?
}
```

---

## Services Layer Detail

### APIService (Base Networking)

Handles all HTTP communication, token injection, and error parsing. All other services call through this.

```swift
class APIService {
    static let shared = APIService()

    private let baseURL = Constants.API.baseURL
    // "https://orbit-app-486204.wl.r.appspot.com/api"

    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        // 1. Build URL from baseURL + endpoint
        // 2. Set Content-Type: application/json
        // 3. If authenticated, add Bearer token from Keychain
        // 4. Encode body via JSONSerialization
        // 5. Make request via URLSession.shared.data(for:)
        // 6. Handle 401 → NetworkError.unauthorized
        // 7. Handle 400+ → decode error message from response
        // 8. Decode success response: APIResponse<T> → return data
    }
}
```

### AuthService

```swift
class AuthService {
    static let shared = AuthService()

    // POST /api/auth/send-code with {"email": "..."}
    func sendVerificationCode(email: String) async throws -> String

    // POST /api/auth/verify-code with {"email": "...", "code": "..."}
    // Saves access_token and refresh_token to Keychain
    func verifyCode(email: String, code: String) async throws -> AuthResponseData

    // POST /api/auth/refresh with {"refresh_token": "..."}
    func refreshToken() async throws -> String

    // POST /api/auth/logout, then clears Keychain tokens
    func logout() async throws

    // Checks if access_token exists in Keychain
    func isLoggedIn() -> Bool
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
│  OrbitApp    │ → WindowGroup with ContentView
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ ContentView │ ── Manages AppState enum
└──────┬──────┘
       │
       ├─── .auth ─────────────▶ AuthFlowView
       │                            │
       │                    .edu email entry
       │                            │
       │                    6-digit code verification
       │                            │
       ├─── .profileSetup ────▶ ProfileSetupView (5 steps)
       │                            │
       └─── .home ────────────▶ MainTabView
```

### Main Tab Bar

```
┌──────────────────────────────────────┐
│            MainTabView               │
├──────────────┬───────────────────────┤
│   Discover   │       Profile         │
└──────┬───────┴──────────┬────────────┘
       │                  │
       ▼                  ▼
  DiscoverView     ProfileDisplayView
  (cosmos UI)      (profile card)
       │                  │
       ▼                  ▼
  ProfileDetail    ProfileSetupView
  Sheet (modal)    (edit mode)
└──────────────────────────────────────┘
```

### Screen Inventory

| Tab | Screens | Purpose |
|-----|---------|---------|
| **Discover** | DiscoverView | Space-themed cosmos with orbiting user planets; tap to view profile sheet |
| **Profile** | ProfileDisplayView | View own profile with photo carousel, edit button |

---

## State Management

### App State (ContentView)

```swift
// ContentView.swift
enum AppState {
    case auth
    case profileSetup
    case home
}

struct ContentView: View {
    @State private var appState: AppState = .auth

    var body: some View {
        switch appState {
        case .auth:
            AuthFlowView(onAuthenticated: { isNewUser in
                if isNewUser {
                    appState = .profileSetup
                } else {
                    // Try to load existing profile
                    loadExistingProfile()
                }
            })
        case .profileSetup:
            ProfileSetupView(onComplete: { appState = .home })
        case .home:
            MainTabView(...)
        }
    }
}
```

### ViewModel State Patterns

```swift
// AuthViewModel - uses enum-based state
class AuthViewModel: ObservableObject {
    enum AuthState { case emailEntry, verification, authenticated }
    @Published var authState: AuthState = .emailEntry
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isNewUser = false
}

// ProfileViewModel - manages multi-step form
class ProfileViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var name = ""
    @Published var age: Double = 20
    @Published var city = ""
    @Published var state = ""
    @Published var bio = ""
    @Published var selectedInterests: Set<String> = []
    // ... personality sliders, social preferences, photos
    @Published var isLoading = false
    @Published var errorMessage: String?
}
```

---

## Error Handling

### NetworkError Enum

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)    // Server-provided error message
    case unauthorized
    case networkError(Error)    // Underlying URLSession error
}
```

### Standard ViewModel Pattern

```swift
func saveProfile() async {
    isLoading = true
    errorMessage = nil

    do {
        let profile = buildProfile()
        let response = try await ProfileService.shared.updateProfile(profile)
        // Handle success
    } catch let error as NetworkError {
        errorMessage = error.localizedDescription
    } catch {
        errorMessage = "Something went wrong. Please try again."
    }

    isLoading = false
}
```

---

## Constants

```swift
enum Constants {
    enum API {
        static let baseURL = "https://orbit-app-486204.wl.r.appspot.com/api"

        enum Endpoints {
            static let sendCode = "/auth/send-code"
            static let verifyCode = "/auth/verify-code"
            static let refreshToken = "/auth/refresh"
            static let logout = "/auth/logout"
            static let me = "/users/me"
            static let uploadPhoto = "/users/me/photo"
        }
    }

    enum Keychain {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
    }

    enum Validation {
        static let verificationCodeLength = 6
        static let minAge = 18
        static let maxAge = 100
        static let maxBioLength = 500
        static let minInterests = 3
        static let maxInterests = 10
        static let maxPhotos = 6
    }
}
```

### KeychainHelper

```swift
class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.orbit.app"

    func save(_ string: String, forKey key: String) -> Bool
    func readString(forKey key: String) -> String?
    func delete(forKey key: String) -> Bool
}
```
