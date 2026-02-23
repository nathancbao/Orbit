import Foundation

struct EventPod: Codable, Identifiable {
    var id: String
    var eventId: Int
    var memberIds: [Int]
    var maxSize: Int
    var status: String          // open | full | meeting_confirmed | completed | cancelled
    var scheduledTime: String?
    var scheduledPlace: String?
    var confirmedAttendees: [Int]
    var members: [PodMember]?   // Enriched — only present in GET /pods/<id>

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case memberIds = "member_ids"
        case maxSize = "max_size"
        case status
        case scheduledTime = "scheduled_time"
        case scheduledPlace = "scheduled_place"
        case confirmedAttendees = "confirmed_attendees"
        case members
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
