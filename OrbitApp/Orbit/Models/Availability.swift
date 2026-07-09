//
//  Availability.swift
//  Orbit
//
//  Shared availability-grid types used by flex-mode missions and pod scheduling.
//

import Foundation
import SwiftUI

// MARK: - Time Block (coarse morning/afternoon/evening slots)

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
