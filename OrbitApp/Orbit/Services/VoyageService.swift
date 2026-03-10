//
//  VoyageService.swift
//  Orbit
//
//  API calls for Voyage mode endpoints.
//

import Foundation

class VoyageService {
    static let shared = VoyageService()
    private init() {}

    /// Fetch tile clusters for a region around (x, y) with the given radius.
    func fetchClusters(x: Int, y: Int, radius: Int = 2) async throws -> [VoyageTile] {
        let endpoint = "\(Constants.API.Endpoints.voyageClusters)?x=\(x)&y=\(y)&radius=\(radius)"
        let response: VoyageClustersResponse = try await APIService.shared.request(
            endpoint: endpoint, authenticated: true
        )
        return response.tiles
    }

    /// Send heartbeat with current tile position.
    func sendHeartbeat(tileX: Int, tileY: Int) async throws {
        let body: [String: Any] = ["tile_x": tileX, "tile_y": tileY]
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.voyageHeartbeat,
            method: "POST", body: body, authenticated: true
        )
    }

    /// End voyage mode.
    func endVoyage() async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.voyageHeartbeat,
            method: "DELETE", authenticated: true
        )
    }
}

// MARK: - Response Types

struct VoyageClustersResponse: Codable {
    let tiles: [VoyageTile]
}

struct VoyageTile: Codable, Identifiable {
    let x: Int
    let y: Int
    let items: [VoyageItem]

    var id: String { "\(x),\(y)" }
}

struct VoyageItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let tags: [String]
    let itemType: String
    let status: String

    // Mission fields
    let date: String?
    let location: String?
    let startTime: String?
    let endTime: String?
    let maxPodSize: Int?

    // Signal/flex fields
    let activityCategory: String?
    let minGroupSize: Int?
    let maxGroupSize: Int?
    let creatorId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description, tags, status, date, location
        case itemType = "item_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case maxPodSize = "max_pod_size"
        case activityCategory = "activity_category"
        case minGroupSize = "min_group_size"
        case maxGroupSize = "max_group_size"
        case creatorId = "creator_id"
    }

    var isMission: Bool { itemType == "mission" }
    var isSignal: Bool { itemType == "signal" }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let cat = activityCategory, !cat.isEmpty { return cat }
        return "Activity"
    }
}