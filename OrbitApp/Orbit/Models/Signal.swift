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

// MARK: - Time Block (legacy)

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
    let hours: [Int]

    var id: Date { date }

    /// True when this slot uses the new hourly format.
    var isHourly: Bool { !hours.isEmpty }

    enum CodingKeys: String, CodingKey {
        case date
        case timeBlocks = "time_blocks"
        case hours
    }

    init(date: Date, timeBlocks: [TimeBlock] = [], hours: [Int] = []) {
        self.date = date
        self.timeBlocks = timeBlocks
        self.hours = hours
    }

    // Backend sends date as "YYYY-MM-DD" string, not ISO8601 with time.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container,
                debugDescription: "Expected yyyy-MM-dd format, got \(dateString)")
        }
        self.date = parsed
        self.timeBlocks = (try? container.decode([TimeBlock].self, forKey: .timeBlocks)) ?? []
        self.hours = (try? container.decode([Int].self, forKey: .hours)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        try container.encode(formatter.string(from: date), forKey: .date)
        if !hours.isEmpty {
            try container.encode(hours, forKey: .hours)
        }
        if !timeBlocks.isEmpty {
            try container.encode(timeBlocks, forKey: .timeBlocks)
        }
    }

    // Local initializer (legacy time-blocks).
    init(date: Date, timeBlocks: [TimeBlock]) {
        self.date = date
        self.timeBlocks = timeBlocks
        self.hours = []
    }

    // Local initializer (new hourly format).
    init(date: Date, hours: [Int]) {
        self.date = date
        self.timeBlocks = []
        self.hours = hours.sorted()
    }

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

    /// Human-readable hour list, e.g. "9 AM, 10 AM, 11 AM"
    var hoursLabel: String {
        hours.map { hourString($0) }.joined(separator: ", ")
    }
}

/// Format an hour (0-23) as "9 AM", "12 PM", etc.
func hourString(_ hour: Int) -> String {
    if hour == 0 { return "12 AM" }
    if hour < 12 { return "\(hour) AM" }
    if hour == 12 { return "12 PM" }
    return "\(hour - 12) PM"
}

// MARK: - Signal Status

@available(*, deprecated, message: "Use Mission with mode: .flex — signalStatus field")
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

@available(*, deprecated, message: "Use Mission with mode: .flex")
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
    let creatorId: Int?
    let createdAt: String?
    let podId: String?
    let scheduledTime: String?
    let links: [String]?
    let timeRangeStart: Int?
    let timeRangeEnd: Int?
    let matchScore: Double?
    let suggestionReason: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, availability, status, links
        case activityCategory  = "activity_category"
        case customActivityName = "custom_activity_name"
        case minGroupSize      = "min_group_size"
        case maxGroupSize      = "max_group_size"
        case creatorId         = "creator_id"
        case createdAt         = "created_at"
        case podId             = "pod_id"
        case scheduledTime     = "scheduled_time"
        case timeRangeStart    = "time_range_start"
        case timeRangeEnd      = "time_range_end"
        case matchScore        = "match_score"
        case suggestionReason  = "suggestion_reason"
    }

    var displayTitle: String {
        if activityCategory == .custom, let name = customActivityName, !name.isEmpty {
            return name
        }
        return title.isEmpty ? activityCategory.displayName : title
    }

    /// Whether this signal uses the new hourly scheduling format.
    var isHourly: Bool {
        availability.contains { $0.isHourly }
    }

    var totalSlotCount: Int {
        if isHourly {
            return availability.reduce(0) { $0 + $1.hours.count }
        }
        return availability.reduce(0) { $0 + $1.timeBlocks.count }
    }

    var activeDayCount: Int { availability.count }

    var availabilitySummary: String {
        let s = totalSlotCount
        let d = activeDayCount
        if isHourly {
            return "\(s) hour\(s == 1 ? "" : "s") over \(d) day\(d == 1 ? "" : "s")"
        }
        return "\(s) slot\(s == 1 ? "" : "s") over \(d) day\(d == 1 ? "" : "s")"
    }

    var groupSizeLabel: String {
        minGroupSize == maxGroupSize ? "\(minGroupSize) people" : "\(minGroupSize)–\(maxGroupSize) people"
    }
}

// MARK: - Signal Error

@available(*, deprecated, message: "Use Mission with mode: .flex")
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
