// AuthModels.swift
// Data models for authentication system.
// Handles user accounts, verification states, and sessions.

import Foundation

// MARK: - AuthenticationState
// Represents the current state of a user in the authentication flow.
enum AuthenticationState: String, Codable {
    case unauthenticated        // User has not started auth
    case emailEntered           // Email submitted, awaiting verification
    case verificationSent       // Verification code sent to email
    case verified               // Email verified successfully
    case authenticated          // Fully logged in
}

// MARK: - AuthError
// Errors that can occur during authentication.
enum AuthError: Error, Equatable {
    case invalidEmail
    case emptyEmail
    case verificationCodeExpired
    case invalidVerificationCode
    case userNotFound
    case userAlreadyExists
    case accountNotVerified
    case invalidPassword
    case passwordTooShort
    case networkError(String)

    var localizedDescription: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emptyEmail:
            return "Email cannot be empty."
        case .verificationCodeExpired:
            return "Verification code has expired. Please request a new one."
        case .invalidVerificationCode:
            return "Invalid verification code. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .userAlreadyExists:
            return "An account with this email already exists."
        case .accountNotVerified:
            return "Please verify your email before logging in."
        case .invalidPassword:
            return "Incorrect password. Please try again."
        case .passwordTooShort:
            return "Password must be at least 8 characters."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - VerificationCode
// Represents a time-limited verification code sent to user's email.
struct VerificationCode: Codable {
    let code: String
    let email: String
    let createdAt: Date
    let expiresAt: Date

    // Default expiration: 10 minutes
    static let defaultExpirationMinutes: Int = 10

    init(email: String, code: String? = nil, expirationMinutes: Int = defaultExpirationMinutes) {
        self.email = email.lowercased()
        self.code = code ?? VerificationCode.generateCode()
        self.createdAt = Date()
        self.expiresAt = Calendar.current.date(byAdding: .minute, value: expirationMinutes, to: self.createdAt) ?? self.createdAt
    }

    // Generate a random 6-digit code
    static func generateCode() -> String {
        let code = Int.random(in: 100000...999999)
        return String(code)
    }

    // Check if code is still valid
    var isValid: Bool {
        return Date() < expiresAt
    }

    // Check if entered code matches
    func matches(_ enteredCode: String) -> Bool {
        return code == enteredCode && isValid
    }
}

// MARK: - UserAccount
// Represents a user account in the system.
struct UserAccount: Identifiable, Hashable, Codable {
    let id: UUID
    let email: String
    var passwordHash: String        // In production, use proper hashing (bcrypt, etc.)
    var isEmailVerified: Bool
    var createdAt: Date
    var lastLoginAt: Date?

    // Associated student profile (linked after onboarding)
    var studentID: UUID?

    init(email: String, passwordHash: String = "") {
        self.id = UUID()
        self.email = email.lowercased()
        self.passwordHash = passwordHash
        self.isEmailVerified = false
        self.createdAt = Date()
        self.lastLoginAt = nil
        self.studentID = nil
    }

    // Hashable conformance
    static func == (lhs: UserAccount, rhs: UserAccount) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - AuthSession
// Represents an active authentication session.
// Codable for Keychain persistence.
struct AuthSession: Identifiable, Codable {
    let id: UUID
    let userID: UUID
    let email: String
    let createdAt: Date
    let expiresAt: Date

    // Default session duration: 7 days
    static let defaultExpirationDays: Int = 7

    init(userID: UUID, email: String, expirationDays: Int = defaultExpirationDays) {
        self.id = UUID()
        self.userID = userID
        self.email = email
        self.createdAt = Date()
        self.expiresAt = Calendar.current.date(byAdding: .day, value: expirationDays, to: self.createdAt) ?? self.createdAt
    }

    var isValid: Bool {
        return Date() < expiresAt
    }
}

// MARK: - Email Validation
extension String {
    /// Validates email format using a simple regex pattern.
    /// Returns true if the string looks like a valid email address.
    var isValidEmail: Bool {
        // Basic email regex pattern
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: self)
    }
}
