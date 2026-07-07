//
//  AnalyticsService.swift
//  Orbit
//
//  Lightweight client-side analytics (Batch G).
//
//  Buffers engagement events in memory and flushes them as a batch to
//  POST /api/analytics/events on a size threshold and on app foreground/
//  background transitions. The server owns identity and timing — it stamps
//  received_ts and derives the pseudonymous user id — so this client only
//  reports what the user did, never who they are.
//
//  Design contract: docs/analytics-and-metrics.md. Only low-sensitivity
//  engagement events the server can't observe itself are sent from here
//  (app_opened, mission_viewed, notification_opened); authoritative events
//  (joins, surveys, …) are emitted server-side.
//
//  Best-effort: analytics must never disrupt the app. Failures are swallowed;
//  a failed flush keeps events buffered for the next attempt, and the buffer is
//  capped so it can never grow without bound offline.
//

import Foundation

/// Well-known client event names. Mirrors the server catalog in
/// `analytics_service.ALLOWED_EVENTS`; anything else is dropped server-side.
enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case missionViewed = "mission_viewed"
    case notificationOpened = "notification_opened"
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    /// One session id per app foreground session (regenerated on foreground).
    private var sessionId = UUID().uuidString
    /// JSON-ready event envelopes awaiting flush.
    private var buffer: [[String: Any]] = []
    private var isFlushing = false

    /// Flush once the buffer reaches this many events.
    private let flushThreshold = 20
    /// Hard cap so an offline session can't grow the buffer unbounded — oldest
    /// events are dropped first.
    private let maxBuffer = 200

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private init() {}

    // MARK: - Public API

    /// Record a client event. Non-blocking; the network flush happens later.
    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        var envelope: [String: Any] = [
            "event_name": event.rawValue,
            "event_id": UUID().uuidString,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "session_id": sessionId,
            "app_version": appVersion,
        ]
        if !properties.isEmpty {
            envelope["properties"] = properties
        }

        buffer.append(envelope)
        if buffer.count > maxBuffer {
            buffer.removeFirst(buffer.count - maxBuffer)
        }
        if buffer.count >= flushThreshold {
            Task { await flush() }
        }
    }

    /// Start a fresh session (call on app foreground) and flush anything held.
    func startSession() {
        sessionId = UUID().uuidString
        Task { await flush() }
    }

    /// Send buffered events to the backend. Best-effort — never throws.
    func flush() async {
        guard !isFlushing, !buffer.isEmpty else { return }
        // Nothing to send if the user isn't authenticated yet; keep buffering.
        guard KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken) != nil else {
            return
        }

        isFlushing = true
        defer { isFlushing = false }

        // Take a snapshot so events tracked during the request aren't lost.
        let batch = Array(buffer.prefix(100))
        do {
            let _: AnalyticsIngestResponse = try await APIService.shared.request(
                endpoint: Constants.API.Endpoints.analyticsEvents,
                method: "POST",
                body: ["events": batch],
                authenticated: true
            )
            // Drop exactly the events we sent; any tracked meanwhile remain.
            buffer.removeFirst(min(batch.count, buffer.count))
        } catch {
            // Keep the buffer for the next attempt; analytics never surfaces
            // an error to the user.
        }
    }
}

// MARK: - Response

private struct AnalyticsIngestResponse: Codable {
    let accepted: Int
    let rejected: Int
}
