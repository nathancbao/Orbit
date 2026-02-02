# Profile Creation Feature

## Overview

The Profile Creation feature allows new users to set up their Orbit profile through a guided 5-step flow. Users can also edit their existing profile at any time. This feature is fully functional on the client side with mock data, ready for server integration.

---

## User Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AUTH (Zodiac)                             │
│  Phone Entry → Verification Code → Success                       │
│  (Currently bypassed with Dev Mode button)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (if new user)
┌─────────────────────────────────────────────────────────────────┐
│                    PROFILE SETUP (5 Steps)                       │
├─────────────────────────────────────────────────────────────────┤
│  Step 1: Basic Info                                              │
│  ├── Name (required)                                             │
│  ├── Age (required, 18-100)                                      │
│  ├── City (required)                                             │
│  ├── State (required)                                            │
│  └── Bio (optional, max 500 chars)                               │
├─────────────────────────────────────────────────────────────────┤
│  Step 2: Personality                                             │
│  ├── Introvert ←──────→ Extrovert (slider)                       │
│  ├── Spontaneous ←────→ Planner (slider)                         │
│  └── Active ←─────────→ Relaxed (slider)                         │
├─────────────────────────────────────────────────────────────────┤
│  Step 3: Interests                                               │
│  ├── 20 predefined interests to choose from                      │
│  ├── Custom interest input field                                 │
│  └── Must select 3-10 interests                                  │
├─────────────────────────────────────────────────────────────────┤
│  Step 4: Social Preferences                                      │
│  ├── Preferred group size (radio buttons)                        │
│  ├── Meeting frequency (radio buttons)                           │
│  └── Preferred times (multi-select chips)                        │
├─────────────────────────────────────────────────────────────────┤
│  Step 5: Photos                                                  │
│  ├── Upload from Photo Library                                   │
│  ├── Import from Files (for testing)                             │
│  └── Optional, up to 6 photos                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PROFILE DISPLAY                               │
│  ├── Large photo carousel                                        │
│  │   └── Tap left/right to navigate photos                       │
│  ├── Name, Age, Location header                                  │
│  ├── Bio section                                                 │
│  ├── Interests (chips)                                           │
│  ├── Personality (visual bars)                                   │
│  ├── Social Preferences                                          │
│  └── [Edit] button → returns to Profile Setup                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
Orbit/
├── Models/
│   ├── User.swift              # User model with profile reference
│   ├── Profile.swift           # Profile, Location, Personality, etc.
│   └── APIResponse.swift       # API response wrappers
│
├── Views/
│   ├── Auth/
│   │   ├── PhoneEntryView.swift      # TODO: Zodiac
│   │   └── VerificationView.swift    # TODO: Zodiac
│   │
│   └── Profile/
│       ├── ProfileSetupView.swift    # 5-step setup flow
│       └── ProfileDisplayView.swift  # Tinder-style profile view
│
├── ViewModels/
│   ├── AuthViewModel.swift           # TODO: Zodiac
│   └── ProfileViewModel.swift        # Profile form state & logic
│
├── Services/
│   ├── APIService.swift              # HTTP networking layer
│   ├── AuthService.swift             # TODO: Zodiac
│   └── ProfileService.swift          # Profile API calls (mock ready)
│
├── Utils/
│   ├── Constants.swift               # URLs, validation rules
│   └── KeychainHelper.swift          # Secure token storage
│
└── ContentView.swift                 # Main app coordinator
```

---

## Data Models

### Profile
```swift
struct Profile: Codable {
    var name: String
    var age: Int
    var location: Location
    var bio: String
    var photos: [String]           // Photo URLs from server
    var interests: [String]        // Mix of predefined + custom
    var personality: Personality
    var socialPreferences: SocialPreferences
    var friendshipGoals: [String]
}
```

### Personality
```swift
struct Personality: Codable {
    var introvertExtrovert: Double    // 0.0 to 1.0
    var spontaneousPlanner: Double    // 0.0 to 1.0
    var activeRelaxed: Double         // 0.0 to 1.0
}
```

### SocialPreferences
```swift
struct SocialPreferences: Codable {
    var groupSize: String           // "One-on-one", "Small groups (3-5)", etc.
    var meetingFrequency: String    // "Weekly", "Bi-weekly", etc.
    var preferredTimes: [String]    // ["Evenings", "Weekends"]
}
```

---

## Validation Rules

| Field | Rule |
|-------|------|
| Name | Required, non-empty |
| Age | Required, 18-100 |
| City | Required, non-empty |
| State | Required, non-empty |
| Bio | Optional, max 500 characters |
| Interests | Required, 3-10 selections |
| Group Size | Required |
| Meeting Frequency | Required |
| Preferred Times | Required, at least 1 |
| Photos | Optional, max 6 |

---

## Key Components

### ProfileSetupView
Main container that manages the 5-step flow:
- Progress bar showing current step
- Step content (switches between step views)
- Back/Next navigation buttons
- Validation prevents advancing with incomplete data
- "Complete" button on final step saves profile

### ProfileViewModel
Holds all form state:
- `@Published` properties for each form field
- Validation computed properties (`isBasicInfoValid`, etc.)
- `buildProfile()` - converts form data to Profile model
- `saveProfile()` - async method to save via ProfileService

### ProfileDisplayView
Displays the completed profile:
- Large photo carousel with tap navigation
- Photo indicators (dots)
- Clean sections for all profile data
- Edit button returns to setup flow

---

## Integration Points

### Zodiac

When authentication succeeds:

```swift
// In your auth completion handler:
if response.isNewUser {
    // New user - needs to create profile
    appState = .profileSetup
} else {
    // Returning user - load their profile and go to home
    completedProfile = response.user.profile
    appState = .home
}
```

Files to implement:
- `AuthViewModel.swift` - see comments for suggested structure
- `AuthService.swift` - see comments for example implementations
- `PhoneEntryView.swift`
- `VerificationView.swift`

### For Rashmit

To enable real API calls:

1. Update `Constants.swift`:
```swift
static let baseURL = "https://your-actual-server.appspot.com/api/v1"
```

2. Update `ProfileService.swift`:
```swift
private let useMockData = false  // Change from true to false
```

API endpoints used:
- `PUT /users/me/profile` - Update profile
- `GET /users/me/profile` - Get profile

Expected response format:
```json
{
  "success": true,
  "data": {
    "profile": { ... },
    "profile_complete": true
  }
}
```

---

## Testing Instructions

### Running the App
1. Open `Orbit.xcodeproj` in Xcode
2. Select a simulator (iPhone 14 Pro recommended)
3. Press Run (⌘R)

### Testing Profile Creation
1. Tap "Skip to Profile Setup" (dev mode)
2. Fill out each step:
   - Step 1: Enter name, age, city, state
   - Step 2: Adjust personality sliders
   - Step 3: Select 3+ interests (try adding a custom one!)
   - Step 4: Select group size, frequency, and at least one time
   - Step 5: Optionally add photos
3. Tap "Complete"
4. View your profile with Tinder-style photo display

### Testing Photo Import
To add photos in the simulator:
1. Drag an image from your Mac onto the simulator
2. It saves to the Photos app
3. In the app, tap "Library" to select it

Or use "Files" button:
1. Save an image to simulator's Files app
2. Tap "Files" in the app to import

### Testing Edit Flow
1. Complete a profile
2. Tap "Edit" in the top right
3. All your data should be preserved
4. Make changes and tap "Complete"
5. Changes should appear on profile display

---

## Current Limitations

1. **No Persistence**: Profiles are lost when app closes (waiting for server)
2. **No Photo Upload**: Photos stored locally only (server needs upload endpoint)
3. **No Auth**: Using dev bypass (waiting for Zodiac)
4. **Mock Data**: ProfileService returns fake success (waiting for server)

---

## Future Enhancements

- [ ] Add location services for auto-detecting city/state
- [ ] Add photo cropping/editing
- [ ] Add profile strength indicator
- [ ] Add friendship goals step
- [ ] Add profile preview before completing
- [ ] Add onboarding tutorial for first-time users

