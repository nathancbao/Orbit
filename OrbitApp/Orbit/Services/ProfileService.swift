import Foundation
import UIKit

class ProfileService {
    static let shared = ProfileService()
    private init() {}

    func updateProfile(_ profile: Profile) async throws -> ProfileResponseData {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let profileData = try encoder.encode(profile)
        var body = (try JSONSerialization.jsonObject(with: profileData) as? [String: Any]) ?? [:]
        // Remove server-computed fields before sending
        body.removeValue(forKey: "match_score")
        body.removeValue(forKey: "trust_score")
        body.removeValue(forKey: "email")

        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            method: "PUT",
            body: body,
            authenticated: true
        )
    }

    func getProfile() async throws -> Profile {
        let response: ProfileResponseData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            authenticated: true
        )
        return response.profile
    }

    func uploadPhoto(_ image: UIImage) async throws -> ProfileResponseData {
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
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.noData }
        if httpResponse.statusCode >= 400 {
            throw NetworkError.serverError("Photo upload failed with status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<ProfileResponseData>.self, from: data)
        guard let responseData = apiResponse.data else { throw NetworkError.noData }
        return responseData
    }
}
