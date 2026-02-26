//
//  Signal.swift
//  Orbit
//
//  Spontaneous activity request — anyone down? (formerly Mission)
//

import Foundation
import SwiftUI

// MARK: - Activity Category

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case sports  = "Sports"
    case food    = "Food"
    case movies  = "Movies"
    case hangout = "Hangout"
    case study   = "Study"
    case custom  = "Custom"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .sports:  return "figure.run"
        case .food:    return "fork.knife"
        case .movies:  return "film"
        case .hangout: return "person.2.fill"
        case .study:   return "book.fill"
        case .custom:  return "star.fill"
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
        let f = DateFormatter(); f.dateFormat = "EEE M/d"
        return f.string(from: date)
    }

    var weekdayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date)
    }

    var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

// MARK: - Signal Status

enum SignalStatus: String, Codable {
    case pending = "pending"   // waiting for min group
    case active  = "active"    // min met, pod formed

    var label: String {
        switch self {
        case .pending: return "Open"
        case .active:  return "Active"
        }
    }
}

// MARK: - Signal

struct Signal: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let activityCategory: ActivityCategory
    let customActivityName: String?
    let minGroupSize: Int
    let maxGroupSize: Int
    let availability: [AvailabilitySlot]
    let status: SignalStatus
    let creatorId: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, availability, status
        case activityCategory  = "activity_category"
        case customActivityName = "custom_activity_name"
        case minGroupSize      = "min_group_size"
        case maxGroupSize      = "max_group_size"
        case creatorId         = "creator_id"
        case createdAt         = "created_at"
    }

    var displayTitle: String {
        if activityCategory == .custom, let name = customActivityName, !name.isEmpty {
            return name
        }
        return title.isEmpty ? activityCategory.displayName : title
    }

    var totalSlotCount: Int { availability.reduce(0) { $0 + $1.timeBlocks.count } }
    var activeDayCount: Int { availability.count }

    var availabilitySummary: String {
        let s = totalSlotCount
        let d = activeDayCount
        return "\(s) slot\(s == 1 ? "" : "s") over \(d) day\(d == 1 ? "" : "s")"
    }

    var groupSizeLabel: String {
        minGroupSize == maxGroupSize ? "\(minGroupSize) people" : "\(minGroupSize)–\(maxGroupSize) people"
    }
}

// MARK: - Signal Error

enum SignalError: LocalizedError {
    case notFound
    case invalidForm(String)
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:              return "Signal not found"
        case .invalidForm(let r):   return r
        case .networkError:          return "Network error. Please try again."
        case .unknown(let m):        return m
        }
    }
}
