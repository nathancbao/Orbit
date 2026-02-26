//
//  Mission.swift (stored as Event.swift — renamed struct)
//  Orbit
//
//  Fixed-date community event — concerts, club meetings, etc. (formerly Event)
//

import Foundation

struct Mission: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var tags: [String]
    var location: String
    var date: String            // YYYY-MM-DD
    var creatorId: Int?
    var creatorType: String?    // user | seeded | ai_suggested
    var maxPodSize: Int
    var status: String          // open | completed | cancelled
    var matchScore: Double?
    var suggestionReason: String?

    // Annotated server-side for the requesting user
    var userPodStatus: String?  // not_joined | in_pod | pod_full
    var userPodId: String?
    var pods: [PodSummary]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, tags, location, date, status
        case creatorId        = "creator_id"
        case creatorType      = "creator_type"
        case maxPodSize       = "max_pod_size"
        case matchScore       = "match_score"
        case suggestionReason = "suggestion_reason"
        case userPodStatus    = "user_pod_status"
        case userPodId        = "user_pod_id"
        case pods
    }

    var displayDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: date) {
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: d)
        }
        return date
    }
}

struct PodSummary: Codable {
    var podId: String
    var memberCount: Int
    var maxSize: Int
    var status: String

    var spotsLeft: Int { max(0, maxSize - memberCount) }

    enum CodingKeys: String, CodingKey {
        case podId       = "pod_id"
        case memberCount = "member_count"
        case maxSize     = "max_size"
        case status
    }
}
