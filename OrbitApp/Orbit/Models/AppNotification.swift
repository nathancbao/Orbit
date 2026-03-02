import Foundation

struct AppNotification: Codable, Identifiable {
    var id: String
    var type: String        // pod_join, pod_leave, chat_message, recommended_event
    var title: String
    var body: String
    var data: [String: String]?
    var read: Bool
    var createdAt: String

    var icon: String {
        switch type {
        case "pod_join":           return "person.badge.plus"
        case "pod_leave":          return "person.badge.minus"
        case "chat_message":       return "message.fill"
        case "recommended_event":  return "sparkles"
        default:                   return "bell.fill"
        }
    }

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Try with fractional seconds first, then without
        guard let date = formatter.date(from: createdAt)
                ?? ISO8601DateFormatter().date(from: createdAt) else {
            return ""
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct NotificationsResponse: Codable {
    var notifications: [AppNotification]
    var unreadCount: Int
}

struct UnreadCountResponse: Codable {
    var unreadCount: Int
}
