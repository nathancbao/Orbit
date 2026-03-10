import Foundation

// MARK: - App Notifications

extension Notification.Name {
    static let missionsNeedRefresh = Notification.Name("missionsNeedRefresh")
}

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
            static func userProfile(_ id: Int) -> String { "/users/\(id)" }
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
            static func podScheduleAvailability(_ id: String) -> String { "/pods/\(id)/schedule/availability" }
            static func podScheduleConfirm(_ id: String) -> String { "/pods/\(id)/schedule/confirm" }

            // Signals (spontaneous activity requests)
            static let signals = "/signals"
            static let discoverSignals = "/signals/discover"
            static func signal(_ id: String) -> String { "/signals/\(id)" }
            static func rsvpSignal(_ id: String) -> String { "/signals/\(id)/rsvp" }

            // Friends
            static let friends = "/friends"
            static let friendRequests = "/friends/requests"
            static let friendRequestsIncoming = "/friends/requests/incoming"
            static let friendRequestsOutgoing = "/friends/requests/outgoing"
            static func friendRequestAccept(_ id: Int) -> String { "/friends/requests/\(id)/accept" }
            static func friendRequestDecline(_ id: Int) -> String { "/friends/requests/\(id)/decline" }
            static func friendRemove(_ id: Int) -> String { "/friends/\(id)" }
            static func friendStatus(_ userId: Int) -> String { "/friends/status/\(userId)" }
            static let friendSearch = "/friends/search"

            // Chat
            static func podMessages(_ id: String) -> String { "/pods/\(id)/messages" }
            static func podVotes(_ id: String) -> String { "/pods/\(id)/votes" }
            static func podVoteRespond(_ podId: String, _ voteId: String) -> String {
                "/pods/\(podId)/votes/\(voteId)/respond"
            }

            // DMs
            static let dmConversations = "/dm/conversations"
            static func dmMessages(_ friendId: Int) -> String { "/dm/\(friendId)/messages" }

            // Pod Invites
            static func podInvite(_ podId: String) -> String { "/pods/\(podId)/invite" }
            static let podInvitesIncoming = "/pods/invites/incoming"
            static func podInviteAccept(_ id: Int) -> String { "/pods/invites/\(id)/accept" }
            static func podInviteDecline(_ id: Int) -> String { "/pods/invites/\(id)/decline" }
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
