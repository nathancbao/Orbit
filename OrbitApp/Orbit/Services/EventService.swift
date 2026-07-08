//
//  MissionService.swift (stored as EventService.swift)
//  Orbit
//
//  API client for missions (formerly EventService).
//

import Foundation
import UIKit

class MissionService {
    static let shared = MissionService()
    private init() {}

    // MARK: - Unified Missions (new Mission kind, both modes)

    /// Build the availability payload shared by flex create/update.
    private func availabilityPayload(_ availability: [AvailabilitySlot]) -> [[String: Any]] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return availability.map { slot in
            if !slot.hours.isEmpty {
                return ["date": df.string(from: slot.date), "hours": slot.hours]
            }
            return ["date": df.string(from: slot.date),
                    "time_blocks": slot.timeBlocks.map(\.rawValue)]
        }
    }

    /// Create a mission of either mode in the unified Mission kind.
    func createUnifiedMission(
        mode: MissionMode,
        title: String,
        description: String,
        tags: [String],
        logo: String?,
        images: [String],
        minPodSize: Int,
        maxPodSize: Int,
        location: String = "",
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        availability: [AvailabilitySlot] = [],
        timeRangeStart: Int? = nil,
        timeRangeEnd: Int? = nil,
        links: [String] = [],
        schedulingWindowDays: Int? = nil
    ) async throws -> Mission {
        var body = unifiedBody(
            mode: mode, title: title, description: description, tags: tags,
            logo: logo, images: images, minPodSize: minPodSize, maxPodSize: maxPodSize,
            location: location, date: date, startTime: startTime, endTime: endTime,
            availability: availability, timeRangeStart: timeRangeStart,
            timeRangeEnd: timeRangeEnd, links: links, schedulingWindowDays: schedulingWindowDays
        )
        body["utc_offset"] = TimeZone.current.secondsFromGMT()
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missions,
            method: "POST", body: body, authenticated: true
        )
    }

    /// Update a mission of either mode in the unified Mission kind.
    func updateUnifiedMission(
        id: String,
        mode: MissionMode,
        title: String,
        description: String,
        tags: [String],
        logo: String?,
        images: [String],
        minPodSize: Int,
        maxPodSize: Int,
        location: String = "",
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        availability: [AvailabilitySlot] = [],
        timeRangeStart: Int? = nil,
        timeRangeEnd: Int? = nil,
        links: [String] = [],
        schedulingWindowDays: Int? = nil
    ) async throws -> Mission {
        var body = unifiedBody(
            mode: mode, title: title, description: description, tags: tags,
            logo: logo, images: images, minPodSize: minPodSize, maxPodSize: maxPodSize,
            location: location, date: date, startTime: startTime, endTime: endTime,
            availability: availability, timeRangeStart: timeRangeStart,
            timeRangeEnd: timeRangeEnd, links: links, schedulingWindowDays: schedulingWindowDays
        )
        body["utc_offset"] = TimeZone.current.secondsFromGMT()
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "PUT", body: body, authenticated: true
        )
    }

    private func unifiedBody(
        mode: MissionMode, title: String, description: String, tags: [String],
        logo: String?, images: [String], minPodSize: Int, maxPodSize: Int,
        location: String, date: String?, startTime: String?, endTime: String?,
        availability: [AvailabilitySlot], timeRangeStart: Int?, timeRangeEnd: Int?,
        links: [String], schedulingWindowDays: Int?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "mode": mode.rawValue,
            "title": title,
            "description": description,
            "tags": tags,
            "min_pod_size": minPodSize,
            "max_pod_size": maxPodSize,
            "images": images,
            "location": location,
        ]
        if let logo { body["logo"] = logo }
        // Links are optional on both set and flex missions (max 3).
        // Always sent so clearing links on edit persists.
        body["links"] = links

        if mode == .set {
            if let date { body["date"] = date }
            if let startTime { body["start_time"] = startTime }
            if let endTime { body["end_time"] = endTime }
        } else {
            body["availability"] = availabilityPayload(availability)
            if let timeRangeStart { body["time_range_start"] = timeRangeStart }
            if let timeRangeEnd { body["time_range_end"] = timeRangeEnd }
            if let schedulingWindowDays { body["scheduling_window_days"] = schedulingWindowDays }
        }
        return body
    }

    /// Upload a single mission image, returning its public URL.
    func uploadMissionImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.noData
        }
        let boundary = UUID().uuidString
        let url = URL(string: Constants.API.baseURL + Constants.API.Endpoints.uploadMissionImage)!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"mission.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.noData }
        if httpResponse.statusCode >= 400 {
            throw NetworkError.serverError("Image upload failed with status \(httpResponse.statusCode)")
        }
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<MissionImageUploadData>.self, from: data)
        guard let urlString = apiResponse.data?.url else { throw NetworkError.noData }
        return urlString
    }

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
                       maxPodSize: Int = 4, logo: String? = nil) async throws -> Mission {
        var body: [String: Any] = [
            "title": title, "description": description,
            "tags": tags, "location": location,
            "date": date, "max_pod_size": maxPodSize,
            "utc_offset": TimeZone.current.secondsFromGMT(),
        ]
        if let startTime { body["start_time"] = startTime }
        if let endTime { body["end_time"] = endTime }
        if let logo { body["logo"] = logo }
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
        maxPodSize: Int = 4,
        logo: String? = nil
    ) async throws -> Mission {
        var body: [String: Any] = [
            "title": title, "description": description,
            "tags": tags, "location": location,
            "date": date, "max_pod_size": maxPodSize,
            "utc_offset": TimeZone.current.secondsFromGMT(),
        ]
        if let startTime { body["start_time"] = startTime }
        if let endTime { body["end_time"] = endTime }
        if let logo { body["logo"] = logo }
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
        timeRangeEnd: Int = 21,
        logo: String? = nil
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
        if let logo { body["logo"] = logo }

        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signals,
            method: "POST", body: body, authenticated: true
        )
        var mission = Mission.fromSignal(signal)
        mission.tags = tags
        if let logo { mission.logo = logo }
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
        timeRangeEnd: Int = 21,
        logo: String? = nil
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
        if let logo { body["logo"] = logo }

        let signal: Signal = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.signal(id),
            method: "PUT", body: body, authenticated: true
        )
        var mission = Mission.fromSignal(signal)
        mission.tags = tags
        if let logo { mission.logo = logo }
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

struct MissionImageUploadData: Codable {
    let url: String
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

