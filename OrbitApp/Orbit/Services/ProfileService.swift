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
        // Remove server-computed and gallery-managed fields before sending
        body.removeValue(forKey: "match_score")
        body.removeValue(forKey: "trust_score")
        body.removeValue(forKey: "email")
        body.removeValue(forKey: "gallery_photos")
        body = body.filter { !($0.value is NSNull) }

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

    func getUserProfile(id: Int) async throws -> Profile {
        let response: ProfileResponseData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.userProfile(id),
            authenticated: true
        )
        return response.profile
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.me,
            method: "DELETE",
            authenticated: true
        )
    }

    /// Downscale an image so its longest side is at most `maxDimension` points.
    private func downscaled(_ image: UIImage, maxDimension: CGFloat = 512) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    func uploadPhoto(_ image: UIImage) async throws -> ProfileResponseData {
        let resized = downscaled(image)
        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
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

    func uploadGalleryPhoto(_ image: UIImage) async throws -> ProfileResponseData {
        let resized = downscaled(image)
        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.noData
        }

        let boundary = UUID().uuidString
        let url = URL(string: Constants.API.baseURL + Constants.API.Endpoints.uploadGalleryPhoto)!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"gallery.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.noData }
        if httpResponse.statusCode >= 400 {
            throw NetworkError.serverError("Gallery upload failed with status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<ProfileResponseData>.self, from: data)
        guard let responseData = apiResponse.data else { throw NetworkError.noData }
        return responseData
    }

    func deleteGalleryPhoto(at index: Int) async throws -> ProfileResponseData {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.deleteGalleryPhoto(index),
            method: "DELETE",
            authenticated: true
        )
    }
}
