//
//  MissionService.swift (stored as EventService.swift)
//  Orbit
//
//  API client for missions (formerly EventService).
//

import Foundation

class MissionService {
    static let shared = MissionService()
    private init() {}

    func listMissions(tag: String? = nil, year: String? = nil) async throws -> [Mission] {
        var endpoint = Constants.API.Endpoints.events
        var params: [String] = []
        if let tag = tag { params.append("tag=\(tag)") }
        if let year = year { params.append("year=\(year)") }
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }
        return try await APIService.shared.request(endpoint: endpoint, authenticated: true)
    }

    func suggestedMissions() async throws -> [Mission] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.suggestedEvents,
            authenticated: true
        )
    }

    func getMission(id: String) async throws -> Mission {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.event(id),
            authenticated: true
        )
    }

    func createMission(title: String, description: String, tags: [String],
                       location: String, date: String, maxPodSize: Int = 4) async throws -> Mission {
        let body: [String: Any] = [
            "title": title, "description": description,
            "tags": tags, "location": location,
            "date": date, "max_pod_size": maxPodSize,
        ]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.events,
            method: "POST", body: body, authenticated: true
        )
    }

    func joinMission(id: String) async throws -> EventPod {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.joinEvent(id),
            method: "POST", authenticated: true
        )
    }

    func leaveMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.leaveEvent(id),
            method: "DELETE", authenticated: true
        )
    }

    func skipMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.skipEvent(id),
            method: "POST", authenticated: true
        )
    }
}

struct EmptyResponse: Codable {
    var message: String?
}


// MARK: - Signal Service
// API client for signals (backend: /api/missions).

class SignalService {
    static let shared = SignalService()
    private init() {}

    func discoverSignals() async throws -> [Signal] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.discoverSignals,
            authenticated: true
        )
    }

    func mySignals() async throws -> [Signal] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            authenticated: true
        )
    }

    func createSignal(
        activityCategory: ActivityCategory,
        customActivityName: String?,
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String
    ) async throws -> Signal {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let slotsPayload: [[String: Any]] = availability.map { slot in
            [
                "date": dateFormatter.string(from: slot.date),
                "time_blocks": slot.timeBlocks.map(\.rawValue),
            ]
        }

        let title: String
        if activityCategory == .custom {
            title = customActivityName ?? "Custom Activity"
        } else {
            title = activityCategory.displayName
        }

        var body: [String: Any] = [
            "title": title,
            "activity_category": activityCategory.rawValue,
            "min_group_size": minGroupSize,
            "max_group_size": maxGroupSize,
            "availability": slotsPayload,
            "description": description,
        ]
        if let name = customActivityName, !name.isEmpty {
            body["custom_activity_name"] = name
        }

        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            method: "POST", body: body, authenticated: true
        )
    }

    func deleteSignal(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            method: "DELETE", authenticated: true
        )
    }
}
