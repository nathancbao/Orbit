//
//  AuthService.swift
//  Orbit
//
//  Handles all authentication-related API calls.
//  Uses .edu email verification.
//

import Foundation

class AuthService {
    static let shared = AuthService()
    private init() {}

    // Send verification code to .edu email
    func sendVerificationCode(email: String) async throws -> String {
        let body: [String: Any] = ["email": email]
        let response: MessageData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.sendCode,
            method: "POST",
            body: body
        )
        return response.message
    }

    // Verify code and get auth tokens
    func verifyCode(email: String, code: String) async throws -> AuthResponseData {
        let body: [String: Any] = [
            "email": email,
            "code": code
        ]
        let response: AuthResponseData = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.verifyCode,
            method: "POST",
            body: body
        )

        // Save tokens to Keychain
        KeychainHelper.shared.save(response.accessToken, forKey: Constants.Keychain.accessToken)
        KeychainHelper.shared.save(response.refreshToken, forKey: Constants.Keychain.refreshToken)

        return response
    }

    // Refresh the access token
    func refreshToken() async throws -> String {
        guard let refreshToken = KeychainHelper.shared.readString(forKey: Constants.Keychain.refreshToken) else {
            throw NetworkError.unauthorized
        }

        let body: [String: Any] = ["refresh_token": refreshToken]
        let response: [String: String] = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.refreshToken,
            method: "POST",
            body: body
        )

        if let newAccessToken = response["access_token"] {
            KeychainHelper.shared.save(newAccessToken, forKey: Constants.Keychain.accessToken)
            return newAccessToken
        }
        throw NetworkError.noData
    }

    // Logout and clear tokens
    func logout() async throws {
        if let refreshToken = KeychainHelper.shared.readString(forKey: Constants.Keychain.refreshToken) {
            let body: [String: Any] = ["refresh_token": refreshToken]
            let _: MessageData = try await APIService.shared.request(
                endpoint: Constants.API.Endpoints.logout,
                method: "POST",
                body: body
            )
        }

        // Clear tokens from Keychain
        KeychainHelper.shared.delete(forKey: Constants.Keychain.accessToken)
        KeychainHelper.shared.delete(forKey: Constants.Keychain.refreshToken)
    }

    // Check if user is logged in
    func isLoggedIn() -> Bool {
        return KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken) != nil
    }
}
