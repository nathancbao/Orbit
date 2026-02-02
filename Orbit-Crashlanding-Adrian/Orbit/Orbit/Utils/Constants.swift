//
//  Constants.swift
//  Orbit
//
//  APP CONSTANTS
//  Centralized location for all app configuration values.
//

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
            // Auth endpoints
            static let sendCode = "/auth/send-code"
            static let verifyCode = "/auth/verify-code"
            static let refreshToken = "/auth/refresh"
            static let logout = "/auth/logout"

            // User/Profile endpoints
            static let me = "/users/me"
            static let uploadPhoto = "/users/me/photo"
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
    // MARK: - Validation Rules
    // ============================================================
    enum Validation {
        // Auth - .edu email required
        static let verificationCodeLength = 6

        // Profile - Basic Info
        static let minAge = 18
        static let maxAge = 100
        static let minBioLength = 0
        static let maxBioLength = 500

        // Profile - Interests
        static let minInterests = 3
        static let maxInterests = 10

        // Profile - Photos
        static let maxPhotos = 6
    }
}
