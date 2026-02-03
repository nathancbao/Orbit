//
//  ProfileViewModel.swift
//  Orbit
//
//  PROFILE VIEW MODEL
//  Manages all the data and logic for the profile setup flow.
//  This is the "brain" behind ProfileSetupView.
//
//  KEY CONCEPTS:
//  - @Published properties automatically update the UI when changed
//  - Validation computed properties control when user can proceed
//  - buildProfile() converts the form data into a Profile model for saving
//
//  USAGE:
//  - ProfileSetupView creates this as a @StateObject
//  - Each step in the setup flow reads/writes to these properties
//  - When user taps "Complete", saveProfile() is called
//

import Foundation
import Combine
import SwiftUI
import PhotosUI

// MARK: - Photo Item
// Wrapper for photos being uploaded
// Tracks loading state for async photo loading from picker
struct PhotoItem: Identifiable {
    let id = UUID()
    var image: UIImage?
    var isLoading: Bool = false
}

// MARK: - Profile View Model
@MainActor  // Ensures all updates happen on main thread (required for UI)
class ProfileViewModel: ObservableObject {

    // ============================================================
    // MARK: - Published Properties (Form Data)
    // These are bound to UI elements in ProfileSetupView
    // Changing these automatically updates the UI
    // ============================================================

    // Step 1: Basic Info
    @Published var name: String = ""
    @Published var age: Int = 18
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var bio: String = ""

    // Step 2: Personality (slider values from 0.0 to 1.0)
    @Published var introvertExtrovert: Double = 0.5   // 0 = introvert, 1 = extrovert
    @Published var spontaneousPlanner: Double = 0.5   // 0 = spontaneous, 1 = planner
    @Published var activeRelaxed: Double = 0.5        // 0 = active, 1 = relaxed

    // Step 3: Interests (includes both predefined and custom)
    @Published var selectedInterests: Set<String> = []

    // Step 4: Social Preferences
    @Published var groupSize: String = "Small groups (3-5)"
    @Published var meetingFrequency: String = "Weekly"
    @Published var preferredTimes: Set<String> = []

    // Step 5: Photos
    @Published var selectedPhotos: [PhotoItem] = []

    // ============================================================
    // MARK: - State Properties
    // Track loading and error states for UI feedback
    // ============================================================

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var profileSaved: Bool = false  // Triggers navigation when true

    // ============================================================
    // MARK: - Initialization
    // ============================================================

    // Default initializer - for new users
    init() {}

    // Initializer with existing data - for editing profiles
    // Called when user taps "Edit" on their profile
    init(profile: Profile, photos: [UIImage]) {
        self.name = profile.name
        self.age = profile.age
        self.city = profile.location.city
        self.state = profile.location.state
        self.bio = profile.bio
        self.introvertExtrovert = profile.personality.introvertExtrovert
        self.spontaneousPlanner = profile.personality.spontaneousPlanner
        self.activeRelaxed = profile.personality.activeRelaxed
        self.selectedInterests = Set(profile.interests)
        self.groupSize = profile.socialPreferences.groupSize
        self.meetingFrequency = profile.socialPreferences.meetingFrequency
        self.preferredTimes = Set(profile.socialPreferences.preferredTimes)
        // Convert UIImages to PhotoItems
        self.selectedPhotos = photos.map { image in
            var item = PhotoItem()
            item.image = image
            return item
        }
    }

    // ============================================================
    // MARK: - Validation
    // These computed properties determine if user can proceed to next step
    // Used by ProfileSetupView to enable/disable the "Next" button
    // ============================================================

    var isBasicInfoValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        age >= Constants.Validation.minAge &&
        age <= Constants.Validation.maxAge &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty &&
        !state.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isInterestsValid: Bool {
        selectedInterests.count >= Constants.Validation.minInterests &&
        selectedInterests.count <= Constants.Validation.maxInterests
    }

    var isSocialPreferencesValid: Bool {
        !groupSize.isEmpty &&
        !meetingFrequency.isEmpty &&
        !preferredTimes.isEmpty
    }

    var isPhotosValid: Bool {
        true  // Photos are optional
    }

    // Overall validation - all required steps must be valid
    var isProfileComplete: Bool {
        isBasicInfoValid && isInterestsValid && isSocialPreferencesValid
    }

    // ============================================================
    // MARK: - Helper Methods
    // ============================================================

    // Returns a description of personality trait based on slider value
    func personalityDescription(for value: Double, low: String, high: String) -> String {
        if value < 0.33 {
            return "More \(low)"
        } else if value > 0.66 {
            return "More \(high)"
        } else {
            return "Balanced"
        }
    }

    // ============================================================
    // MARK: - Profile Building & Saving
    // ============================================================

    // Converts all form data into a Profile model
    // Called when saving or when passing data to ProfileDisplayView
    func buildProfile() -> Profile {
        return Profile(
            name: name.trimmingCharacters(in: .whitespaces),
            age: age,
            location: Location(
                city: city.trimmingCharacters(in: .whitespaces),
                state: state.trimmingCharacters(in: .whitespaces),
                coordinates: nil  // Could add location services later
            ),
            bio: bio.trimmingCharacters(in: .whitespaces),
            photos: [],  // Photo URLs would come from server after upload
            interests: Array(selectedInterests),
            personality: Personality(
                introvertExtrovert: introvertExtrovert,
                spontaneousPlanner: spontaneousPlanner,
                activeRelaxed: activeRelaxed
            ),
            socialPreferences: SocialPreferences(
                groupSize: groupSize,
                meetingFrequency: meetingFrequency,
                preferredTimes: Array(preferredTimes)
            ),
            friendshipGoals: []  // Could add this step later
        )
    }

    // Saves profile to server (or mock)
    // Called when user taps "Complete" on final step
    func saveProfile() async {
        // Validate before saving
        guard isProfileComplete else {
            errorMessage = "Please complete all required fields"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let profile = buildProfile()
            // ProfileService handles mock vs real API based on useMockData flag
            let response = try await ProfileService.shared.updateProfile(profile)

            if response.profileComplete {
                profileSaved = true  // This triggers navigation to home
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    // Loads existing profile from server (for returning users)
    // Not currently used since we pass profile data directly
    func loadExistingProfile() async {
        isLoading = true

        do {
            let profile = try await ProfileService.shared.getProfile()
            populateFromProfile(profile)
        } catch {
            // New user, no existing profile - that's fine
        }

        isLoading = false
    }

    // Populates form fields from a Profile model
    private func populateFromProfile(_ profile: Profile) {
        name = profile.name
        age = profile.age
        city = profile.location.city
        state = profile.location.state
        bio = profile.bio
        introvertExtrovert = profile.personality.introvertExtrovert
        spontaneousPlanner = profile.personality.spontaneousPlanner
        activeRelaxed = profile.personality.activeRelaxed
        selectedInterests = Set(profile.interests)
        groupSize = profile.socialPreferences.groupSize
        meetingFrequency = profile.socialPreferences.meetingFrequency
        preferredTimes = Set(profile.socialPreferences.preferredTimes)
    }
}
