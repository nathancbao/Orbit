import Foundation
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var podInvites: [PodInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""

    // User search
    @Published var userSearchText: String = ""
    @Published var userSearchResults: [FriendProfile] = []
    @Published var isSearching = false
    @Published var sentRequestUserIds: Set<Int> = []
    @Published var sendingUserIds: Set<Int> = []
    @Published var searchError: String?
    private var searchTask: Task<Void, Never>?

    var filteredFriends: [Friendship] {
        if searchText.isEmpty { return friends }
        return friends.filter {
            $0.friend?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var inboxCount: Int { incomingRequests.count + podInvites.count }

    // MARK: - Load

    func loadAll() async {
        isLoading = true

        async let friendsResult = FriendService.shared.getFriends()
        async let incomingResult = FriendService.shared.getIncomingRequests()
        async let outgoingResult = FriendService.shared.getOutgoingRequests()
        async let podInvitesResult = PodService.shared.getIncomingInvites()

        do { friends = try await friendsResult } catch { print("[Friends] friends error: \(error)") }
        do { incomingRequests = try await incomingResult } catch { print("[Friends] incoming error: \(error)") }
        do { outgoingRequests = try await outgoingResult } catch { print("[Friends] outgoing error: \(error)") }
        do { podInvites = try await podInvitesResult } catch { print("[Friends] pod invites error: \(error)") }

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

    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await FriendService.shared.cancelRequest(requestId: request.id)
            outgoingRequests.removeAll { $0.id == request.id }
            sentRequestUserIds.remove(request.toUserId)
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

    // MARK: - Pod Invites

    func acceptPodInvite(_ invite: PodInvite) async {
        do {
            _ = try await PodService.shared.acceptInvite(inviteId: invite.id)
            podInvites.removeAll { $0.id == invite.id }
            // Tell the missions feed to refresh so the joined mission appears in "My Missions"
            NotificationCenter.default.post(name: .missionsNeedRefresh, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declinePodInvite(_ invite: PodInvite) async {
        do {
            try await PodService.shared.declineInvite(inviteId: invite.id)
            podInvites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - User Search

    func searchUsers() {
        let query = userSearchText.trimmingCharacters(in: .whitespaces)
        searchTask?.cancel()

        guard query.count >= 3 else {
            userSearchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            // Debounce — wait a beat before hitting the API
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            if let results = try? await FriendService.shared.searchUsers(query: query) {
                guard !Task.isCancelled else { return }
                // Filter out yourself and existing friends
                let currentUserId = UserDefaults.standard.integer(forKey: "orbit_user_id")
                let friendIds = Set(friends.compactMap { $0.friend?.userId })
                userSearchResults = results.filter { $0.userId != currentUserId && !friendIds.contains($0.userId) }
            } else {
                userSearchResults = []
            }
            isSearching = false
        }
    }

    func sendRequestFromSearch(toUserId: Int) async {
        sendingUserIds.insert(toUserId)
        searchError = nil
        do {
            let request = try await FriendService.shared.sendRequest(toUserId: toUserId)
            outgoingRequests.append(request)
            sentRequestUserIds.insert(toUserId)
        } catch {
            searchError = error.localizedDescription
        }
        sendingUserIds.remove(toUserId)
    }
}
