import Foundation
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""

    var filteredFriends: [Friendship] {
        if searchText.isEmpty { return friends }
        return friends.filter {
            $0.friend?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var inboxCount: Int { incomingRequests.count }

    // MARK: - Load

    func loadAll() async {
        isLoading = true

        async let friendsResult = FriendService.shared.getFriends()
        async let incomingResult = FriendService.shared.getIncomingRequests()
        async let outgoingResult = FriendService.shared.getOutgoingRequests()

        if let f = try? await friendsResult { friends = f }
        if let i = try? await incomingResult { incomingRequests = i }
        if let o = try? await outgoingResult { outgoingRequests = o }

        isLoading = false
    }

    // MARK: - Actions

    func acceptRequest(_ request: FriendRequest) async {
        do {
            let friendship = try await FriendService.shared.acceptRequest(requestId: request.id)
            incomingRequests.removeAll { $0.id == request.id }
            friends.append(friendship)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await FriendService.shared.declineRequest(requestId: request.id)
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friendship: Friendship) async {
        do {
            try await FriendService.shared.removeFriend(friendshipId: friendship.id)
            friends.removeAll { $0.id == friendship.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(toUserId: Int) async -> Bool {
        do {
            let request = try await FriendService.shared.sendRequest(toUserId: toUserId)
            outgoingRequests.append(request)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
