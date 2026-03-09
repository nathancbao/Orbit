import Foundation

class FriendService {
    static let shared = FriendService()
    private init() {}

    // MARK: - Friends List

    func getFriends() async throws -> [Friendship] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friends,
            authenticated: true
        )
    }

    // MARK: - Friend Requests

    func getIncomingRequests() async throws -> [FriendRequest] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRequestsIncoming,
            authenticated: true
        )
    }

    func getOutgoingRequests() async throws -> [FriendRequest] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRequestsOutgoing,
            authenticated: true
        )
    }

    // MARK: - Send Request

    func sendRequest(toUserId: Int) async throws -> FriendRequest {
        let body: [String: Any] = ["to_user_id": toUserId]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRequests,
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    // MARK: - Respond to Request

    func acceptRequest(requestId: Int) async throws -> Friendship {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRequestAccept(requestId),
            method: "POST",
            authenticated: true
        )
    }

    func declineRequest(requestId: Int) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRequestDecline(requestId),
            method: "POST",
            authenticated: true
        )
    }

    // MARK: - Remove Friend

    func removeFriend(friendshipId: Int) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendRemove(friendshipId),
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - Check Status

    func checkFriendStatus(userId: Int) async throws -> FriendStatus {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.friendStatus(userId),
            authenticated: true
        )
    }
}
