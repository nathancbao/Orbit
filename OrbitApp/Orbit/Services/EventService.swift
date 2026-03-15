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
                       location: String, date: String,
                       startTime: String? = nil, endTime: String? = nil,
                       maxPodSize: Int = 4) async throws -> Mission {
        var body: [String: Any] = [
            "title": title, "description": description,
            "tags": tags, "location": location,
            "date": date, "max_pod_size": maxPodSize,
            "utc_offset": TimeZone.current.secondsFromGMT(),
        ]
        if let startTime { body["start_time"] = startTime }
        if let endTime { body["end_time"] = endTime }
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missions,
            method: "POST", body: body, authenticated: true
        )
    }

    func updateMission(
        id: String,
        title: String,
        description: String,
        tags: [String],
        location: String,
        date: String,
        startTime: String? = nil,
        endTime: String? = nil,
        maxPodSize: Int = 4
    ) async throws -> Mission {
        var body: [String: Any] = [
            "title": title, "description": description,
            "tags": tags, "location": location,
            "date": date, "max_pod_size": maxPodSize,
            "utc_offset": TimeZone.current.secondsFromGMT(),
        ]
        if let startTime { body["start_time"] = startTime }
        if let endTime { body["end_time"] = endTime }
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "PUT", body: body, authenticated: true
        )
    }

    func joinMission(id: String, podId: String? = nil) async throws -> Pod {
        var body: [String: Any]? = nil
        if let podId = podId {
            body = ["pod_id": podId]
        }
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.joinMission(id),
            method: "POST", body: body, authenticated: true
        )
    }

    func leaveMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.leaveMission(id),
            method: "DELETE", authenticated: true
        )
    }

    func deleteSetMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "DELETE", authenticated: true
        )
    }

    func skipMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.skipMission(id),
            method: "POST", authenticated: true
        )
    }

    // MARK: - Flex Mode (calls signal endpoints directly)

    func listFlexMissions() async throws -> [Mission] {
        let response: SignalDiscoverResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.discoverSignals,
            authenticated: true
        )
        return response.signals.map { Mission.fromSignal($0) }
    }

    func myFlexMissions() async throws -> [Mission] {
        let signals: [Signal] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            authenticated: true
        )
        return signals.map { Mission.fromSignal($0) }
    }

    func createFlexMission(
        title: String = "",
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String,
        links: [String] = [],
        tags: [String] = [],
        timeRangeStart: Int = 9,
        timeRangeEnd: Int = 21
    ) async throws -> Mission {
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

        let resolvedTitle: String
        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedTitle = title.trimmingCharacters(in: .whitespaces)
        } else {
            resolvedTitle = "Flex Mission"
        }

        var body: [String: Any] = [
            "title": resolvedTitle,
            "min_group_size": minGroupSize,
            "max_group_size": maxGroupSize,
            "availability": slotsPayload,
            "description": description,
            "time_range_start": timeRangeStart,
            "time_range_end": timeRangeEnd,
        ]
        if !links.isEmpty {
            body["links"] = links
        }
        if !tags.isEmpty {
            body["tags"] = tags
        }

        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            method: "POST", body: body, authenticated: true
        )
        var mission = Mission.fromSignal(signal)
        mission.tags = tags
        return mission
    }

    func updateFlexMission(
        id: String,
        title: String = "",
        minGroupSize: Int,
        maxGroupSize: Int,
        availability: [AvailabilitySlot],
        description: String,
        links: [String] = [],
        tags: [String] = [],
        timeRangeStart: Int = 9,
        timeRangeEnd: Int = 21
    ) async throws -> Mission {
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

        let resolvedTitle: String
        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedTitle = title.trimmingCharacters(in: .whitespaces)
        } else {
            resolvedTitle = "Flex Mission"
        }

        var body: [String: Any] = [
            "title": resolvedTitle,
            "min_group_size": minGroupSize,
            "max_group_size": maxGroupSize,
            "availability": slotsPayload,
            "description": description,
            "time_range_start": timeRangeStart,
            "time_range_end": timeRangeEnd,
        ]
        if !links.isEmpty { body["links"] = links }
        if !tags.isEmpty { body["tags"] = tags }

        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            method: "PUT", body: body, authenticated: true
        )
        var mission = Mission.fromSignal(signal)
        mission.tags = tags
        return mission
    }

    func joinFlexMission(id: String) async throws -> Mission {
        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.rsvpSignal(id),
            method: "POST", authenticated: true
        )
        return Mission.fromSignal(signal)
    }

    func deleteFlexMission(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            method: "DELETE", authenticated: true
        )
    }

    func getFlexMission(id: String) async throws -> Mission {
        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            authenticated: true
        )
        return Mission.fromSignal(signal)
    }

    func rsvpedFlexMissions() async throws -> [Mission] {
        let signals: [Signal] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.myRsvps,
            authenticated: true
        )
        return signals.map { Mission.fromSignal($0) }
    }

    /// Fetches set missions + flex missions concurrently, returns merged array.
    func listAllMissions(tag: String? = nil, year: String? = nil) async throws -> [Mission] {
        async let setMissions = listMissions(tag: tag, year: year)
        async let flexMissions = listFlexMissions()
        let (s, f) = try await (setMissions, flexMissions)
        return s + f
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

