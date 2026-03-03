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
        var endpoint = Constants.API.Endpoints.missions
        var params: [String] = []
        if let tag = tag { params.append("tag=\(tag)") }
        if let year = year { params.append("year=\(year)") }
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }
        return try await APIService.shared.request(endpoint: endpoint, authenticated: true)
    }

    func suggestedMissions() async throws -> [Mission] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.suggestedMissions,
            authenticated: true
        )
    }

    func getMission(id: String) async throws -> Mission {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
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
            endpoint: Constants.API.Endpoints.missions,
            method: "POST", body: body, authenticated: true
        )
    }

    func joinMission(id: String) async throws -> Pod {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.joinMission(id),
            method: "POST", authenticated: true
        )
    }

    func leaveMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.leaveMission(id),
            method: "DELETE", authenticated: true
        )
    }

    func skipMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.skipMission(id),
            method: "POST", authenticated: true
        )
    }
}

struct EmptyResponse: Codable {
    var message: String?
}


// MARK: - Signal Discover Response
// Backend wraps discover signals in {"signals": [...], "next_cursor": ...}.

struct SignalDiscoverResponse: Codable {
    let signals: [Signal]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case signals
        case nextCursor = "next_cursor"
    }
}

// MARK: - Signal Service
// API client for signals (backend: /api/signals).

class SignalService {
    static let shared = SignalService()
    private init() {}

    func discoverSignals() async throws -> [Signal] {
        let response: SignalDiscoverResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.discoverSignals,
            authenticated: true
        )
        return response.signals
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
        description: String,
        links: [String] = [],
        timeRangeStart: Int = 9,
        timeRangeEnd: Int = 21
    ) async throws -> Signal {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let slotsPayload: [[String: Any]] = availability.map { slot in
            if !slot.hours.isEmpty {
                return [
                    "date": dateFormatter.string(from: slot.date),
                    "hours": slot.hours,
                ]
            } else {
                return [
                    "date": dateFormatter.string(from: slot.date),
                    "time_blocks": slot.timeBlocks.map(\.rawValue),
                ]
            }
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
            "time_range_start": timeRangeStart,
            "time_range_end": timeRangeEnd,
        ]
        if let name = customActivityName, !name.isEmpty {
            body["custom_activity_name"] = name
        }
        if !links.isEmpty {
            body["links"] = links
        }

        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            method: "POST", body: body, authenticated: true
        )
    }

    func rsvpSignal(id: String) async throws -> Signal {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.rsvpSignal(id),
            method: "POST", authenticated: true
        )
    }

    func deleteSignal(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            method: "DELETE", authenticated: true
        )
    }
}
