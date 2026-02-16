//
//  MissionModels.swift
//  Orbit
//
//  Data models for missions (group activities with time constraints).
//

import Foundation

// MARK: - RSVP Type

enum RSVPType: String, Codable {
    case hard
    case soft
}

// MARK: - Mission

struct Mission: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let tags: [String]
    let location: String
    let startTime: String
    let endTime: String
    let latitude: Double?
    let longitude: Double?
    let links: [String]
    let images: [String]
    let maxParticipants: Int
    let creatorId: Int
    let hardRsvpCount: Int
    let softRsvpCount: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, tags, location, links, images, latitude, longitude
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case creatorId = "creator_id"
        case hardRsvpCount = "hard_rsvp_count"
        case softRsvpCount = "soft_rsvp_count"
        case createdAt = "created_at"
    }

    var totalRsvpCount: Int {
        hardRsvpCount + softRsvpCount
    }

    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }

    var endDate: Date? {
        ISO8601DateFormatter().date(from: endTime)
    }

    var isExpired: Bool {
        guard let end = endDate else { return false }
        return Date() > end.addingTimeInterval(3600)
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}

// MARK: - Mission Participant

struct MissionParticipant: Codable, Identifiable {
    var id: String { "\(userId)" }
    let userId: Int
    let rsvpType: RSVPType
    let rsvpedAt: String?
    let profile: Profile?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rsvpType = "rsvp_type"
        case rsvpedAt = "rsvped_at"
        case profile
    }
}

// MARK: - Feed Segment

enum MissionFeedSegment: String, CaseIterable {
    case discover = "Discover"
    case myEvents = "My Events"
}

// MARK: - API Response Types

struct MissionListResponseData: Codable {
    let missions: [Mission]?

    // Support both array and wrapped responses
    init(from decoder: Decoder) throws {
        // Try decoding as array first (backend returns array directly)
        if let array = try? [Mission](from: decoder) {
            missions = array
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            missions = try container.decodeIfPresent([Mission].self, forKey: .missions)
        }
    }

    enum CodingKeys: String, CodingKey {
        case missions
    }
}

// MARK: - Mission Errors

enum MissionError: LocalizedError {
    case notFound
    case alreadyRsvped
    case missionFull
    case missionExpired
    case notCreator
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Mission not found"
        case .alreadyRsvped:
            return "You've already joined this mission"
        case .missionFull:
            return "This mission is at full capacity"
        case .missionExpired:
            return "This mission has expired"
        case .notCreator:
            return "Only the mission creator can do this"
        case .networkError:
            return "Network error. Please try again."
        case .unknown(let msg):
            return msg
        }
    }
}
