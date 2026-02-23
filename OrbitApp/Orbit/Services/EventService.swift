import Foundation

class EventService {
    static let shared = EventService()
    private init() {}

    func listEvents(tag: String? = nil, year: String? = nil) async throws -> [Event] {
        var endpoint = Constants.API.Endpoints.events
        var params: [String] = []
        if let tag = tag { params.append("tag=\(tag)") }
        if let year = year { params.append("year=\(year)") }
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }
        return try await APIService.shared.request(endpoint: endpoint, authenticated: true)
    }

    func suggestedEvents() async throws -> [Event] {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.suggestedEvents,
            authenticated: true
        )
    }

    func getEvent(id: String) async throws -> Event {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.event(id),
            authenticated: true
        )
    }

    func createEvent(title: String, description: String, tags: [String],
                     location: String, date: String, maxPodSize: Int = 4) async throws -> Event {
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "tags": tags,
            "location": location,
            "date": date,
            "max_pod_size": maxPodSize,
        ]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.events,
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func joinEvent(id: String) async throws -> EventPod {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.joinEvent(id),
            method: "POST",
            authenticated: true
        )
    }

    func leaveEvent(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.leaveEvent(id),
            method: "DELETE",
            authenticated: true
        )
    }

    func skipEvent(id: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.skipEvent(id),
            method: "POST",
            authenticated: true
        )
    }
}

// Used for endpoints that return { "message": "..." }
struct EmptyResponse: Codable {
    var message: String?
}
