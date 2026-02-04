import Foundation

struct User: Codable, Identifiable {
    let id: String
    let phoneNumber: String
    let profileComplete: Bool
    let createdAt: Date
    let profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case profileComplete = "profile_complete"
        case createdAt = "created_at"
        case profile
    }
}
