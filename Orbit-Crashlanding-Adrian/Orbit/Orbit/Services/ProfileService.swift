//
//  ProfileService.swift
//  Orbit
//
//  Handles all profile-related API calls.
//  Set useMockData = false to use real server.
//

import Foundation

class ProfileService {
    static let shared = ProfileService()
    private init() {}

    // Set to false when server is ready
    private let useMockData = false

    // Update profile
    func updateProfile(_ profile: Profile) async throws -> ProfileResponseData {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            return ProfileResponseData(profile: profile, profileComplete: true)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let profileData = try encoder.encode(profile)
        let body = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] ?? [:]

        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            method: "PUT",
            body: body,
            authenticated: true
        )
    }

    // Get profile
    func getProfile() async throws -> Profile {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return Profile(
                name: "",
                age: 18,
                location: Location(city: "", state: "", coordinates: nil),
                bio: "",
                photos: [],
                interests: [],
                personality: Personality(
                    introvertExtrovert: 0.5,
                    spontaneousPlanner: 0.5,
                    activeRelaxed: 0.5
                ),
                socialPreferences: SocialPreferences(
                    groupSize: "Small groups (3-5)",
                    meetingFrequency: "Weekly",
                    preferredTimes: []
                ),
                friendshipGoals: []
            )
        }

        let response: ProfileResponseData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            method: "GET",
            authenticated: true
        )
        return response.profile
    }
}
