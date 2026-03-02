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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        podId = (try? container.decode(String.self, forKey: .podId)) ?? ""
        userId = (try? container.decode(Int.self, forKey: .userId)) ?? 0
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        messageType = (try? container.decode(String.self, forKey: .messageType)) ?? "text"
        createdAt = (try? container.decode(String.self, forKey: .createdAt)) ?? ""
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        podId = (try? container.decode(String.self, forKey: .podId)) ?? ""
        createdBy = (try? container.decode(Int.self, forKey: .createdBy)) ?? 0
        voteType = (try? container.decode(String.self, forKey: .voteType)) ?? "time"
        options = (try? container.decode([String].self, forKey: .options)) ?? []
        votes = (try? container.decode([String: Int].self, forKey: .votes)) ?? [:]
        status = (try? container.decode(String.self, forKey: .status)) ?? "open"
        result = try? container.decodeIfPresent(String.self, forKey: .result)
        createdAt = (try? container.decode(String.self, forKey: .createdAt)) ?? ""
    }
}
