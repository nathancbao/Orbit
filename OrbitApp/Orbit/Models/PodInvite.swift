import Foundation

struct PodInvite: Codable, Identifiable {
    var id: Int
    var podId: String
    var fromUserId: Int
    var toUserId: Int
    var status: String
    var createdAt: String
    var fromUser: PodInviteUser?
    var podName: String?
    var missionTitle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
        case createdAt = "created_at"
        case fromUser = "from_user"
        case podName = "pod_name"
        case missionTitle = "mission_title"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id))
            ?? Int((try? c.decode(String.self, forKey: .id)) ?? "") ?? 0
        podId = (try? c.decode(String.self, forKey: .podId)) ?? ""
        fromUserId = (try? c.decode(Int.self, forKey: .fromUserId))
            ?? Int((try? c.decode(String.self, forKey: .fromUserId)) ?? "") ?? 0
        toUserId = (try? c.decode(Int.self, forKey: .toUserId))
            ?? Int((try? c.decode(String.self, forKey: .toUserId)) ?? "") ?? 0
        status = (try? c.decode(String.self, forKey: .status)) ?? "pending"
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        fromUser = try? c.decodeIfPresent(PodInviteUser.self, forKey: .fromUser)
        podName = try? c.decodeIfPresent(String.self, forKey: .podName)
        missionTitle = try? c.decodeIfPresent(String.self, forKey: .missionTitle)
    }

    /// Display label for the invite notification
    var activityLabel: String {
        if let title = missionTitle, !title.isEmpty { return title }
        if let name = podName, !name.isEmpty { return name }
        return "a pod"
    }
}

struct PodInviteUser: Codable {
    var name: String
    var photo: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        photo = try? c.decodeIfPresent(String.self, forKey: .photo)
    }

    enum CodingKeys: String, CodingKey {
        case name, photo
    }
}
