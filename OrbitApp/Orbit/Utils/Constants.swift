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
            static let myPods = "/users/me/pods"
            static let myRsvps = "/users/me/rsvps"
            static let uploadPhoto = "/users/me/photo"
            static let uploadGalleryPhoto = "/users/me/gallery"
            static func deleteGalleryPhoto(_ index: Int) -> String { "/users/me/gallery/\(index)" }

            // Missions (fixed-date events)
            static let missions = "/missions"
            static let suggestedMissions = "/missions/suggested"
            static func mission(_ id: String) -> String { "/missions/\(id)" }
            static func joinMission(_ id: String) -> String { "/missions/\(id)/join" }
            static func leaveMission(_ id: String) -> String { "/missions/\(id)/leave" }
            static func skipMission(_ id: String) -> String { "/missions/\(id)/skip" }

            // Pods
            static func pod(_ id: String) -> String { "/pods/\(id)" }
            static func podKick(_ id: String) -> String { "/pods/\(id)/kick" }
            static func podConfirm(_ id: String) -> String { "/pods/\(id)/confirm-attendance" }
            static func podRename(_ id: String) -> String { "/pods/\(id)/name" }
            static func podLeave(_ id: String) -> String { "/pods/\(id)/leave" }

            // Signals (spontaneous activity requests)
            static let signals = "/signals"
            static let discoverSignals = "/signals/discover"
            static func signal(_ id: String) -> String { "/signals/\(id)" }
            static func rsvpSignal(_ id: String) -> String { "/signals/\(id)/rsvp" }

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
        static let maxBioLength = 250
        static let maxGalleryPhotos = 6
        static let maxLinks = 3
    }
}
