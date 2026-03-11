//
//  Mission.swift (stored as Event.swift — renamed struct)
//  Orbit
//
//  Community activity — supports both fixed-date (Set mode) and flexible scheduling (Flex mode).
//

import Foundation

// MARK: - Mission Mode

enum MissionMode: String, Codable {
    case set = "set"    // Fixed date/time (traditional mission)
    case flex = "flex"  // Group picks time via availability grid (formerly "Signal")
}

// MARK: - Mission

struct Mission: Codable, Identifiable {

    // ── Shared fields (both modes) ──────────────────────────────────────

    var id: String
    var title: String
    var description: String
    var tags: [String]
    var location: String
    var creatorId: Int?
    var creatorType: String?        // user | seeded | ai_suggested
    var maxPodSize: Int
    var status: String              // open | completed | cancelled | pending | active
    var matchScore: Double?
    var suggestionReason: String?

    // Annotated server-side for the requesting user
    var userPodStatus: String?      // not_joined | in_pod | pod_full
    var userPodId: String?
    var pods: [PodSummary]?

    // ── Mode discriminator ──────────────────────────────────────────────

    var mode: MissionMode

    // ── Set mode fields ─────────────────────────────────────────────────

    var date: String                // YYYY-MM-DD (required for set, empty for flex)
    var startTime: String?          // HH:mm (24h)
    var endTime: String?            // HH:mm (24h)

    // ── Flex mode fields (optional, only populated when mode == .flex) ──

    var activityCategory: ActivityCategory?
    var customActivityName: String?
    var minGroupSize: Int?
    var availability: [AvailabilitySlot]?
    var timeRangeStart: Int?
    var timeRangeEnd: Int?
    var links: [String]?
    var signalStatus: SignalStatus?  // pending | active (flex mode status)
    var podId: String?              // user's pod from RSVP (flex mode)
    var scheduledTime: String?      // confirmed meeting time (flex mode, set by leader)
    var createdAt: String?
    var utcOffset: Int?             // seconds east of UTC, used for deletion countdown

    // ── CodingKeys ──────────────────────────────────────────────────────

    enum CodingKeys: String, CodingKey {
        case id, title, description, tags, location, date, status, mode
        case startTime          = "start_time"
        case endTime            = "end_time"
        case creatorId          = "creator_id"
        case creatorType        = "creator_type"
        case maxPodSize         = "max_pod_size"
        case matchScore         = "match_score"
        case suggestionReason   = "suggestion_reason"
        case userPodStatus      = "user_pod_status"
        case userPodId          = "user_pod_id"
        case pods
        case activityCategory   = "activity_category"
        case customActivityName = "custom_activity_name"
        case minGroupSize       = "min_group_size"
        case availability
        case timeRangeStart     = "time_range_start"
        case timeRangeEnd       = "time_range_end"
        case links
        case signalStatus       = "signal_status"
        case podId              = "pod_id"
        case scheduledTime      = "scheduled_time"
        case createdAt          = "created_at"
        case utcOffset          = "utc_offset"
    }

    // ── Custom Decoder (backward-compatible: defaults mode to .set) ─────

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id              = try c.decode(String.self, forKey: .id)
        title           = try c.decode(String.self, forKey: .title)
        description     = (try? c.decode(String.self, forKey: .description)) ?? ""
        tags            = (try? c.decode([String].self, forKey: .tags)) ?? []
        location        = (try? c.decode(String.self, forKey: .location)) ?? ""
        date            = (try? c.decode(String.self, forKey: .date)) ?? ""
        startTime       = try? c.decode(String.self, forKey: .startTime)
        endTime         = try? c.decode(String.self, forKey: .endTime)
        creatorId       = try? c.decode(Int.self, forKey: .creatorId)
        creatorType     = try? c.decode(String.self, forKey: .creatorType)
        maxPodSize      = (try? c.decode(Int.self, forKey: .maxPodSize)) ?? 4
        status          = (try? c.decode(String.self, forKey: .status)) ?? "open"
        matchScore      = try? c.decode(Double.self, forKey: .matchScore)
        suggestionReason = try? c.decode(String.self, forKey: .suggestionReason)
        userPodStatus   = try? c.decode(String.self, forKey: .userPodStatus)
        userPodId       = try? c.decode(String.self, forKey: .userPodId)
        pods            = try? c.decode([PodSummary].self, forKey: .pods)

        // Mode — defaults to .set when absent (backward compatibility)
        mode            = (try? c.decode(MissionMode.self, forKey: .mode)) ?? .set

        // Flex mode fields
        activityCategory  = try? c.decode(ActivityCategory.self, forKey: .activityCategory)
        customActivityName = try? c.decode(String.self, forKey: .customActivityName)
        minGroupSize      = try? c.decode(Int.self, forKey: .minGroupSize)
        availability      = try? c.decode([AvailabilitySlot].self, forKey: .availability)
        timeRangeStart    = try? c.decode(Int.self, forKey: .timeRangeStart)
        timeRangeEnd      = try? c.decode(Int.self, forKey: .timeRangeEnd)
        links             = try? c.decode([String].self, forKey: .links)
        signalStatus      = try? c.decode(SignalStatus.self, forKey: .signalStatus)
        podId             = try? c.decode(String.self, forKey: .podId)
        scheduledTime     = try? c.decode(String.self, forKey: .scheduledTime)
        createdAt         = try? c.decode(String.self, forKey: .createdAt)
        utcOffset         = try? c.decode(Int.self, forKey: .utcOffset)
    }

    // ── Local initializer (for creating missions in code) ───────────────

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        tags: [String] = [],
        location: String = "",
        date: String = "",
        startTime: String? = nil,
        endTime: String? = nil,
        creatorId: Int? = nil,
        creatorType: String? = nil,
        maxPodSize: Int = 4,
        status: String = "open",
        matchScore: Double? = nil,
        suggestionReason: String? = nil,
        userPodStatus: String? = nil,
        userPodId: String? = nil,
        pods: [PodSummary]? = nil,
        mode: MissionMode = .set,
        activityCategory: ActivityCategory? = nil,
        customActivityName: String? = nil,
        minGroupSize: Int? = nil,
        availability: [AvailabilitySlot]? = nil,
        timeRangeStart: Int? = nil,
        timeRangeEnd: Int? = nil,
        links: [String]? = nil,
        signalStatus: SignalStatus? = nil,
        podId: String? = nil,
        scheduledTime: String? = nil,
        createdAt: String? = nil,
        utcOffset: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.location = location
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.creatorId = creatorId
        self.creatorType = creatorType
        self.maxPodSize = maxPodSize
        self.status = status
        self.matchScore = matchScore
        self.suggestionReason = suggestionReason
        self.userPodStatus = userPodStatus
        self.userPodId = userPodId
        self.pods = pods
        self.mode = mode
        self.activityCategory = activityCategory
        self.customActivityName = customActivityName
        self.minGroupSize = minGroupSize
        self.availability = availability
        self.timeRangeStart = timeRangeStart
        self.timeRangeEnd = timeRangeEnd
        self.links = links
        self.signalStatus = signalStatus
        self.podId = podId
        self.scheduledTime = scheduledTime
        self.createdAt = createdAt
        self.utcOffset = utcOffset
    }

    // ── Computed Properties ─────────────────────────────────────────────

    var isFlexMode: Bool { mode == .flex }

    /// Whether this mission has ended (past its end time in the user's local timezone).
    var isCompleted: Bool { status == "completed" }

    /// The date at which this mission will be auto-deleted (end time + 2 hours).
    /// Times are stored in the creator's local timezone. utc_offset converts to UTC.
    var deletionDate: Date? {
        guard mode == .set, !date.isEmpty else { return nil }

        // Parse date+time as naive values (no timezone) using a GMT calendar
        // so that "2026-03-11 15:00" is treated as absolute hour 15, not shifted.
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let day = f.date(from: date) else { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var endDt: Date?

        if let et = endTime {
            let parts = et.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                endDt = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
            }
        }
        if endDt == nil, let st = startTime {
            let parts = st.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2, let base = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) {
                endDt = base.addingTimeInterval(2 * 3600)
            }
        }
        if endDt == nil {
            endDt = cal.date(bySettingHour: 23, minute: 59, second: 0, of: day)
        }

        guard let naiveEnd = endDt else { return nil }

        // naiveEnd is now the local end time stored as-if-GMT.
        // Subtract utcOffset to convert creator-local → real UTC, then add 2h grace.
        let offsetSecs = utcOffset ?? TimeZone.current.secondsFromGMT()
        let utcEnd = naiveEnd.addingTimeInterval(TimeInterval(-offsetSecs))
        return utcEnd.addingTimeInterval(2 * 3600)
    }

    /// Time remaining until deletion, or nil if not applicable.
    var timeUntilDeletion: TimeInterval? {
        guard let delDate = deletionDate else { return nil }
        let remaining = delDate.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Human-readable countdown string like "1h 23m".
    var deletionCountdownString: String? {
        guard let remaining = timeUntilDeletion else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Parsed event date+time for sorting. Set missions use date+startTime; flex returns `.distantFuture`.
    var sortDate: Date {
        guard mode == .set, !date.isEmpty else { return .distantFuture }
        let f = DateFormatter()
        if let start = startTime {
            f.dateFormat = "yyyy-MM-dd HH:mm"
            if let d = f.date(from: "\(date) \(start)") { return d }
        }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date) ?? .distantFuture
    }

    /// Parsed createdAt for "newest first" sorting.
    var createdAtDate: Date {
        guard let raw = createdAt, !raw.isEmpty else { return .distantPast }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw) ?? .distantPast
    }

    /// Display title — flex mode uses category/custom name, set mode uses title.
    var displayTitle: String {
        if mode == .flex {
            if activityCategory == .custom, let name = customActivityName, !name.isEmpty {
                return name
            }
            if let cat = activityCategory {
                return title.isEmpty ? cat.displayName : title
            }
        }
        return title
    }

    /// Formatted date string for set mode cards.
    var displayDate: String {
        guard !date.isEmpty else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date) else { return date }
        f.dateStyle = .medium
        f.timeStyle = .none
        var result = f.string(from: d)
        if let start = startTime {
            result += " · \(Self.formatTime(start))"
            if let end = endTime {
                result += " – \(Self.formatTime(end))"
            }
        }
        return result
    }

    /// Availability summary for flex mode (e.g. "3 hours over 2 days").
    var flexAvailabilitySummary: String? {
        guard let slots = availability, !slots.isEmpty else { return nil }
        let isHourly = slots.contains { $0.isHourly }
        let totalSlots: Int
        if isHourly {
            totalSlots = slots.reduce(0) { $0 + $1.hours.count }
        } else {
            totalSlots = slots.reduce(0) { $0 + $1.timeBlocks.count }
        }
        let days = slots.count
        if isHourly {
            return "\(totalSlots) hour\(totalSlots == 1 ? "" : "s") over \(days) day\(days == 1 ? "" : "s")"
        }
        return "\(totalSlots) slot\(totalSlots == 1 ? "" : "s") over \(days) day\(days == 1 ? "" : "s")"
    }

    /// Group size label for flex mode (e.g. "3–8 people").
    var flexGroupSizeLabel: String? {
        guard let min = minGroupSize else { return nil }
        let max = maxPodSize
        return min == max ? "\(min) people" : "\(min)–\(max) people"
    }

    /// Convert "HH:mm" to a localized short time string (e.g. "3:00 PM").
    private static func formatTime(_ hhmm: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let d = f.date(from: hhmm) else { return hhmm }
        f.dateFormat = ""
        f.timeStyle = .short
        return f.string(from: d)
    }

    // ── Factory: Convert Signal → Mission (flex mode) ───────────────────

    /// Convert a Signal (backend flex entity) to a Mission with mode: .flex.
    static func fromSignal(_ signal: Signal) -> Mission {
        Mission(
            id: signal.id,
            title: signal.title,
            description: signal.description,
            tags: [],
            location: "",
            date: "",
            creatorId: signal.creatorId,
            maxPodSize: signal.maxGroupSize,
            status: signal.status.rawValue,
            mode: .flex,
            activityCategory: signal.activityCategory,
            customActivityName: signal.customActivityName,
            minGroupSize: signal.minGroupSize,
            availability: signal.availability,
            timeRangeStart: signal.timeRangeStart,
            timeRangeEnd: signal.timeRangeEnd,
            links: signal.links,
            signalStatus: signal.status,
            podId: signal.podId,
            scheduledTime: signal.scheduledTime,
            createdAt: signal.createdAt
        )
    }
}

// MARK: - Pod Summary

struct PodSummary: Codable {
    var podId: String
    var memberCount: Int
    var maxSize: Int
    var status: String
    var memberPreviews: [MemberPreview]?

    var spotsLeft: Int { max(0, maxSize - memberCount) }

    enum CodingKeys: String, CodingKey {
        case podId           = "pod_id"
        case memberCount     = "member_count"
        case maxSize         = "max_size"
        case status
        case memberPreviews  = "member_previews"
    }
}
