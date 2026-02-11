//
//  FriendsViewModel.swift
//  Orbit
//
//  State management for friends and friend requests.
//

import Foundation
import Combine

@MainActor
class FriendsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var friends: [Friend] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []

    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingRequests: Bool = false
    @Published var isSendingRequest: Bool = false

    @Published var errorMessage: String?
    @Published var showError: Bool = false

    @Published var successMessage: String?
    @Published var showSuccess: Bool = false

    // MARK: - Computed Properties

    var hasPendingRequests: Bool {
        !incomingRequests.isEmpty
    }

    var incomingRequestCount: Int {
        incomingRequests.count
    }

    // MARK: - Load Data

    func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFriends() }
            group.addTask { await self.loadFriendRequests() }
        }
    }

    func loadFriends() async {
        isLoadingFriends = true
        errorMessage = nil

        do {
            friends = try await FriendService.shared.getFriends()
        } catch {
            handleError(error)
        }

        isLoadingFriends = false
    }

    func loadFriendRequests() async {
        isLoadingRequests = true
        errorMessage = nil

        do {
            let (incoming, outgoing) = try await FriendService.shared.getFriendRequests()
            incomingRequests = incoming
            outgoingRequests = outgoing
        } catch {
            handleError(error)
        }

        isLoadingRequests = false
    }

    // MARK: - Send Request

    func sendFriendRequest(to profile: Profile) async -> Bool {
        isSendingRequest = true
        errorMessage = nil

        do {
            let request = try await FriendService.shared.sendFriendRequest(to: profile)
            outgoingRequests.append(request)
            showSuccessMessage("Friend request sent to \(profile.name)!")
            isSendingRequest = false
            return true
        } catch {
            handleError(error)
            isSendingRequest = false
            return false
        }
    }

    // MARK: - Accept Request

    func acceptRequest(_ request: FriendRequest) async {
        do {
            let friend = try await FriendService.shared.acceptFriendRequest(request)
            incomingRequests.removeAll { $0.id == request.id }
            friends.append(friend)
            showSuccessMessage("You are now friends with \(request.fromUserProfile.name)!")
        } catch {
            handleError(error)
        }
    }

    // MARK: - Deny Request

    func denyRequest(_ request: FriendRequest) async {
        do {
            try await FriendService.shared.denyFriendRequest(request)
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Cancel Outgoing Request

    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await FriendService.shared.cancelFriendRequest(request)
            outgoingRequests.removeAll { $0.id == request.id }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Remove Friend

    func removeFriend(_ friend: Friend) async {
        do {
            try await FriendService.shared.removeFriend(friend)
            friends.removeAll { $0.id == friend.id }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        if let friendError = error as? FriendError {
            errorMessage = friendError.errorDescription
        } else if let networkError = error as? NetworkError {
            errorMessage = networkError.errorDescription
        } else {
            errorMessage = "An unexpected error occurred"
        }
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }
}
