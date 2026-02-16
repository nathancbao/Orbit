//
//  MissionService.swift
//  Orbit
//
//  Handles mission CRUD and RSVP operations.
//  Set useMockData = false when server is ready.
//

import Foundation

class MissionService {
    static let shared = MissionService()
    private init() {
        seedMockData()
    }

    // Set to false when backend is ready
    private let useMockData = true

    // In-memory mock storage
    private var mockMissions: [Mission] = []
    private var mockRsvps: [String: RSVPType] = [:] // "missionId_userId" -> type

    private var currentUserId: Int { 999 }

    // MARK: - List Missions (Discover)

    func listMissions() async throws -> [Mission] {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockMissions.filter { !$0.isExpired }
        }

        let missions: [Mission] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missions,
            method: "GET",
            authenticated: false
        )
        return missions
    }

    // MARK: - My Missions

    func getMyMissions() async throws -> [Mission] {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockMissions.filter { mission in
                mission.creatorId == currentUserId ||
                mockRsvps.keys.contains("\(mission.id)_\(currentUserId)")
            }
        }

        let missions: [Mission] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.myMissions,
            method: "GET",
            authenticated: true
        )
        return missions
    }

    // MARK: - Get Single Mission

    func getMission(id: String) async throws -> Mission {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            guard let mission = mockMissions.first(where: { $0.id == id }) else {
                throw MissionError.notFound
            }
            return mission
        }

        let mission: Mission = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "GET",
            authenticated: false
        )
        return mission
    }

    // MARK: - Create Mission

    func createMission(data: [String: Any]) async throws -> Mission {
        if useMockData {
            try await Task.sleep(nanoseconds: 400_000_000)
            let mission = Mission(
                id: UUID().uuidString,
                title: data["title"] as? String ?? "",
                description: data["description"] as? String ?? "",
                tags: data["tags"] as? [String] ?? [],
                location: data["location"] as? String ?? "",
                startTime: data["start_time"] as? String ?? "",
                endTime: data["end_time"] as? String ?? "",
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double,
                links: data["links"] as? [String] ?? [],
                images: data["images"] as? [String] ?? [],
                maxParticipants: data["max_participants"] as? Int ?? 0,
                creatorId: currentUserId,
                hardRsvpCount: 0,
                softRsvpCount: 0,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            mockMissions.insert(mission, at: 0)
            return mission
        }

        let mission: Mission = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missions,
            method: "POST",
            body: data,
            authenticated: true
        )
        return mission
    }

    // MARK: - Update Mission

    func updateMission(id: String, data: [String: Any]) async throws -> Mission {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            guard let index = mockMissions.firstIndex(where: { $0.id == id }) else {
                throw MissionError.notFound
            }
            let old = mockMissions[index]
            let updated = Mission(
                id: old.id,
                title: data["title"] as? String ?? old.title,
                description: data["description"] as? String ?? old.description,
                tags: data["tags"] as? [String] ?? old.tags,
                location: data["location"] as? String ?? old.location,
                startTime: data["start_time"] as? String ?? old.startTime,
                endTime: data["end_time"] as? String ?? old.endTime,
                latitude: data["latitude"] as? Double ?? old.latitude,
                longitude: data["longitude"] as? Double ?? old.longitude,
                links: data["links"] as? [String] ?? old.links,
                images: data["images"] as? [String] ?? old.images,
                maxParticipants: data["max_participants"] as? Int ?? old.maxParticipants,
                creatorId: old.creatorId,
                hardRsvpCount: old.hardRsvpCount,
                softRsvpCount: old.softRsvpCount,
                createdAt: old.createdAt
            )
            mockMissions[index] = updated
            return updated
        }

        let mission: Mission = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "PUT",
            body: data,
            authenticated: true
        )
        return mission
    }

    // MARK: - Delete Mission

    func deleteMission(id: String) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            mockMissions.removeAll { $0.id == id }
            mockRsvps = mockRsvps.filter { !$0.key.hasPrefix("\(id)_") }
            return
        }

        struct MessageResponse: Codable { let message: String }
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.mission(id),
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - RSVP to Mission

    func rsvpToMission(id: String, rsvpType: RSVPType) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            let rsvpKey = "\(id)_\(currentUserId)"
            guard mockRsvps[rsvpKey] == nil else {
                throw MissionError.alreadyRsvped
            }
            mockRsvps[rsvpKey] = rsvpType

            // Update count
            if let index = mockMissions.firstIndex(where: { $0.id == id }) {
                let old = mockMissions[index]
                let newHard = rsvpType == .hard ? old.hardRsvpCount + 1 : old.hardRsvpCount
                let newSoft = rsvpType == .soft ? old.softRsvpCount + 1 : old.softRsvpCount
                mockMissions[index] = Mission(
                    id: old.id, title: old.title, description: old.description,
                    tags: old.tags, location: old.location,
                    startTime: old.startTime, endTime: old.endTime,
                    latitude: old.latitude, longitude: old.longitude,
                    links: old.links, images: old.images,
                    maxParticipants: old.maxParticipants, creatorId: old.creatorId,
                    hardRsvpCount: newHard, softRsvpCount: newSoft,
                    createdAt: old.createdAt
                )
            }
            return
        }

        struct MessageResponse: Codable { let message: String }
        let body: [String: Any] = ["rsvp_type": rsvpType.rawValue]
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missionRsvp(id),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    // MARK: - Leave Mission

    func leaveMission(id: String) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            let rsvpKey = "\(id)_\(currentUserId)"
            guard let rsvpType = mockRsvps[rsvpKey] else {
                return
            }
            mockRsvps.removeValue(forKey: rsvpKey)

            if let index = mockMissions.firstIndex(where: { $0.id == id }) {
                let old = mockMissions[index]
                let newHard = rsvpType == .hard ? old.hardRsvpCount - 1 : old.hardRsvpCount
                let newSoft = rsvpType == .soft ? old.softRsvpCount - 1 : old.softRsvpCount
                mockMissions[index] = Mission(
                    id: old.id, title: old.title, description: old.description,
                    tags: old.tags, location: old.location,
                    startTime: old.startTime, endTime: old.endTime,
                    latitude: old.latitude, longitude: old.longitude,
                    links: old.links, images: old.images,
                    maxParticipants: old.maxParticipants, creatorId: old.creatorId,
                    hardRsvpCount: max(0, newHard), softRsvpCount: max(0, newSoft),
                    createdAt: old.createdAt
                )
            }
            return
        }

        struct MessageResponse: Codable { let message: String }
        let _: MessageResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missionRsvp(id),
            method: "DELETE",
            authenticated: true
        )
    }

    // MARK: - Get Participants

    func getParticipants(missionId: String) async throws -> [MissionParticipant] {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            var participants: [MissionParticipant] = []
            for (key, rsvpType) in mockRsvps where key.hasPrefix("\(missionId)_") {
                let userId = Int(key.replacingOccurrences(of: "\(missionId)_", with: "")) ?? 0
                participants.append(MissionParticipant(
                    userId: userId,
                    rsvpType: rsvpType,
                    rsvpedAt: nil,
                    profile: nil
                ))
            }
            return participants
        }

        let participants: [MissionParticipant] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.missionParticipants(missionId),
            method: "GET",
            authenticated: false
        )
        return participants
    }

    // MARK: - Check User RSVP Status

    func getUserRsvpType(missionId: String) -> RSVPType? {
        let key = "\(missionId)_\(currentUserId)"
        return mockRsvps[key]
    }

    func isCreator(mission: Mission) -> Bool {
        return mission.creatorId == currentUserId
    }

    // MARK: - Seed Mock Data

    private func seedMockData() {
        guard useMockData else { return }

        let cal = Calendar.current
        let now = Date()

        mockMissions = [
            Mission(
                id: "mission_1",
                title: "Study Group: Algorithms Final",
                description: "Let's prep for the algorithms final together! Bring your textbook and practice problems. We'll work through dynamic programming and graph algorithms.",
                tags: ["Study", "CS", "Algorithms"],
                location: "Engineering Library, Room 204",
                startTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 26, to: now)!),
                endTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 29, to: now)!),
                latitude: 37.4275,
                longitude: -122.1697,
                links: ["https://leetcode.com/studyplan/algorithm/"],
                images: [],
                maxParticipants: 8,
                creatorId: 101,
                hardRsvpCount: 3,
                softRsvpCount: 1,
                createdAt: ISO8601DateFormatter().string(from: cal.date(byAdding: .day, value: -1, to: now)!)
            ),
            Mission(
                id: "mission_2",
                title: "Sunset Hike at Dish Trail",
                description: "Casual sunset hike at the Stanford Dish. Meet at the trailhead parking lot. All fitness levels welcome!",
                tags: ["Outdoors", "Hiking", "Social"],
                location: "The Dish Trailhead",
                startTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 50, to: now)!),
                endTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 52, to: now)!),
                latitude: 37.4088,
                longitude: -122.1744,
                links: [],
                images: [],
                maxParticipants: 0,
                creatorId: 102,
                hardRsvpCount: 7,
                softRsvpCount: 3,
                createdAt: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: -5, to: now)!)
            ),
            Mission(
                id: "mission_3",
                title: "Hackathon Team Forming",
                description: "Looking for teammates for the upcoming TreeHacks hackathon. Need frontend, backend, and ML skills. Let's brainstorm project ideas!",
                tags: ["Hackathon", "Coding", "Teamwork"],
                location: "Tresidder Union, 2nd Floor",
                startTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .day, value: 3, to: now)!),
                endTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .day, value: 3, to: cal.date(byAdding: .hour, value: 2, to: now)!)!),
                latitude: 37.4241,
                longitude: -122.1710,
                links: ["https://treehacks.com"],
                images: [],
                maxParticipants: 5,
                creatorId: currentUserId,
                hardRsvpCount: 2,
                softRsvpCount: 0,
                createdAt: ISO8601DateFormatter().string(from: cal.date(byAdding: .day, value: -2, to: now)!)
            ),
            Mission(
                id: "mission_4",
                title: "Basketball Pickup Game",
                description: "5v5 pickup basketball at Arrillaga. Bring your A-game! We need exactly 10 players.",
                tags: ["Sports", "Basketball", "Fitness"],
                location: "Arrillaga Outdoor Courts",
                startTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 72, to: now)!),
                endTime: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: 74, to: now)!),
                latitude: 37.4318,
                longitude: -122.1620,
                links: [],
                images: [],
                maxParticipants: 10,
                creatorId: 103,
                hardRsvpCount: 6,
                softRsvpCount: 2,
                createdAt: ISO8601DateFormatter().string(from: cal.date(byAdding: .hour, value: -12, to: now)!)
            ),
        ]

        // Add some mock RSVPs for the current user
        mockRsvps["mission_1_\(currentUserId)"] = .hard
    }
}
