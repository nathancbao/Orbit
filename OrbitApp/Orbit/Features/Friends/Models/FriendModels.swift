//
//  FriendModels.swift
//  Orbit
//
//  Data models for friend requests and friendships.
//

import Foundation

// MARK: - Friend Request Status

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case denied
}

// MARK: - Friend Request

struct FriendRequest: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let fromUserProfile: Profile
    let toUserProfile: Profile
    let status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case fromUserProfile = "from_user_profile"
        case toUserProfile = "to_user_profile"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Friend

struct Friend: Codable, Identifiable {
    let id: String
    let friendProfile: Profile
    let connectedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case friendProfile = "friend_profile"
        case connectedAt = "connected_at"
    }
}

// MARK: - API Response Types

struct FriendRequestResponseData: Codable {
    let request: FriendRequest
    let message: String?
}

struct FriendsListResponseData: Codable {
    let friends: [Friend]
}

struct FriendRequestsListResponseData: Codable {
    let incoming: [FriendRequest]
    let outgoing: [FriendRequest]
}

// MARK: - Friend Errors

enum FriendError: LocalizedError {
    case requestAlreadyExists
    case requestNotFound
    case alreadyFriends
    case cannotFriendSelf

    var errorDescription: String? {
        switch self {
        case .requestAlreadyExists:
            return "A friend request already exists with this user"
        case .requestNotFound:
            return "Friend request not found"
        case .alreadyFriends:
            return "You are already friends with this user"
        case .cannotFriendSelf:
            return "You cannot send a friend request to yourself"
        }
    }
}
