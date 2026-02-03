# Orbit Client Architecture

## Overview

Orbit is an iOS app that helps college students find friends through interest-based matching. Users authenticate with a .edu email, set up a detailed profile, and discover other users through an interactive solar system interface where they are the center of their own universe.

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
OrbitApp/Orbit/
├── OrbitApp.swift                 # @main app entry point
├── ContentView.swift              # Root navigation coordinator (AppState)
│
├── Models/
│   ├── APIResponse.swift          # API response wrappers (generic + specific)
│   ├── Profile.swift              # Profile, Location, Personality, SocialPreferences
│   └── User.swift                 # User model with profile completion tracking
│
├── Services/
│   ├── APIService.swift           # Base HTTP client (singleton)
│   ├── AuthService.swift          # Email auth, token management
│   ├── ProfileService.swift       # Profile CRUD + photo upload
│   └── DiscoverService.swift      # Fetch suggested profiles
│
├── Utils/
│   ├── Constants.swift            # API URLs, endpoints, validation rules
│   └── KeychainHelper.swift       # Secure token storage
│
├── ViewModels/
│   ├── AuthViewModel.swift        # Email verification flow state
│   └── ProfileViewModel.swift     # 5-step profile setup form management
│
└── Views/
    ├── MainTabView.swift          # Tab bar (Discover + Profile)
    │
    ├── Auth/
    │   ├── AuthFlowView.swift     # Email entry + code verification
    │   ├── PhoneEntryView.swift   # Placeholder (unused)
    │   └── VerificationView.swift # Placeholder (unused)
    │
    ├── Discover/
    │   └── DiscoverView.swift     # Solar system discovery interface
    │                              # Contains: Star, YourPlanet, UserPlanet,
    │                              # ProfileDetailSheet, InfoChip, FlowLayout
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
│                    (SwiftUI Views)                          │
│  Display UI, capture user input, observe ViewModel state    │
└─────────────────────────┬───────────────────────────────────┘
                          │ @StateObject / @State
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      VIEWMODELS                             │
│              (@Observable / ObservableObject)               │
│  Handle UI logic, transform data, manage view state         │
└─────────────────────────┬───────────────────────────────────┘
                          │ async/await calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       SERVICES                              │
│                    (Singletons)                             │
│  Make API calls, handle auth, manage Keychain tokens        │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP requests (URLSession)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      FLASK API                              │
│       (orbit-app-486204.wl.r.appspot.com/api)               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Example: Profile Save

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

### 1. Views Layer (`Views/`)

Views are SwiftUI structs that display UI and respond to state changes.

| Folder | Views | Purpose |
|--------|-------|---------|
| `Auth/` | AuthFlowView | .edu email entry and 6-digit code verification |
| `Discover/` | DiscoverView | Solar system interface with orbiting user planets |
| `Profile/` | ProfileSetupView, ProfileDisplayView | 5-step profile creation and profile card display |
| Root | MainTabView | Tab bar with Discover and Profile tabs |

---

#### AuthFlowView

Handles both email entry and code verification in a single view, switching between states based on `AuthViewModel.authState`. Uses a dark blue gradient background.

**States:**
- `emailEntry` - User enters their .edu email address
- `verification` - User enters the 6-digit code sent to their email

---

#### DiscoverView - Solar System Interface

The flagship discovery feature. Users explore potential friends through an immersive space-themed solar system where they are at the center.

**Visual Components:**

| Component | Description |
|-----------|-------------|
| **Space Background** | Deep space gradient (dark blue → purple → black) with 100 randomly generated animated stars |
| **Orbit Rings** | 3 concentric decorative circles centered on the user, providing visual structure |
| **YourPlanet** | The user's planet at the center - a blue/purple gradient sphere labeled "YOU" with a pulsing glow animation |
| **UserPlanet** | Other users appear as colorful planets orbiting around the center. Each planet displays the user's first initial |
| **ProfileDetailSheet** | Modal sheet that appears when tapping a planet, showing full profile details |

**Key Implementation Details:**

```swift
// Star model for background
struct Star: Identifiable {
    let id: UUID
    let position: CGPoint
    let size: CGFloat        // 1-3 points
    let opacity: Double      // 0.3-1.0
}

// YourPlanet - center of the solar system
struct YourPlanet: View {
    let size: CGFloat        // 90pt default
    // Pulsing glow animation that repeats forever
    // Blue/purple gradient fill
    // "YOU" label below
}

// UserPlanet - other users in orbit
struct UserPlanet: View {
    let profile: Profile
    let size: CGFloat        // 70pt default
    // Color determined by hash of name (consistent across sessions)
    // Displays first initial of name
    // Gentle hover animation with deterministic timing
    // Name label below planet
}
```

**Planet Positioning Algorithm:**
- Planets are distributed evenly around the center using angular spacing
- Deterministic jitter based on index prevents perfect circular arrangement
- Position caching prevents planets from moving on re-render
- Radius varies slightly per planet for natural appearance

**Color Assignment:**
```swift
// 8 planet colors assigned based on name hash
let colors: [Color] = [.orange, .pink, .green, .yellow, .red, .mint, .cyan, .indigo]
let index = abs(profile.name.hashValue) % colors.count
```

**ProfileDetailSheet Contents:**
- Photo display (or gradient placeholder with initial)
- Name, age, location header with gradient overlay
- Bio section
- Interests displayed as chips using FlowLayout
- Social style info (group size, meeting frequency)
- "Connect" button (connection logic TODO)

---

#### ProfileSetupView

A multi-step form with 5 steps, each validated before allowing progression:

| Step | Name | Fields | Validation |
|------|------|--------|------------|
| 1 | BasicInfoStep | Name, age, city, state, bio | Name required, age 18-100, city & state required |
| 2 | PersonalityStep | 3 personality sliders | Always valid (sliders have defaults) |
| 3 | InterestsStep | Predefined chips + custom interests | Min 3, max 10 interests |
| 4 | SocialPreferencesStep | Group size, frequency, preferred times | All fields required |
| 5 | PhotoUploadStep | Up to 6 photos | Optional (0-6 photos allowed) |

**Personality Sliders:**
- Introvert ↔ Extrovert (0.0 - 1.0)
- Spontaneous ↔ Planner (0.0 - 1.0)
- Active ↔ Relaxed (0.0 - 1.0)

**Interest Categories (Predefined):**
Sports & Fitness, Music, Art & Design, Technology, Food & Cooking, Travel, Gaming, Reading, Movies & TV, Photography, Nature, Fashion, Dancing, Volunteering, Entrepreneurship, Podcasts, Board Games, Languages, Meditation, DIY & Crafts

---

#### ProfileDisplayView

Shows a profile card with:
- **Photo carousel** - Swipeable with dot indicators
- **Header** - Name, age, location
- **Bio section**
- **Interests** - Tags in a flow layout
- **Personality bars** - Visual representation of the 3 traits
- **Social preferences** - Group size, frequency, preferred times
- **Edit button** - Returns to ProfileSetupView in edit mode

---

### 2. ViewModels Layer (`ViewModels/`)

| ViewModel | Responsibility |
|-----------|---------------|
| `AuthViewModel` | .edu email validation, send/verify code flow, auth state management |
| `ProfileViewModel` | 5-step form data, step validation, interest management, photo selection, profile save |

#### AuthViewModel

Manages an `AuthState` enum and handles the complete auth flow.

```swift
class AuthViewModel: ObservableObject {
    enum AuthState {
        case emailEntry
        case verification
        case authenticated
    }

    @Published var authState: AuthState = .emailEntry
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isNewUser = false
    @Published var userId: Int?
}
```

**Key Features:**
- Validates emails end in `.edu`
- Validates verification code is exactly 6 digits
- Supports demo bypass with code `"123456"`
- Stores tokens to Keychain on successful verification

#### ProfileViewModel

Manages all form fields across the 5 setup steps.

```swift
class ProfileViewModel: ObservableObject {
    @Published var currentStep = 0

    // Step 1: Basic Info
    @Published var name = ""
    @Published var age: Double = 20
    @Published var city = ""
    @Published var state = ""
    @Published var bio = ""

    // Step 2: Personality (0.0 - 1.0 sliders)
    @Published var introvertExtrovert: Double = 0.5
    @Published var spontaneousPlanner: Double = 0.5
    @Published var activeRelaxed: Double = 0.5

    // Step 3: Interests
    @Published var selectedInterests: Set<String> = []
    @Published var customInterest = ""

    // Step 4: Social Preferences
    @Published var selectedGroupSize = ""
    @Published var selectedFrequency = ""
    @Published var selectedTimes: Set<String> = []

    // Step 5: Photos
    @Published var selectedPhotos: [PhotoItem] = []

    // State
    @Published var isLoading = false
    @Published var errorMessage: String?
}
```

**Key Methods:**
- `isCurrentStepValid` - Computed property checking current step's validation
- `addCustomInterest()` - Adds user-typed interest to selection
- `buildProfile()` - Converts form state into a `Profile` struct
- `saveProfile()` - Uploads photos first, then sends profile to server
- `init(existingProfile:)` - Pre-populates form for editing

**PhotoItem Wrapper:**
```swift
struct PhotoItem: Identifiable {
    let id: UUID
    var image: UIImage?
    var isLoading: Bool
}
```

---

### 3. Services Layer (`Services/`)

Services are singletons accessed via `.shared`.

| Service | Responsibility |
|---------|---------------|
| `APIService` | Generic HTTP request handler with JSON encoding/decoding, auth token injection |
| `AuthService` | Send verification code to email, verify code, refresh token, logout |
| `ProfileService` | Get and update user profile, upload photos |
| `DiscoverService` | Fetch suggested profiles for discovery |

#### APIService (Base Networking)

Foundation for all network calls.

```swift
class APIService {
    static let shared = APIService()

    private let baseURL = "https://orbit-app-486204.wl.r.appspot.com/api"

    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = false
    ) async throws -> T
}
```

**Key Features:**
- Generic `request<T: Codable>()` method for all HTTP calls
- Automatic snake_case ↔ camelCase conversion via JSONEncoder/Decoder strategies
- Bearer token injection from Keychain when `authenticated: true`
- Decodes server responses from `{ "success": true, "data": {...} }` wrapper
- Custom `NetworkError` enum for error handling

#### AuthService

```swift
class AuthService {
    static let shared = AuthService()

    // POST /api/auth/send-code
    func sendVerificationCode(email: String) async throws -> String

    // POST /api/auth/verify-code (saves tokens to Keychain)
    func verifyCode(email: String, code: String) async throws -> AuthResponseData

    // POST /api/auth/refresh
    func refreshToken() async throws -> String

    // POST /api/auth/logout (clears Keychain)
    func logout() async throws

    // Check if access_token exists in Keychain
    func isLoggedIn() -> Bool
}
```

#### ProfileService

```swift
class ProfileService {
    static let shared = ProfileService()
    var useMockData = false  // Toggle for development

    // GET /api/users/me
    func getProfile() async throws -> ProfileResponseData

    // PUT /api/users/me
    func updateProfile(_ profile: Profile) async throws -> ProfileResponseData

    // POST /api/users/me/photo (multipart/form-data)
    func uploadPhoto(_ image: UIImage) async throws -> String  // Returns URL
}
```

#### DiscoverService

```swift
class DiscoverService {
    static let shared = DiscoverService()
    var useMockData = true  // Currently uses mock data

    // GET /api/discover/users
    func getDiscoverProfiles() async throws -> [Profile]
}
```

**Mock Profiles (5 total):** Used for testing without backend. Includes varied demographics, interests, and personality traits.

---

### 4. Models Layer (`Models/`)

#### API Response Wrappers

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
    let userId: Int               // "user_id"
}

struct ProfileResponseData: Codable {
    let profile: Profile
    let profileComplete: Bool     // "profile_complete"
}
```

#### Profile

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
    var socialPreferences: SocialPreferences
    var friendshipGoals: [String]
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
    var introvertExtrovert: Double    // 0.0 = Introvert, 1.0 = Extrovert
    var spontaneousPlanner: Double    // 0.0 = Spontaneous, 1.0 = Planner
    var activeRelaxed: Double         // 0.0 = Active, 1.0 = Relaxed
}

struct SocialPreferences: Codable {
    var groupSize: String             // "One-on-one", "Small groups (3-5)", etc.
    var meetingFrequency: String      // "Weekly", "Bi-weekly", "Monthly", "Flexible"
    var preferredTimes: [String]      // ["Mornings", "Afternoons", "Evenings", "Weekends"]
}
```

#### User

```swift
struct User: Codable, Identifiable {
    let id: String
    let phoneNumber: String       // Legacy field (now stores email)
    let profileComplete: Bool
    let createdAt: Date
    let profile: Profile?
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
│  OrbitApp   │ → WindowGroup with ContentView
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
│   (globe)    │      (person)         │
└──────┬───────┴──────────┬────────────┘
       │                  │
       ▼                  ▼
  DiscoverView     ProfileDisplayView
  (solar system)   (profile card)
       │                  │
       ▼                  ▼
  ProfileDetail    ProfileSetupView
  Sheet (modal)    (edit mode)
```

### Screen Inventory

| Tab | Screen | Purpose |
|-----|--------|---------|
| **Discover** | DiscoverView | Solar system with user at center, other users as orbiting planets |
| **Discover** | ProfileDetailSheet | Modal showing full profile when planet is tapped |
| **Profile** | ProfileDisplayView | View own profile with photo carousel |
| **Profile** | ProfileSetupView | Edit profile (same view as initial setup) |

---

## State Management

### App State (ContentView)

```swift
enum AppState {
    case auth           // Not logged in
    case profileSetup   // Logged in but profile incomplete
    case home           // Logged in with complete profile
}

struct ContentView: View {
    @State private var appState: AppState = .auth
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var userProfile: Profile?

    var body: some View {
        switch appState {
        case .auth:
            AuthFlowView(...)
        case .profileSetup:
            ProfileSetupView(...)
        case .home:
            MainTabView(...)
        }
    }
}
```

**State Transitions:**
- `.auth` → `.profileSetup`: On successful auth with `isNewUser = true`
- `.auth` → `.home`: On successful auth with existing complete profile
- `.profileSetup` → `.home`: On successful profile save
- `.home` → `.profileSetup`: When user taps Edit on ProfileDisplayView
- Any → `.auth`: On logout

---

## Error Handling

### NetworkError Enum

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)    // Server-provided error message
    case unauthorized           // 401 response
    case networkError(Error)    // Underlying URLSession error

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingError: return "Failed to decode response"
        case .serverError(let message): return message
        case .unauthorized: return "Please log in again"
        case .networkError(let error): return error.localizedDescription
        }
    }
}
```

### Standard ViewModel Error Pattern

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
            static let discoverUsers = "/discover/users"
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

---

## UI Components

### FlowLayout

A custom layout for wrapping content (used for interest tags and time chips):

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    // Arranges subviews in rows, wrapping to next line when needed
}
```

### InfoChip

Small labeled badge for displaying social preferences:

```swift
struct InfoChip: View {
    let label: String
    let icon: String  // SF Symbol name
}
```

---

## Future Considerations

1. **Connection System** - The "Connect" button in ProfileDetailSheet needs backend implementation
2. **Real-time Updates** - Consider WebSocket for live discovery updates
3. **Matching Algorithm** - Backend should rank planets by compatibility (closer = more compatible)
4. **Notifications** - Push notifications for new connections
5. **Messaging** - In-app messaging between connected users
6. **Crews & Missions** - Group features as described in overview.md
