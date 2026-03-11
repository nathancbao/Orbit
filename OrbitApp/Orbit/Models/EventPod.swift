import Foundation

struct Pod: Codable, Identifiable {
    var id: String
    var missionId: String       // Int for missions, UUID string for signals
    var memberIds: [Int]
    var maxSize: Int
    var name: String?           // User-defined pod name
    var status: String          // open | full | meeting_confirmed | completed | cancelled
    var scheduledTime: String?
    var scheduledPlace: String?
    var confirmedAttendees: [Int]
    var members: [PodMember]?   // Enriched — only present in GET /pods/<id>
    var missionTitle: String?   // Enriched — present in GET /users/me/pods
    var scheduleData: PodScheduleData?  // Availability grid entries from backend
    var surveyCompletedBy: [Int]
    var hasPendingSurvey: Bool
    var missionTags: [String]

    // ── Local-only schedule fields (not from API — TODO: migrate to backend) ──
    var confirmedTime: Date?
    var scheduleDeadline: Date?
    var leaderPickDeadline: Date?

    /// Display name: user-set name, then mission title, then fallback.
    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        if let t = missionTitle, !t.isEmpty { return t }
        return "Pod"
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case missionId = "mission_id"
        case memberIds = "member_ids"
        case maxSize = "max_size"
        case status
        case scheduledTime = "scheduled_time"
        case scheduledPlace = "scheduled_place"
        case confirmedAttendees = "confirmed_attendees"
        case members
        case missionTitle = "mission_title"
        case scheduleData = "schedule_data"
        case surveyCompletedBy = "survey_completed_by"
        case hasPendingSurvey = "has_pending_survey"
        case missionTags = "mission_tags"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // mission_id can be Int (missions) or String (signals)
        if let intId = try? container.decode(Int.self, forKey: .missionId) {
            missionId = String(intId)
        } else {
            missionId = (try? container.decode(String.self, forKey: .missionId)) ?? ""
        }
        memberIds = (try? container.decode([Int].self, forKey: .memberIds)) ?? []
        maxSize = (try? container.decode(Int.self, forKey: .maxSize)) ?? 4
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        status = (try? container.decode(String.self, forKey: .status)) ?? "open"
        scheduledTime = try? container.decodeIfPresent(String.self, forKey: .scheduledTime)
        scheduledPlace = try? container.decodeIfPresent(String.self, forKey: .scheduledPlace)
        confirmedAttendees = (try? container.decode([Int].self, forKey: .confirmedAttendees)) ?? []
        members = try? container.decodeIfPresent([PodMember].self, forKey: .members)
        missionTitle = try? container.decodeIfPresent(String.self, forKey: .missionTitle)
        do {
            scheduleData = try container.decodeIfPresent(PodScheduleData.self, forKey: .scheduleData)
            print("[Schedule] Pod \(id) decoded schedule_data: \(scheduleData?.entries.count ?? 0) entries")
        } catch {
            print("[Schedule] Pod \(id) FAILED to decode schedule_data: \(error)")
            scheduleData = nil
        }

        surveyCompletedBy = (try? container.decode([Int].self, forKey: .surveyCompletedBy)) ?? []
        hasPendingSurvey = (try? container.decode(Bool.self, forKey: .hasPendingSurvey)) ?? false
        missionTags = (try? container.decode([String].self, forKey: .missionTags)) ?? []

        // Local-only fields — not decoded from API
        confirmedTime = nil
        scheduleDeadline = nil
        leaderPickDeadline = nil
    }

    /// The leader of the pod (first member in join order).
    var leaderId: Int? { memberIds.first }

    /// Parsed scheduled time for sorting (tries common date formats).
    var parsedScheduledTime: Date? {
        guard let raw = scheduledTime, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let f = DateFormatter()
        for fmt in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }

    /// Whether this pod is still in pre-scheduling state (not yet confirmed/cancelled).
    var isFlexForming: Bool {
        status == "open" || status == "full"
    }
}

// MARK: - Pod Schedule Data

struct PodScheduleData: Codable {
    var entries: [String: PodScheduleEntry]
}

struct PodScheduleEntry: Codable {
    var slots: [PodTimeSlot]
    var name: String
    var joinIndex: Int

    enum CodingKeys: String, CodingKey {
        case slots, name
        case joinIndex = "join_index"
    }
}

struct PodTimeSlot: Codable {
    var date: String  // "YYYY-MM-DD"
    var hour: Int
}

// MARK: - Member Preview (lightweight, for mission cards)

struct MemberPreview: Codable, Identifiable {
    var userId: Int
    var name: String
    var photo: String?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case photo
    }
}

// MARK: - Pod Member

struct PodMember: Codable, Identifiable {
    var userId: Int
    var name: String
    var collegeYear: String
    var interests: [String]
    var photo: String?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case collegeYear = "college_year"
        case interests
        case photo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(Int.self, forKey: .userId)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "Member"
        collegeYear = (try? container.decode(String.self, forKey: .collegeYear)) ?? ""
        interests = (try? container.decode([String].self, forKey: .interests)) ?? []
        photo = try? container.decodeIfPresent(String.self, forKey: .photo)
    }
}
