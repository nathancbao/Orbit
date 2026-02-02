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
