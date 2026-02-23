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
}
