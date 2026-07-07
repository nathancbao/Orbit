import Foundation

// MARK: - App Notification (in-app inbox item)
// e.g. "the pod you were in was deleted"

struct AppNotification: Codable, Identifiable {
    var id: String
    var type: String        // pod_deleted | ...
    var title: String
    var body: String
    var read: Bool
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, read
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        read = (try? c.decode(Bool.self, forKey: .read)) ?? false
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

// MARK: - Notification Service

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    /// Fetch the user's in-app notifications, newest first.
    func getNotifications() async throws -> [AppNotification] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notifications,
            authenticated: true
        )
    }

    /// Mark all notifications as read.
    func markAllRead() async throws {
        let _: MarkReadResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notificationsRead,
            method: "POST",
            authenticated: true
        )
    }
}

struct MarkReadResponse: Codable {
    var markedRead: Int?

    enum CodingKeys: String, CodingKey {
        case markedRead = "marked_read"
    }
}
