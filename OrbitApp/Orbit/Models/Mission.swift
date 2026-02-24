import Foundation
import SwiftUI

// MARK: - Activity Category

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case pickleball   = "Pickleball"
    case basketball   = "Basketball"
    case cafeHopping  = "Cafe Hopping"
    case restaurant   = "Restaurant"
    case studySession = "Study Session"
    case hiking       = "Hiking"
    case gym          = "Gym"
    case running      = "Running"
    case yoga         = "Yoga"
    case boardGames   = "Board Games"
    case movies       = "Movies"
    case custom       = "Custom"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .pickleball:   return "figure.pickleball"
        case .basketball:   return "figure.basketball"
        case .cafeHopping:  return "cup.and.saucer.fill"
        case .restaurant:   return "fork.knife"
        case .studySession: return "book.fill"
        case .hiking:       return "figure.hiking"
        case .gym:          return "dumbbell.fill"
        case .running:      return "figure.run"
        case .yoga:         return "figure.mind.and.body"
        case .boardGames:   return "gamecontroller.fill"
        case .movies:       return "film"
        case .custom:       return "star.fill"
        }
    }
}

// MARK: - Time Block

enum TimeBlock: String, Codable, CaseIterable, Identifiable {
    case morning   = "morning"
    case afternoon = "afternoon"
    case evening   = "evening"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    var shortLabel: String {
        switch self {
        case .morning:   return "AM"
        case .afternoon: return "PM"
        case .evening:   return "Eve"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }
}

// MARK: - Availability Slot

struct AvailabilitySlot: Codable, Identifiable, Equatable {
    let date: Date
    let timeBlocks: [TimeBlock]

    var id: Date { date }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE M/d"
        return formatter.string(from: date)
    }

    var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Mission Status

enum MissionStatus: String, Codable {
    case pendingMatch = "pending_match"
    case matched      = "matched"

    var label: String {
        switch self {
        case .pendingMatch: return "Pending"
        case .matched:      return "Matched"
        }
    }
}

// MARK: - Mission

struct Mission: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let activityCategory: ActivityCategory
    let customActivityName: String?
    let minGroupSize: Int
    let maxGroupSize: Int
    let availability: [AvailabilitySlot]
    let status: MissionStatus
    let creatorId: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, availability, status
        case activityCategory = "activity_category"
        case customActivityName = "custom_activity_name"
        case minGroupSize = "min_group_size"
        case maxGroupSize = "max_group_size"
        case creatorId = "creator_id"
        case createdAt = "created_at"
    }

    var displayTitle: String {
        if activityCategory == .custom, let name = customActivityName, !name.isEmpty {
            return name
        }
        return title.isEmpty ? activityCategory.displayName : title
    }

    var totalSlotCount: Int {
        availability.reduce(0) { $0 + $1.timeBlocks.count }
    }

    var activeDayCount: Int {
        availability.count
    }

    var availabilitySummary: String {
        let slots = totalSlotCount
        let days = activeDayCount
        return "\(slots) slot\(slots == 1 ? "" : "s") over \(days) day\(days == 1 ? "" : "s")"
    }

    var groupSizeLabel: String {
        if minGroupSize == maxGroupSize {
            return "\(minGroupSize) people"
        }
        return "\(minGroupSize)-\(maxGroupSize) people"
    }
}

// MARK: - Mission Error

enum MissionError: LocalizedError {
    case notFound
    case invalidForm(String)
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Mission not found"
        case .invalidForm(let reason):
            return reason
        case .networkError:
            return "Network error. Please try again."
        case .unknown(let msg):
            return msg
        }
    }
}
