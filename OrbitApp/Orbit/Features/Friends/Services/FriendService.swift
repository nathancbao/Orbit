//
//  FriendService.swift
//  Orbit
//
//  Handles friend requests and friendships.
//  Set useMockData = false when server is ready.
//

import Foundation

class FriendService {
    static let shared = FriendService()
    private init() {
        // Seed initial mock data
        seedMockData()
    }

    // Set to false when backend is ready
    private let useMockData = true

    // In-memory mock storage
    private var mockFriendRequests: [FriendRequest] = []
    private var mockFriends: [Friend] = []

    // Current user ID (would come from AuthService in production)
    private var currentUserId: String { "current_user" }

    // MARK: - Send Friend Request

    func sendFriendRequest(to toProfile: Profile) async throws -> FriendRequest {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)

            // Check if already friends
            if mockFriends.contains(where: { $0.friendProfile.id == toProfile.id }) {
                throw FriendError.alreadyFriends
            }

            // Check if request already exists
            if mockFriendRequests.contains(where: {
                ($0.fromUserId == currentUserId && $0.toUserId == toProfile.id) ||
                ($0.toUserId == currentUserId && $0.fromUserId == toProfile.id)
            }) {
                throw FriendError.requestAlreadyExists
            }

            let request = FriendRequest(
                id: UUID().uuidString,
                fromUserId: currentUserId,
                toUserId: toProfile.id,
                fromUserProfile: Self.mockCurrentUserProfile,
                toUserProfile: toProfile,
                status: .pending,
                createdAt: Date(),
                updatedAt: Date()
            )
            mockFriendRequests.append(request)
            return request
        }

        // Real API call
        let body: [String: Any] = ["to_user_id": toProfile.id]
        let response: FriendRequestResponseData = try await APIService.shared.request(
            endpoint: "/friends/requests",
            method: "POST",
            body: body,
            authenticated: true
        )
        return response.request
    }

    // MARK: - Get Friend Requests

    func getFriendRequests() async throws -> (incoming: [FriendRequest], outgoing: [FriendRequest]) {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)

            let incoming = mockFriendRequests.filter {
                $0.toUserId == currentUserId && $0.status == .pending
            }
            let outgoing = mockFriendRequests.filter {
                $0.fromUserId == currentUserId && $0.status == .pending
            }
            return (incoming, outgoing)
        }

        let response: FriendRequestsListResponseData = try await APIService.shared.request(
            endpoint: "/friends/requests",
            method: "GET",
            authenticated: true
        )
        return (response.incoming, response.outgoing)
    }

    // MARK: - Accept Friend Request

    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friend {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)

            // Remove from requests
            mockFriendRequests.removeAll { $0.id == request.id }

            // Create friendship
            let friend = Friend(
                id: UUID().uuidString,
                friendProfile: request.fromUserProfile,
                connectedAt: Date()
            )
            mockFriends.append(friend)
            return friend
        }

        let _: FriendRequestResponseData = try await APIService.shared.request(
            endpoint: "/friends/requests/\(request.id)/accept",
            method: "POST",
            authenticated: true
        )
        return Friend(
            id: UUID().uuidString,
            friendProfile: request.fromUserProfile,
            connectedAt: Date()
        )
    }

    // MARK: - Deny Friend Request

    func denyFriendRequest(_ request: FriendRequest) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            mockFriendRequests.removeAll { $0.id == request.id }
            return
        }

        struct MessageResponse: Codable {
            let message: String
        }
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: "/friends/requests/\(request.id)/deny",
            method: "POST",
            authenticated: true
        )
    }

    // MARK: - Cancel Outgoing Request

    func cancelFriendRequest(_ request: FriendRequest) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            mockFriendRequests.removeAll { $0.id == request.id }
            return
        }

        struct MessageResponse: Codable {
            let message: String
        }
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: "/friends/requests/\(request.id)",
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - Get Friends

    func getFriends() async throws -> [Friend] {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockFriends
        }

        let response: FriendsListResponseData = try await APIService.shared.request(
            endpoint: "/friends",
            method: "GET",
            authenticated: true
        )
        return response.friends
    }

    // MARK: - Remove Friend

    func removeFriend(_ friend: Friend) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            mockFriends.removeAll { $0.id == friend.id }
            return
        }

        struct MessageResponse: Codable {
            let message: String
        }
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: "/friends/\(friend.id)",
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - Check Request Status

    func getRequestStatus(for profile: Profile) -> FriendRequestStatus? {
        // Check if already friends
        if mockFriends.contains(where: { $0.friendProfile.id == profile.id }) {
            return .accepted
        }

        // Check pending requests (either direction)
        if let request = mockFriendRequests.first(where: {
            (($0.fromUserId == currentUserId && $0.toUserId == profile.id) ||
             ($0.toUserId == currentUserId && $0.fromUserId == profile.id)) &&
            $0.status == .pending
        }) {
            return request.status
        }

        return nil
    }

    // MARK: - Seed Mock Data

    private func seedMockData() {
        guard useMockData else { return }

        let mockProfiles = DiscoverService.mockProfiles

        // Add some mock incoming requests (from other users to current user)
        if mockProfiles.count >= 2 {
            mockFriendRequests = [
                FriendRequest(
                    id: "req_1",
                    fromUserId: mockProfiles[0].id,
                    toUserId: currentUserId,
                    fromUserProfile: mockProfiles[0],
                    toUserProfile: Self.mockCurrentUserProfile,
                    status: .pending,
                    createdAt: Date().addingTimeInterval(-86400),
                    updatedAt: Date().addingTimeInterval(-86400)
                ),
                FriendRequest(
                    id: "req_2",
                    fromUserId: mockProfiles[1].id,
                    toUserId: currentUserId,
                    fromUserProfile: mockProfiles[1],
                    toUserProfile: Self.mockCurrentUserProfile,
                    status: .pending,
                    createdAt: Date().addingTimeInterval(-3600),
                    updatedAt: Date().addingTimeInterval(-3600)
                )
            ]
        }

        // Add one mock friend
        if mockProfiles.count >= 3 {
            mockFriends = [
                Friend(
                    id: "friend_1",
                    friendProfile: mockProfiles[2],
                    connectedAt: Date().addingTimeInterval(-604800) // 1 week ago
                )
            ]
        }
    }

    // Mock current user profile
    static let mockCurrentUserProfile = Profile(
        name: "You",
        age: 22,
        location: Location(city: "San Francisco", state: "CA", coordinates: nil),
        bio: "Current user profile",
        photos: [],
        interests: ["Coding", "Music"],
        personality: Personality(introvertExtrovert: 0.5, spontaneousPlanner: 0.5, activeRelaxed: 0.5),
        socialPreferences: SocialPreferences(groupSize: "Small groups (3-5)", meetingFrequency: "Weekly", preferredTimes: ["Evenings"]),
        friendshipGoals: []
    )
}
