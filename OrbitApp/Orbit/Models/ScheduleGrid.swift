//
//  ScheduleGrid.swift
//  Orbit
//
//  When2Meet-style scheduling models for flex mode pods.
//  Data models, member colors, and overlap computation logic.
//

import SwiftUI

// MARK: - Member Color

/// Deterministic color assigned to each pod member based on join order.
enum MemberColor: String, CaseIterable, Codable {
    case pink, purple, blue, teal, orange, green, yellow, red

    var color: Color {
        switch self {
        case .pink:   return Color(red: 0.9,  green: 0.6,  blue: 0.7)
        case .purple: return Color(red: 0.7,  green: 0.65, blue: 0.85)
        case .blue:   return Color(red: 0.45, green: 0.55, blue: 0.85)
        case .teal:   return Color(red: 0.35, green: 0.75, blue: 0.75)
        case .orange: return Color(red: 0.95, green: 0.65, blue: 0.35)
        case .green:  return Color(red: 0.45, green: 0.78, blue: 0.45)
        case .yellow: return Color(red: 0.95, green: 0.85, blue: 0.35)
        case .red:    return Color(red: 0.9,  green: 0.35, blue: 0.35)
        }
    }

    /// Assign color by join-order index (cycles through 8 colors).
    static func forIndex(_ index: Int) -> MemberColor {
        allCases[index % allCases.count]
    }
}

// MARK: - Flex Pod Phase (State Machine)

/// Lifecycle phases for a flex pod's scheduling process.
enum FlexPodPhase: Equatable {
    case forming                              // 1-2 members, grid editable
    case locked(hasOverlap: Bool)             // 3 members, grid locked for non-leaders
    case leaderPicking                        // overlap exists, leader selects slot
    case noOverlapCountdown(deadline: Date)   // no overlap, 48h for members to update
    case scheduled(confirmedTime: Date)       // leader confirmed, chat unlocked
    case dissolved                            // timeouts expired, pod dead
}

// MARK: - Time Slot

/// A single 1-hour slot on a specific calendar day.
/// Uses Calendar-based equality to avoid timezone issues.
struct TimeSlot: Codable {
    let date: Date   // Calendar day (time component ignored)
    let hour: Int    // 9 through 21 (9 AM to 9 PM)

    /// Unique string key for dictionary/frame lookup: "YYYY-M-D-HH".
    var key: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)-\(hour)"
    }

    /// Human-readable label: "3 PM", "12 PM", etc.
    var label: String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

extension TimeSlot: Hashable {
    static func == (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date) && lhs.hour == rhs.hour
    }

    func hash(into hasher: inout Hasher) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        hasher.combine(c.year)
        hasher.combine(c.month)
        hasher.combine(c.day)
        hasher.combine(hour)
    }
}

// MARK: - Schedule Entry

/// One member's availability in the schedule grid.
struct ScheduleEntry: Codable, Identifiable {
    let userId: Int
    let memberColor: MemberColor
    let displayName: String
    var slots: Set<TimeSlot>
    var updatedAt: Date

    var id: Int { userId }

    /// Whether this member has saved any availability.
    var hasSubmitted: Bool { !slots.isEmpty }
}

// MARK: - Schedule Grid

/// Container for the pod's 10-day × 13-hour scheduling grid.
struct ScheduleGrid: Codable {
    let missionId: String
    let podId: String
    let startDate: Date          // Mission creation date (start of day)
    let endDate: Date            // startDate + 10 days
    var entries: [ScheduleEntry]

    /// Valid hour range: 9 AM to 9 PM (inclusive of 9 AM, up through 9 PM slot).
    static let hourRange = 9...21

    // MARK: - Dates

    /// All calendar dates in the 10-day window.
    var dates: [Date] {
        let cal = Calendar.current
        var result: [Date] = []
        var current = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: endDate)
        while current <= end {
            result.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Slot Queries

    /// All entries (members) who selected a given slot.
    func members(for slot: TimeSlot) -> [ScheduleEntry] {
        entries.filter { $0.slots.contains(slot) }
    }

    /// Count of members who selected a given slot.
    func memberCount(for slot: TimeSlot) -> Int {
        members(for: slot).count
    }

    // MARK: - Overlap

    /// Slots where ALL members who have submitted overlap.
    /// Returns empty set if fewer than 2 members have submitted.
    func overlapSlots() -> Set<TimeSlot> {
        let submitted = entries.filter { $0.hasSubmitted }
        guard submitted.count >= 2, let first = submitted.first else { return [] }
        var overlap = first.slots
        for entry in submitted.dropFirst() {
            overlap = overlap.intersection(entry.slots)
        }
        return overlap
    }

    /// Whether any full overlap exists among submitted members.
    var hasOverlap: Bool {
        !overlapSlots().isEmpty
    }

    /// Slots where exactly (totalSubmitted - 1) members overlap (near misses).
    /// Useful for "near-overlap hints" during the 48h countdown.
    func nearOverlapSlots() -> [TimeSlot: [ScheduleEntry]] {
        let submitted = entries.filter { $0.hasSubmitted }
        guard submitted.count >= 2 else { return [:] }
        let threshold = submitted.count - 1  // e.g., 2 of 3

        // Collect all unique slots across all entries
        var allSlots = Set<TimeSlot>()
        for entry in submitted {
            allSlots.formUnion(entry.slots)
        }

        var result: [TimeSlot: [ScheduleEntry]] = [:]
        let fullOverlap = overlapSlots()

        for slot in allSlots {
            // Skip slots that are already full overlap
            guard !fullOverlap.contains(slot) else { continue }
            let present = submitted.filter { $0.slots.contains(slot) }
            if present.count == threshold {
                result[slot] = present
            }
        }

        return result
    }

    // MARK: - Entry Management

    /// Find existing entry for user or create a new one. Returns the index.
    @discardableResult
    mutating func entryForUser(_ userId: Int, name: String, joinIndex: Int) -> Int {
        if let idx = entries.firstIndex(where: { $0.userId == userId }) {
            return idx
        }
        let entry = ScheduleEntry(
            userId: userId,
            memberColor: MemberColor.forIndex(joinIndex),
            displayName: name,
            slots: [],
            updatedAt: Date()
        )
        entries.append(entry)
        return entries.count - 1
    }

    /// Update a user's selected slots.
    mutating func updateSlots(for userId: Int, slots: Set<TimeSlot>) {
        guard let idx = entries.firstIndex(where: { $0.userId == userId }) else { return }
        entries[idx].slots = slots
        entries[idx].updatedAt = Date()
    }

    /// Number of members who have submitted availability.
    var submittedCount: Int {
        entries.filter { $0.hasSubmitted }.count
    }
}
