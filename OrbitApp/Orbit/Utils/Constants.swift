import Foundation

enum Constants {

    // ============================================================
    // MARK: - API Configuration
    // ============================================================
    enum API {
        // Local testing: "http://localhost:8080/api"
        // Production: "https://orbit-app-486204.wl.r.appspot.com/api"
        static let baseURL = "https://orbit-app-486204.wl.r.appspot.com/api"

        enum Endpoints {
            // Auth
            static let sendCode = "/auth/send-code"
            static let verifyCode = "/auth/verify-code"
            static let refreshToken = "/auth/refresh"
            static let logout = "/auth/logout"

            // User / Profile
            static let me = "/users/me"
            static let uploadPhoto = "/users/me/photo"

            // Events
            static let events = "/events"
            static let suggestedEvents = "/events/suggested"
            static func event(_ id: String) -> String { "/events/\(id)" }
            static func joinEvent(_ id: String) -> String { "/events/\(id)/join" }
            static func leaveEvent(_ id: String) -> String { "/events/\(id)/leave" }
            static func skipEvent(_ id: String) -> String { "/events/\(id)/skip" }

            // Pods
            static func pod(_ id: String) -> String { "/pods/\(id)" }
            static func podKick(_ id: String) -> String { "/pods/\(id)/kick" }
            static func podConfirm(_ id: String) -> String { "/pods/\(id)/confirm-attendance" }

            // Chat
            static func podMessages(_ id: String) -> String { "/pods/\(id)/messages" }
            static func podVotes(_ id: String) -> String { "/pods/\(id)/votes" }
            static func podVoteRespond(_ podId: String, _ voteId: String) -> String {
                "/pods/\(podId)/votes/\(voteId)/respond"
            }
        }
    }

    // ============================================================
    // MARK: - Keychain Keys
    // ============================================================
    enum Keychain {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
    }

    // ============================================================
    // MARK: - Validation
    // ============================================================
    enum Validation {
        static let verificationCodeLength = 6
        static let minInterests = 3
        static let maxInterests = 10
    }
}
