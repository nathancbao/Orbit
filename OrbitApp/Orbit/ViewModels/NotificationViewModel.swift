import Foundation

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false

    func load() async {
        isLoading = true
        do {
            let response = try await NotificationService.shared.listNotifications()
            notifications = response.notifications
            unreadCount = response.unreadCount
        } catch {
            print("Failed to load notifications: \(error)")
        }
        isLoading = false
    }

    func markRead(_ ids: [String]) async {
        do {
            try await NotificationService.shared.markRead(ids: ids)
            // Update local state
            for i in notifications.indices {
                if ids.contains(notifications[i].id) {
                    notifications[i].read = true
                }
            }
            unreadCount = notifications.filter { !$0.read }.count
        } catch {
            print("Failed to mark notifications read: \(error)")
        }
    }

    func markAllRead() async {
        do {
            try await NotificationService.shared.markAllRead()
            for i in notifications.indices {
                notifications[i].read = true
            }
            unreadCount = 0
        } catch {
            print("Failed to mark all read: \(error)")
        }
    }

    func refreshBadge() async {
        do {
            unreadCount = try await NotificationService.shared.getUnreadCount()
        } catch {
            print("Failed to refresh badge: \(error)")
        }
    }
}
