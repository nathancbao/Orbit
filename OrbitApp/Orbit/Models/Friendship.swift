import Foundation

// MARK: - Friend Request Status

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

// MARK: - Friend Request

struct FriendRequest: Codable, Identifiable {
    var id: Int
    var fromUserId: Int
    var toUserId: Int
    var status: FriendRequestStatus
    var createdAt: String

    // Enriched profile of the other user (populated by backend)
    var fromUser: FriendProfile?
    var toUser: FriendProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId   = "to_user_id"
        case status
        case createdAt  = "created_at"
        case fromUser   = "from_user"
        case toUser     = "to_user"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Backend may return id as string or int
        id          = (try? c.decode(Int.self, forKey: .id))
                    ?? Int((try? c.decode(String.self, forKey: .id)) ?? "") ?? 0
        fromUserId  = (try? c.decode(Int.self, forKey: .fromUserId))
                    ?? Int((try? c.decode(String.self, forKey: .fromUserId)) ?? "") ?? 0
        toUserId    = (try? c.decode(Int.self, forKey: .toUserId))
                    ?? Int((try? c.decode(String.self, forKey: .toUserId)) ?? "") ?? 0
        status      = (try? c.decode(FriendRequestStatus.self, forKey: .status)) ?? .pending
        createdAt   = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        fromUser    = try? c.decodeIfPresent(FriendProfile.self, forKey: .fromUser)
        toUser      = try? c.decodeIfPresent(FriendProfile.self, forKey: .toUser)
    }
}

// MARK: - Friendship (accepted)

struct Friendship: Codable, Identifiable {
    var id: Int
    var userId: Int
    var friendId: Int
    var createdAt: String

    var friend: FriendProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case friendId = "friend_id"
        case createdAt = "created_at"
        case friend
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Backend may return id as string or int
        id        = (try? c.decode(Int.self, forKey: .id))
                  ?? Int((try? c.decode(String.self, forKey: .id)) ?? "") ?? 0
        userId    = (try? c.decode(Int.self, forKey: .userId))
                  ?? Int((try? c.decode(String.self, forKey: .userId)) ?? "") ?? 0
        friendId  = (try? c.decode(Int.self, forKey: .friendId))
                  ?? Int((try? c.decode(String.self, forKey: .friendId)) ?? "") ?? 0
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        friend    = try? c.decodeIfPresent(FriendProfile.self, forKey: .friend)
    }
}

// MARK: - Friend Profile (lightweight, like PodMember)

struct FriendProfile: Codable, Identifiable {
    var userId: Int
    var name: String
    var collegeYear: String
    var interests: [String]
    var photo: String?
    var bio: String

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case name
        case collegeYear = "college_year"
        case interests
        case photo
        case bio
    }

    private enum FallbackKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fb = try decoder.container(keyedBy: FallbackKeys.self)
        userId      = (try? c.decode(Int.self, forKey: .userId))
                    ?? Int((try? c.decode(String.self, forKey: .userId)) ?? "")
                    ?? (try? fb.decode(Int.self, forKey: .id))
                    ?? Int((try? fb.decode(String.self, forKey: .id)) ?? "")
                    ?? 0
        name        = (try? c.decode(String.self, forKey: .name)) ?? "User"
        collegeYear = (try? c.decode(String.self, forKey: .collegeYear)) ?? ""
        interests   = (try? c.decode([String].self, forKey: .interests)) ?? []
        photo       = try? c.decodeIfPresent(String.self, forKey: .photo)
        bio         = (try? c.decode(String.self, forKey: .bio)) ?? ""
    }
}

// MARK: - Friend Status (relationship check between two users)

struct FriendStatus: Codable {
    var status: String   // "none" | "pending_sent" | "pending_received" | "friends"
    var requestId: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case requestId = "request_id"
    }

    init(status: String, requestId: Int?) {
        self.status = status
        self.requestId = requestId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status    = (try? c.decode(String.self, forKey: .status)) ?? "none"
        requestId = (try? c.decode(Int.self, forKey: .requestId))
                  ?? Int((try? c.decode(String.self, forKey: .requestId)) ?? "")
    }
}
