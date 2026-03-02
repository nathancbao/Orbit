import Foundation

struct EventPod: Codable, Identifiable {
    var id: String
    var eventId: String         // Int for events, UUID string for signals
    var memberIds: [Int]
    var maxSize: Int
    var name: String?           // User-defined pod name
    var status: String          // open | full | meeting_confirmed | completed | cancelled
    var scheduledTime: String?
    var scheduledPlace: String?
    var confirmedAttendees: [Int]
    var members: [PodMember]?   // Enriched — only present in GET /pods/<id>
    var eventTitle: String?     // Enriched — present in GET /users/me/pods

    /// Display name: user-set name, then event title, then fallback.
    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        if let t = eventTitle, !t.isEmpty { return t }
        return "Pod"
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case eventId = "event_id"
        case memberIds = "member_ids"
        case maxSize = "max_size"
        case status
        case scheduledTime = "scheduled_time"
        case scheduledPlace = "scheduled_place"
        case confirmedAttendees = "confirmed_attendees"
        case members
        case eventTitle = "event_title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // event_id can be Int (events) or String (signals)
        if let intId = try? container.decode(Int.self, forKey: .eventId) {
            eventId = String(intId)
        } else {
            eventId = (try? container.decode(String.self, forKey: .eventId)) ?? ""
        }
        memberIds = (try? container.decode([Int].self, forKey: .memberIds)) ?? []
        maxSize = (try? container.decode(Int.self, forKey: .maxSize)) ?? 4
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        status = (try? container.decode(String.self, forKey: .status)) ?? "open"
        scheduledTime = try? container.decodeIfPresent(String.self, forKey: .scheduledTime)
        scheduledPlace = try? container.decodeIfPresent(String.self, forKey: .scheduledPlace)
        confirmedAttendees = (try? container.decode([Int].self, forKey: .confirmedAttendees)) ?? []
        members = try? container.decodeIfPresent([PodMember].self, forKey: .members)
        eventTitle = try? container.decodeIfPresent(String.self, forKey: .eventTitle)
    }
}

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
