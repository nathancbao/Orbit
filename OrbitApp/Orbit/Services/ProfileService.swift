//
//  ProfileService.swift
//  Orbit
//
//  Handles all profile-related API calls.
//  Set useMockData = false to use real server.
//

import Foundation
import UIKit

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
        var body = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] ?? [:]

        // Remove photos from update - they're handled by uploadPhoto separately
        body.removeValue(forKey: "photos")

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

    // Clear all photos from profile
    func clearPhotos() async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }

        let body: [String: Any] = ["photos": []]
        let _: ProfileResponseData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            method: "PUT",
            body: body,
            authenticated: true
        )
    }

    // Upload a photo
    func uploadPhoto(_ image: UIImage) async throws -> ProfileResponseData {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return ProfileResponseData(
                profile: Profile(
                    name: "", age: 18,
                    location: Location(city: "", state: "", coordinates: nil),
                    bio: "", photos: ["mock_url"], interests: [],
                    personality: Personality(introvertExtrovert: 0.5, spontaneousPlanner: 0.5, activeRelaxed: 0.5),
                    socialPreferences: SocialPreferences(groupSize: "", meetingFrequency: "", preferredTimes: []),
                    friendshipGoals: []
                ),
                profileComplete: false
            )
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.noData
        }

        let boundary = UUID().uuidString
        let url = URL(string: Constants.API.baseURL + Constants.API.Endpoints.uploadPhoto)!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        if httpResponse.statusCode >= 400 {
            throw NetworkError.serverError("Photo upload failed with status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<ProfileResponseData>.self, from: data)
        guard let responseData = apiResponse.data else {
            throw NetworkError.noData
        }
        return responseData
    }
}
