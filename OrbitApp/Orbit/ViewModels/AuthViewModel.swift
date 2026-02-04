//
//  AuthViewModel.swift
//  Orbit
//
//  Manages authentication state and logic.
//  Uses client-side email verification via SendGrid.
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
    @Published var isNewUser: Bool = true

    private let authService = AuthenticationService.shared

    // Validate email format
    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isValidEmail
    }

    // Validate 6-digit code
    var isCodeValid: Bool {
        let digits = verificationCode.filter { $0.isNumber }
        return digits.count == 6
    }

    // Send verification code to email via SendGrid
    func sendVerificationCode() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email"
            return
        }

        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let result = await authService.sendVerificationCodeAsync(to: normalizedEmail)

        switch result {
        case .success:
            authState = .verification
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Verify the code entered by user
    func verifyCode() async {
        guard isCodeValid else {
            errorMessage = "Please enter a valid 6-digit code"
            return
        }

        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        // First verify the code
        let verifyResult = authService.verifyCode(verificationCode, for: normalizedEmail)

        switch verifyResult {
        case .success:
            // Check if this is a new user (no existing account)
            isNewUser = !authService.accountExists(email: normalizedEmail)

            // Create session (which also creates account if needed)
            let sessionResult = authService.createSession(email: normalizedEmail)

            switch sessionResult {
            case .success:
                authState = .authenticated
            case .failure(let error):
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Reset to email entry state
    func resetToEmailEntry() {
        authState = .emailEntry
        verificationCode = ""
        errorMessage = nil
    }

    // Check if user has valid session (for auto-login)
    func checkExistingAuth() -> Bool {
        return authService.hasValidSession()
    }

    // Logout the current user
    func logout() {
        authService.logout()
        authState = .emailEntry
        email = ""
        verificationCode = ""
        errorMessage = nil
        isNewUser = true
    }

    // Get current user's email
    func getCurrentEmail() -> String? {
        return authService.getCurrentEmail()
    }
}
