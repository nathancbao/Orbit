import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String
    var podId: String
    var userId: Int
    var content: String
    var messageType: String   // text | vote_created | vote_result | system
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case userId = "user_id"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
    }

    var isSystemMessage: Bool {
        messageType != "text"
    }
}

struct Vote: Codable, Identifiable {
    var id: String
    var podId: String
    var createdBy: Int
    var voteType: String      // time | place
    var options: [String]
    var votes: [String: Int]  // user_id_string -> option_index
    var status: String        // open | closed
    var result: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case createdBy = "created_by"
        case voteType = "vote_type"
        case options, votes, status, result
        case createdAt = "created_at"
    }
}
