import Foundation

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func listNotifications(limit: Int = 50) async throws -> NotificationsResponse {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notifications + "?limit=\(limit)",
            authenticated: true
        )
    }

    func markRead(ids: [String]) async throws {
        let body: [String: Any] = ["notification_ids": ids]
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notificationsRead,
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func markAllRead() async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notificationsReadAll,
            method: "POST",
            authenticated: true
        )
    }

    func getUnreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.notificationsUnreadCount,
            authenticated: true
        )
        return response.unreadCount
    }

    func registerDeviceToken(_ token: String) async throws {
        let body: [String: Any] = ["token": token]
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.devices,
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func unregisterDeviceToken(_ token: String) async throws {
        let body: [String: Any] = ["token": token]
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.devices,
            method: "DELETE",
            body: body,
            authenticated: true
        )
    }
}

// EmptyResponse is defined in EventService.swift
