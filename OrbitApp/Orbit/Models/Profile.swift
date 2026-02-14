import Foundation

struct Profile: Codable, Identifiable {
    var id: String { name } // Use name as unique identifier
    var name: String
    var age: Int
    var location: Location
    var bio: String
    var photos: [String]
    var interests: [String]
    var personality: Personality
    var socialPreferences: SocialPreferences
    var friendshipGoals: [String]
    var matchScore: Double?
    var vibeCheck: VibeCheck?

    enum CodingKeys: String, CodingKey {
        case name, age, location, bio, photos, interests, personality
        case socialPreferences = "social_preferences"
        case friendshipGoals = "friendship_goals"
        case matchScore = "match_score"
        case vibeCheck = "vibe_check"
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

// MARK: - Vibe Check (Quiz-based personality — 8 dimensions + MBTI)
struct VibeCheck: Codable {
    var introvertExtrovert: Double
    var spontaneousPlanner: Double
    var activeRelaxed: Double
    var adventurousCautious: Double
    var expressiveReserved: Double
    var independentCollaborative: Double
    var sensingIntuition: Double
    var thinkingFeeling: Double
    var mbtiType: String

    enum CodingKeys: String, CodingKey {
        case introvertExtrovert = "introvert_extrovert"
        case spontaneousPlanner = "spontaneous_planner"
        case activeRelaxed = "active_relaxed"
        case adventurousCautious = "adventurous_cautious"
        case expressiveReserved = "expressive_reserved"
        case independentCollaborative = "independent_collaborative"
        case sensingIntuition = "sensing_intuition"
        case thinkingFeeling = "thinking_feeling"
        case mbtiType = "mbti_type"
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
