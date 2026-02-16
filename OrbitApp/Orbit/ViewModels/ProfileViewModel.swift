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

// MARK: - Quiz Types

enum QuizQuestionType {
    case scenario   // "Would you rather" style — pick one of 4 options
    case rating     // 1–7 Likert scale
}

struct DimensionWeight {
    let dimension: String
    let weight: Double   // positive = high end, negative = inverted
}

struct QuizAnswerOption: Identifiable {
    let id = UUID()
    let text: String
    let dimensionWeights: [DimensionWeight]
}

struct QuizQuestion: Identifiable {
    let id: Int
    let text: String
    let type: QuizQuestionType
    let options: [QuizAnswerOption]           // scenario only
    let ratingDimension: DimensionWeight?     // rating only
}

struct QuizAnswer {
    var selectedOptionIndex: Int?   // scenario
    var ratingValue: Int?           // 1–7 rating
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
    // MARK: - Vibe Check Quiz Data
    // ============================================================
    @Published var quizAnswers: [Int: QuizAnswer] = [:]
    @Published var vibeCheckPersonality: [String: Double] = [:]
    @Published var derivedMBTI: String = ""

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
        // Load existing vibe check data if available
        if let vc = profile.vibeCheck {
            self.vibeCheckPersonality = [
                "introvert_extrovert": vc.introvertExtrovert,
                "spontaneous_planner": vc.spontaneousPlanner,
                "active_relaxed": vc.activeRelaxed,
                "adventurous_cautious": vc.adventurousCautious,
                "expressive_reserved": vc.expressiveReserved,
                "independent_collaborative": vc.independentCollaborative,
                "sensing_intuition": vc.sensingIntuition,
                "thinking_feeling": vc.thinkingFeeling,
            ]
            self.derivedMBTI = vc.mbtiType
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
    // MARK: - Quiz Validation & Computation
    // ============================================================

    var isVibeCheckComplete: Bool {
        quizAnswers.count == Self.quizQuestions.count &&
        quizAnswers.allSatisfy { _, answer in
            answer.selectedOptionIndex != nil || answer.ratingValue != nil
        }
    }

    /// Compute the 8-dimension personality from quiz answers + derive MBTI
    func computeVibeCheck() {
        var dimensionSums: [String: Double] = [:]
        var dimensionCounts: [String: Int] = [:]

        for question in Self.quizQuestions {
            guard let answer = quizAnswers[question.id] else { continue }

            if question.type == .scenario, let idx = answer.selectedOptionIndex {
                let option = question.options[idx]
                for dw in option.dimensionWeights {
                    dimensionSums[dw.dimension, default: 0.0] += dw.weight
                    dimensionCounts[dw.dimension, default: 0] += 1
                }
            } else if question.type == .rating, let rating = answer.ratingValue,
                      let dw = question.ratingDimension {
                // Map 1–7 to 0.0–1.0: (rating - 1) / 6
                var value = Double(rating - 1) / 6.0
                if dw.weight < 0 { value = 1.0 - value }  // inverted
                dimensionSums[dw.dimension, default: 0.0] += value
                dimensionCounts[dw.dimension, default: 0] += 1
            }
        }

        // Average per dimension, clamp to [0, 1]
        var result: [String: Double] = [:]
        for (dim, sum) in dimensionSums {
            let count = dimensionCounts[dim, default: 1]
            result[dim] = min(1.0, max(0.0, sum / Double(count)))
        }
        vibeCheckPersonality = result

        // Derive MBTI
        let ie = result["introvert_extrovert"] ?? 0.5
        let sn = result["sensing_intuition"] ?? 0.5
        let tf = result["thinking_feeling"] ?? 0.5
        let jp = result["spontaneous_planner"] ?? 0.5

        let e_i = ie >= 0.5 ? "E" : "I"
        let s_n = sn >= 0.5 ? "N" : "S"
        let t_f = tf >= 0.5 ? "F" : "T"
        let j_p = jp >= 0.5 ? "J" : "P"

        derivedMBTI = "\(e_i)\(s_n)\(t_f)\(j_p)"
    }

    // ============================================================
    // MARK: - 22 Quiz Questions
    // ============================================================

    static let quizQuestions: [QuizQuestion] = [
        // ── Scenario Questions (1–12) ──────────────────────────────

        // Q1: introvert_extrovert
        QuizQuestion(id: 1, text: "It's Friday night and you have no plans. What sounds best?", type: .scenario, options: [
            QuizAnswerOption(text: "Host a party or hit the town with friends", dimensionWeights: [DimensionWeight(dimension: "introvert_extrovert", weight: 1.0)]),
            QuizAnswerOption(text: "Grab dinner with a small group", dimensionWeights: [DimensionWeight(dimension: "introvert_extrovert", weight: 0.7)]),
            QuizAnswerOption(text: "Chill at home with one close friend", dimensionWeights: [DimensionWeight(dimension: "introvert_extrovert", weight: 0.3)]),
            QuizAnswerOption(text: "Solo night in — movie, book, or games", dimensionWeights: [DimensionWeight(dimension: "introvert_extrovert", weight: 0.0)]),
        ], ratingDimension: nil),

        // Q2: spontaneous_planner
        QuizQuestion(id: 2, text: "A friend texts: \"Road trip this weekend!\" You...", type: .scenario, options: [
            QuizAnswerOption(text: "Already packing — let's go!", dimensionWeights: [DimensionWeight(dimension: "spontaneous_planner", weight: 0.0)]),
            QuizAnswerOption(text: "Sounds fun, I'll figure it out on the way", dimensionWeights: [DimensionWeight(dimension: "spontaneous_planner", weight: 0.2)]),
            QuizAnswerOption(text: "Need a few details first — where and when?", dimensionWeights: [DimensionWeight(dimension: "spontaneous_planner", weight: 0.7)]),
            QuizAnswerOption(text: "I'd need to plan ahead — maybe next time", dimensionWeights: [DimensionWeight(dimension: "spontaneous_planner", weight: 1.0)]),
        ], ratingDimension: nil),

        // Q3: active_relaxed
        QuizQuestion(id: 3, text: "You have a free Saturday. What are you doing?", type: .scenario, options: [
            QuizAnswerOption(text: "Gym, hike, or a pickup game", dimensionWeights: [DimensionWeight(dimension: "active_relaxed", weight: 0.0)]),
            QuizAnswerOption(text: "Exploring the city or trying something new", dimensionWeights: [DimensionWeight(dimension: "active_relaxed", weight: 0.3)]),
            QuizAnswerOption(text: "Catching up on errands and hobbies at home", dimensionWeights: [DimensionWeight(dimension: "active_relaxed", weight: 0.7)]),
            QuizAnswerOption(text: "Full couch mode — recharging all day", dimensionWeights: [DimensionWeight(dimension: "active_relaxed", weight: 1.0)]),
        ], ratingDimension: nil),

        // Q4: adventurous_cautious
        QuizQuestion(id: 4, text: "Your friend signs you up for skydiving or karaoke night. You...", type: .scenario, options: [
            QuizAnswerOption(text: "YOLO — I'm in for anything wild", dimensionWeights: [DimensionWeight(dimension: "adventurous_cautious", weight: 0.0)]),
            QuizAnswerOption(text: "I'd try it, but I need a pep talk first", dimensionWeights: [DimensionWeight(dimension: "adventurous_cautious", weight: 0.3)]),
            QuizAnswerOption(text: "I'd watch and cheer — not my thing", dimensionWeights: [DimensionWeight(dimension: "adventurous_cautious", weight: 0.7)]),
            QuizAnswerOption(text: "Hard pass — I like my comfort zone", dimensionWeights: [DimensionWeight(dimension: "adventurous_cautious", weight: 1.0)]),
        ], ratingDimension: nil),

        // Q5: adventurous_cautious + spontaneous_planner
        QuizQuestion(id: 5, text: "At a new restaurant, how do you order?", type: .scenario, options: [
            QuizAnswerOption(text: "\"Surprise me\" — chef's choice or the weirdest thing", dimensionWeights: [
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.0),
                DimensionWeight(dimension: "spontaneous_planner", weight: 0.0),
            ]),
            QuizAnswerOption(text: "Something I've never tried before", dimensionWeights: [
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.2),
                DimensionWeight(dimension: "spontaneous_planner", weight: 0.3),
            ]),
            QuizAnswerOption(text: "I check reviews first, then pick something solid", dimensionWeights: [
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.7),
                DimensionWeight(dimension: "spontaneous_planner", weight: 0.8),
            ]),
            QuizAnswerOption(text: "My go-to — why risk it?", dimensionWeights: [
                DimensionWeight(dimension: "adventurous_cautious", weight: 1.0),
                DimensionWeight(dimension: "spontaneous_planner", weight: 1.0),
            ]),
        ], ratingDimension: nil),

        // Q6: expressive_reserved
        QuizQuestion(id: 6, text: "Something is bothering you about a friend. You...", type: .scenario, options: [
            QuizAnswerOption(text: "Bring it up right away — honesty is everything", dimensionWeights: [DimensionWeight(dimension: "expressive_reserved", weight: 0.0)]),
            QuizAnswerOption(text: "Wait for the right moment, then talk it out", dimensionWeights: [DimensionWeight(dimension: "expressive_reserved", weight: 0.3)]),
            QuizAnswerOption(text: "Drop hints and hope they pick up on it", dimensionWeights: [DimensionWeight(dimension: "expressive_reserved", weight: 0.7)]),
            QuizAnswerOption(text: "Keep it to myself — it'll probably pass", dimensionWeights: [DimensionWeight(dimension: "expressive_reserved", weight: 1.0)]),
        ], ratingDimension: nil),

        // Q7: expressive_reserved + introvert_extrovert
        QuizQuestion(id: 7, text: "At a party where you don't know many people, you...", type: .scenario, options: [
            QuizAnswerOption(text: "Work the room — I love meeting new people", dimensionWeights: [
                DimensionWeight(dimension: "expressive_reserved", weight: 0.0),
                DimensionWeight(dimension: "introvert_extrovert", weight: 1.0),
            ]),
            QuizAnswerOption(text: "Find one person and have a deep conversation", dimensionWeights: [
                DimensionWeight(dimension: "expressive_reserved", weight: 0.3),
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.4),
            ]),
            QuizAnswerOption(text: "Stick close to whoever I came with", dimensionWeights: [
                DimensionWeight(dimension: "expressive_reserved", weight: 0.7),
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.2),
            ]),
            QuizAnswerOption(text: "Find the dog or a quiet corner", dimensionWeights: [
                DimensionWeight(dimension: "expressive_reserved", weight: 1.0),
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.0),
            ]),
        ], ratingDimension: nil),

        // Q8: independent_collaborative
        QuizQuestion(id: 8, text: "In a group project, you naturally...", type: .scenario, options: [
            QuizAnswerOption(text: "Take charge and delegate tasks", dimensionWeights: [DimensionWeight(dimension: "independent_collaborative", weight: 0.3)]),
            QuizAnswerOption(text: "Collaborate and brainstorm together", dimensionWeights: [DimensionWeight(dimension: "independent_collaborative", weight: 1.0)]),
            QuizAnswerOption(text: "Do my part independently and merge at the end", dimensionWeights: [DimensionWeight(dimension: "independent_collaborative", weight: 0.0)]),
            QuizAnswerOption(text: "Go with the flow and support the team", dimensionWeights: [DimensionWeight(dimension: "independent_collaborative", weight: 0.7)]),
        ], ratingDimension: nil),

        // Q9: independent_collaborative + active_relaxed
        QuizQuestion(id: 9, text: "\"Would you rather...\" for a weekend activity?", type: .scenario, options: [
            QuizAnswerOption(text: "Run a marathon or hike a mountain", dimensionWeights: [
                DimensionWeight(dimension: "independent_collaborative", weight: 0.2),
                DimensionWeight(dimension: "active_relaxed", weight: 0.0),
            ]),
            QuizAnswerOption(text: "Join a casual kickball league", dimensionWeights: [
                DimensionWeight(dimension: "independent_collaborative", weight: 0.8),
                DimensionWeight(dimension: "active_relaxed", weight: 0.3),
            ]),
            QuizAnswerOption(text: "Start a podcast with friends", dimensionWeights: [
                DimensionWeight(dimension: "independent_collaborative", weight: 0.9),
                DimensionWeight(dimension: "active_relaxed", weight: 0.7),
            ]),
            QuizAnswerOption(text: "Movie night — cozy and chill", dimensionWeights: [
                DimensionWeight(dimension: "independent_collaborative", weight: 0.5),
                DimensionWeight(dimension: "active_relaxed", weight: 1.0),
            ]),
        ], ratingDimension: nil),

        // Q10: introvert_extrovert + adventurous_cautious
        QuizQuestion(id: 10, text: "Your ideal vacation looks like...", type: .scenario, options: [
            QuizAnswerOption(text: "Backpacking through a new country with friends", dimensionWeights: [
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.9),
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.0),
            ]),
            QuizAnswerOption(text: "A group trip to a beach resort", dimensionWeights: [
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.7),
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.5),
            ]),
            QuizAnswerOption(text: "Solo trip to a cozy cabin", dimensionWeights: [
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.1),
                DimensionWeight(dimension: "adventurous_cautious", weight: 0.6),
            ]),
            QuizAnswerOption(text: "Staycation — my bed is the destination", dimensionWeights: [
                DimensionWeight(dimension: "introvert_extrovert", weight: 0.0),
                DimensionWeight(dimension: "adventurous_cautious", weight: 1.0),
            ]),
        ], ratingDimension: nil),

        // Q11: thinking_feeling
        QuizQuestion(id: 11, text: "A friend is upset about a bad grade. You...", type: .scenario, options: [
            QuizAnswerOption(text: "Listen and comfort them — feelings first", dimensionWeights: [DimensionWeight(dimension: "thinking_feeling", weight: 1.0)]),
            QuizAnswerOption(text: "Validate their feelings, then offer advice", dimensionWeights: [DimensionWeight(dimension: "thinking_feeling", weight: 0.7)]),
            QuizAnswerOption(text: "Help them figure out what went wrong", dimensionWeights: [DimensionWeight(dimension: "thinking_feeling", weight: 0.3)]),
            QuizAnswerOption(text: "Give them a study plan to ace the next one", dimensionWeights: [DimensionWeight(dimension: "thinking_feeling", weight: 0.0)]),
        ], ratingDimension: nil),

        // Q12: sensing_intuition
        QuizQuestion(id: 12, text: "When learning something new, you prefer...", type: .scenario, options: [
            QuizAnswerOption(text: "Step-by-step instructions and hands-on practice", dimensionWeights: [DimensionWeight(dimension: "sensing_intuition", weight: 0.0)]),
            QuizAnswerOption(text: "Real examples and case studies", dimensionWeights: [DimensionWeight(dimension: "sensing_intuition", weight: 0.3)]),
            QuizAnswerOption(text: "Understanding the big picture first", dimensionWeights: [DimensionWeight(dimension: "sensing_intuition", weight: 0.7)]),
            QuizAnswerOption(text: "Diving into theory and exploring connections", dimensionWeights: [DimensionWeight(dimension: "sensing_intuition", weight: 1.0)]),
        ], ratingDimension: nil),

        // ── Rating Questions (13–22) ───────────────────────────────

        // Q13: introvert_extrovert
        QuizQuestion(id: 13, text: "I recharge by being around people.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "introvert_extrovert", weight: 1.0)),

        // Q14: spontaneous_planner
        QuizQuestion(id: 14, text: "I usually have my week planned in advance.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "spontaneous_planner", weight: 1.0)),

        // Q15: active_relaxed (inverted — agreeing = active = low)
        QuizQuestion(id: 15, text: "I prefer heart-rate-up activities over laid-back ones.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "active_relaxed", weight: -1.0)),

        // Q16: adventurous_cautious (inverted — agreeing = adventurous = low)
        QuizQuestion(id: 16, text: "I enjoy trying unfamiliar experiences.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "adventurous_cautious", weight: -1.0)),

        // Q17: expressive_reserved (inverted — agreeing = expressive = low)
        QuizQuestion(id: 17, text: "My friends always know how I'm feeling.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "expressive_reserved", weight: -1.0)),

        // Q18: independent_collaborative
        QuizQuestion(id: 18, text: "I prefer making decisions with friends rather than alone.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "independent_collaborative", weight: 1.0)),

        // Q19: thinking_feeling
        QuizQuestion(id: 19, text: "I trust my gut feelings more than logic when making decisions.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "thinking_feeling", weight: 1.0)),

        // Q20: sensing_intuition
        QuizQuestion(id: 20, text: "I'm more interested in possibilities and what could be than in facts and what is.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "sensing_intuition", weight: 1.0)),

        // Q21: expressive_reserved
        QuizQuestion(id: 21, text: "I prefer deep conversations over small talk.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "expressive_reserved", weight: -1.0)),

        // Q22: spontaneous_planner + independent_collaborative
        QuizQuestion(id: 22, text: "When picking where to eat, I'd rather someone else decide.", type: .rating, options: [],
                     ratingDimension: DimensionWeight(dimension: "independent_collaborative", weight: 1.0)),
    ]

    // ============================================================
    // MARK: - Profile Building & Saving
    // ============================================================

    // Converts all form data into a Profile model
    // Called when saving or when passing data to ProfileDisplayView
    func buildProfile() -> Profile {
        // Build VibeCheck if quiz was completed
        var vibeCheck: VibeCheck? = nil
        if (isVibeCheckComplete || !vibeCheckPersonality.isEmpty) && !derivedMBTI.isEmpty {
            vibeCheck = VibeCheck(
                introvertExtrovert: vibeCheckPersonality["introvert_extrovert"] ?? 0.5,
                spontaneousPlanner: vibeCheckPersonality["spontaneous_planner"] ?? 0.5,
                activeRelaxed: vibeCheckPersonality["active_relaxed"] ?? 0.5,
                adventurousCautious: vibeCheckPersonality["adventurous_cautious"] ?? 0.5,
                expressiveReserved: vibeCheckPersonality["expressive_reserved"] ?? 0.5,
                independentCollaborative: vibeCheckPersonality["independent_collaborative"] ?? 0.5,
                sensingIntuition: vibeCheckPersonality["sensing_intuition"] ?? 0.5,
                thinkingFeeling: vibeCheckPersonality["thinking_feeling"] ?? 0.5,
                mbtiType: derivedMBTI
            )
        }

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
            friendshipGoals: [],  // Could add this step later
            vibeCheck: vibeCheck
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
            // Upload photos first
            for photoItem in selectedPhotos {
                if let image = photoItem.image {
                    _ = try await ProfileService.shared.uploadPhoto(image)
                }
            }

            // Then save profile data
            let profile = buildProfile()
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
