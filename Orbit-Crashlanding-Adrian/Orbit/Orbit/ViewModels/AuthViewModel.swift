//
//  AuthViewModel.swift
//  Orbit
//
//  Manages authentication state and logic.
//  Uses .edu email verification.
//

import Foundation
import Combine

enum AuthState {
    case emailEntry
    case verification
    case authenticated
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var verificationCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var authState: AuthState = .emailEntry
    @Published var isNewUser: Bool = false
    @Published var userId: Int?

    // Validate .edu email
    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("@") && trimmed.hasSuffix(".edu")
    }

    // Validate 6-digit code
    var isCodeValid: Bool {
        let digits = verificationCode.filter { $0.isNumber }
        return digits.count == Constants.Validation.verificationCodeLength
    }

    // Send verification code to email
    func sendVerificationCode() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid .edu email"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let _ = try await AuthService.shared.sendVerificationCode(email: email.lowercased().trimmingCharacters(in: .whitespaces))
            authState = .verification
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Verify the code
    func verifyCode() async {
        guard isCodeValid else {
            errorMessage = "Please enter a valid 6-digit code"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.verifyCode(
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                code: verificationCode
            )
            isNewUser = response.isNewUser
            userId = response.userId
            authState = .authenticated
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Reset to email entry
    func resetToEmailEntry() {
        authState = .emailEntry
        verificationCode = ""
        errorMessage = nil
    }

    // Check if already logged in
    func checkExistingAuth() -> Bool {
        return AuthService.shared.isLoggedIn()
    }
}
