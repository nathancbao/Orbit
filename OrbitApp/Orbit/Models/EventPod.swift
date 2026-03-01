import Foundation

struct EventPod: Codable, Identifiable {
    var id: String
    var eventId: Int
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
}
