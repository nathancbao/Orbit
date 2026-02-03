import Foundation

// Generic API response wrapper
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}

// Common response data types
struct MessageData: Codable {
    let message: String
}

struct AuthResponseData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let isNewUser: Bool
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case isNewUser = "is_new_user"
        case userId = "user_id"
    }
}

struct ProfileResponseData: Codable {
    let profile: Profile
    let profileComplete: Bool

    enum CodingKeys: String, CodingKey {
        case profile
        case profileComplete = "profile_complete"
    }
}
