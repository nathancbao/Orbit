import Foundation

class ChatService {
    static let shared = ChatService()
    private init() {}

    func getMessages(podId: String) async throws -> [ChatMessage] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podMessages(podId),
            authenticated: true
        )
    }

    func sendMessage(podId: String, content: String) async throws -> ChatMessage {
        let body: [String: Any] = ["content": content]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podMessages(podId),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func getVotes(podId: String) async throws -> [Vote] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podVotes(podId),
            authenticated: true
        )
    }

    func createVote(podId: String, voteType: String, options: [String]) async throws -> Vote {
        let body: [String: Any] = ["vote_type": voteType, "options": options]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podVotes(podId),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func respondToVote(podId: String, voteId: String, optionIndex: Int) async throws -> Vote {
        let body: [String: Any] = ["option_index": optionIndex]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podVoteRespond(podId, voteId),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func removeVote(podId: String, voteId: String) async throws -> Vote {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podVoteRespond(podId, voteId),
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - Pod Conversations

    func getPodConversations() async throws -> [PodConversation] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podConversations,
            authenticated: true
        )
    }

    // MARK: - DMs

    func getDMMessages(friendId: Int) async throws -> [ChatMessage] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.dmMessages(friendId),
            authenticated: true
        )
    }

    func sendDMMessage(friendId: Int, content: String) async throws -> ChatMessage {
        let body: [String: Any] = ["content": content]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.dmMessages(friendId),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func getDMConversations() async throws -> [DMConversation] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.dmConversations,
            authenticated: true
        )
    }
}

// MARK: - DM Conversation Model

struct DMConversation: Codable, Identifiable {
    var conversationId: String
    var friendId: Int
    var friendName: String
    var friendPhoto: String?
    var lastMessage: String
    var lastMessageAt: String
    var lastMessageUserId: Int?

    var id: String { conversationId }

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case friendId = "friend_id"
        case friendName = "friend_name"
        case friendPhoto = "friend_photo"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case lastMessageUserId = "last_message_user_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = (try? c.decode(String.self, forKey: .conversationId)) ?? ""
        friendId = (try? c.decode(Int.self, forKey: .friendId))
            ?? Int((try? c.decode(String.self, forKey: .friendId)) ?? "") ?? 0
        friendName = (try? c.decode(String.self, forKey: .friendName)) ?? ""
        friendPhoto = try? c.decodeIfPresent(String.self, forKey: .friendPhoto)
        lastMessage = (try? c.decode(String.self, forKey: .lastMessage)) ?? ""
        lastMessageAt = (try? c.decode(String.self, forKey: .lastMessageAt)) ?? ""
        lastMessageUserId = (try? c.decode(Int.self, forKey: .lastMessageUserId))
            ?? Int((try? c.decode(String.self, forKey: .lastMessageUserId)) ?? "")
    }
}

// MARK: - Pod Conversation Model

struct PodConversation: Codable, Identifiable {
    var podId: String
    var podName: String
    var lastMessage: String
    var lastMessageAt: String
    var lastMessageUserId: Int?

    var id: String { podId }

    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case podName = "pod_name"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case lastMessageUserId = "last_message_user_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        podId = (try? c.decode(String.self, forKey: .podId)) ?? ""
        podName = (try? c.decode(String.self, forKey: .podName)) ?? ""
        lastMessage = (try? c.decode(String.self, forKey: .lastMessage)) ?? ""
        lastMessageAt = (try? c.decode(String.self, forKey: .lastMessageAt)) ?? ""
        lastMessageUserId = (try? c.decode(Int.self, forKey: .lastMessageUserId))
            ?? Int((try? c.decode(String.self, forKey: .lastMessageUserId)) ?? "")
    }
}
