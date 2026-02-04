// AuthenticationService.swift
// Handles all authentication logic: signup, login, email verification.
// This is the main service that coordinates the auth flow.

import Foundation

// MARK: - AuthenticationService
/// Main service for handling user authentication.
/// Manages user accounts, verification codes, and sessions.
class AuthenticationService {

    // MARK: - Properties

    /// Storage for user accounts (email -> account)
    private var accounts: [String: UserAccount] = [:]

    /// Pending verification codes (email -> code)
    private var pendingVerifications: [String: VerificationCode] = [:]

    /// Active sessions (sessionID -> session)
    private var activeSessions: [UUID: AuthSession] = [:]

    /// Current authentication state
    private(set) var currentState: AuthenticationState = .unauthenticated

    /// Currently logged-in session (if any)
    private(set) var currentSession: AuthSession?

    /// Email service for sending verification emails
    private var emailService: EmailServiceProtocol

    /// Flag to track if email was sent (for UI feedback)
    private(set) var lastEmailSendResult: Result<Bool, EmailError>?

    // MARK: - Initialization

    init(emailService: EmailServiceProtocol = EmailService.shared) {
        self.emailService = emailService
    }

    // MARK: - Email Validation

    /// Validates email format.
    /// - Parameter email: The email to validate
    /// - Returns: Result with normalized email or AuthError
    func validateEmail(_ email: String) -> Result<String, AuthError> {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            return .failure(.emptyEmail)
        }

        guard trimmedEmail.isValidEmail else {
            return .failure(.invalidEmail)
        }

        return .success(trimmedEmail.lowercased())
    }

    // MARK: - Check Email Exists

    /// Checks if an account with this email already exists.
    /// - Parameter email: The email to check
    /// - Returns: True if account exists, false otherwise
    func accountExists(email: String) -> Bool {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts[normalizedEmail] != nil
    }

    // MARK: - Send Verification Code

    /// Sends a verification code to the provided email.
    /// Used for both signup (new accounts) and login verification.
    /// - Parameter email: The email to send verification to
    /// - Returns: Result with the VerificationCode or AuthError
    func sendVerificationCode(to email: String) -> Result<VerificationCode, AuthError> {
        // Validate email first
        switch validateEmail(email) {
        case .failure(let error):
            return .failure(error)
        case .success(let validEmail):
            // Generate and store verification code
            let verificationCode = VerificationCode(email: validEmail)
            pendingVerifications[validEmail] = verificationCode

            // Update state
            currentState = .verificationSent

            return .success(verificationCode)
        }
    }

    /// Sends a verification code via email asynchronously.
    /// - Parameter email: The email to send verification to
    /// - Returns: Result with the VerificationCode or AuthError
    func sendVerificationCodeAsync(to email: String) async -> Result<VerificationCode, AuthError> {
        // Validate email first
        switch validateEmail(email) {
        case .failure(let error):
            return .failure(error)
        case .success(let validEmail):
            // Generate verification code
            let verificationCode = VerificationCode(email: validEmail)

            // Send email via EmailService
            let emailResult = await emailService.sendVerificationEmail(to: validEmail, code: verificationCode.code)

            switch emailResult {
            case .success:
                // Store verification code only if email was sent successfully
                pendingVerifications[validEmail] = verificationCode
                currentState = .verificationSent
                lastEmailSendResult = .success(true)
                return .success(verificationCode)

            case .failure(let emailError):
                lastEmailSendResult = .failure(emailError)
                // Convert EmailError to AuthError
                return .failure(.networkError(emailError.localizedDescription))
            }
        }
    }

    // MARK: - Verify Code

    /// Verifies the code entered by the user.
    /// - Parameters:
    ///   - code: The verification code entered
    ///   - email: The email the code was sent to
    /// - Returns: Result indicating success or AuthError
    func verifyCode(_ code: String, for email: String) -> Result<Bool, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard let storedCode = pendingVerifications[normalizedEmail] else {
            return .failure(.invalidVerificationCode)
        }

        guard storedCode.isValid else {
            pendingVerifications.removeValue(forKey: normalizedEmail)
            return .failure(.verificationCodeExpired)
        }

        guard storedCode.matches(code) else {
            return .failure(.invalidVerificationCode)
        }

        // Code is valid - update state
        currentState = .verified
        pendingVerifications.removeValue(forKey: normalizedEmail)

        // If account exists, mark as verified
        if var account = accounts[normalizedEmail] {
            account.isEmailVerified = true
            accounts[normalizedEmail] = account
        }

        return .success(true)
    }

    // MARK: - Create Account (Signup)

    /// Creates a new user account after email verification.
    /// - Parameters:
    ///   - email: Verified email address
    ///   - password: User's chosen password
    /// - Returns: Result with the new UserAccount or AuthError
    func createAccount(email: String, password: String) -> Result<UserAccount, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if email is valid
        switch validateEmail(normalizedEmail) {
        case .failure(let error):
            return .failure(error)
        case .success(_):
            break
        }

        // Check if account already exists
        if accounts[normalizedEmail] != nil {
            return .failure(.userAlreadyExists)
        }

        // Validate password
        guard password.count >= 8 else {
            return .failure(.passwordTooShort)
        }

        // Create account (in production, hash the password properly)
        let passwordHash = hashPassword(password)
        var newAccount = UserAccount(email: normalizedEmail, passwordHash: passwordHash)
        newAccount.isEmailVerified = true  // Since we verified the email first

        // Store account
        accounts[normalizedEmail] = newAccount

        return .success(newAccount)
    }

    // MARK: - Login

    /// Logs in a user with email and password.
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Returns: Result with AuthSession or AuthError
    func login(email: String, password: String) -> Result<AuthSession, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if account exists
        guard var account = accounts[normalizedEmail] else {
            return .failure(.userNotFound)
        }

        // Check if email is verified
        guard account.isEmailVerified else {
            return .failure(.accountNotVerified)
        }

        // Verify password
        let passwordHash = hashPassword(password)
        guard account.passwordHash == passwordHash else {
            return .failure(.invalidPassword)
        }

        // Update last login
        account.lastLoginAt = Date()
        accounts[normalizedEmail] = account

        // Create session
        let session = AuthSession(userID: account.id, email: normalizedEmail)
        activeSessions[session.id] = session
        currentSession = session
        currentState = .authenticated

        return .success(session)
    }

    // MARK: - Logout

    /// Logs out the current user.
    func logout() {
        if let session = currentSession {
            activeSessions.removeValue(forKey: session.id)
        }
        currentSession = nil
        currentState = .unauthenticated
    }

    // MARK: - Password Reset

    /// Initiates password reset by sending verification code.
    /// - Parameter email: Email of the account to reset
    /// - Returns: Result with VerificationCode or AuthError
    func initiatePasswordReset(email: String) -> Result<VerificationCode, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if account exists
        guard accounts[normalizedEmail] != nil else {
            return .failure(.userNotFound)
        }

        // Send verification code
        return sendVerificationCode(to: normalizedEmail)
    }

    /// Initiates password reset asynchronously with email sending.
    /// - Parameter email: Email of the account to reset
    /// - Returns: Result with VerificationCode or AuthError
    func initiatePasswordResetAsync(email: String) async -> Result<VerificationCode, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if account exists
        guard accounts[normalizedEmail] != nil else {
            return .failure(.userNotFound)
        }

        // Send verification code via email
        return await sendVerificationCodeAsync(to: normalizedEmail)
    }

    /// Completes password reset after verification.
    /// - Parameters:
    ///   - email: User's email
    ///   - newPassword: New password to set
    /// - Returns: Result indicating success or AuthError
    func completePasswordReset(email: String, newPassword: String) -> Result<Bool, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard var account = accounts[normalizedEmail] else {
            return .failure(.userNotFound)
        }

        // Validate new password
        guard newPassword.count >= 8 else {
            return .failure(.passwordTooShort)
        }

        // Update password
        account.passwordHash = hashPassword(newPassword)
        accounts[normalizedEmail] = account

        return .success(true)
    }

    // MARK: - Session Management

    /// Validates if a session is still active.
    /// - Parameter sessionID: The session ID to validate
    /// - Returns: True if session is valid and active
    func isSessionValid(_ sessionID: UUID) -> Bool {
        guard let session = activeSessions[sessionID] else {
            return false
        }
        return session.isValid
    }

    /// Gets the current logged-in user account.
    /// - Returns: The current UserAccount if logged in, nil otherwise
    func getCurrentUser() -> UserAccount? {
        guard let session = currentSession,
              isSessionValid(session.id) else {
            return nil
        }
        return accounts[session.email]
    }

    // MARK: - Link Student Profile

    /// Links a Student profile to a UserAccount.
    /// - Parameters:
    ///   - studentID: The Student's UUID
    ///   - userID: The UserAccount's UUID
    /// - Returns: True if successful
    func linkStudentProfile(studentID: UUID, to email: String) -> Bool {
        let normalizedEmail = email.lowercased()
        guard var account = accounts[normalizedEmail] else {
            return false
        }
        account.studentID = studentID
        accounts[normalizedEmail] = account
        return true
    }

    // MARK: - Helper Methods

    /// Simple password hashing (for demo purposes only).
    /// In production, use bcrypt or similar secure hashing.
    private func hashPassword(_ password: String) -> String {
        // This is NOT secure - just for demonstration
        // In production, use proper password hashing
        return String(password.utf8.map { $0 }.reduce(0, { $0 + Int($1) }))
    }

    // MARK: - Testing Helpers

    /// Resets all service state (for testing).
    func reset() {
        accounts.removeAll()
        pendingVerifications.removeAll()
        activeSessions.removeAll()
        currentSession = nil
        currentState = .unauthenticated
        lastEmailSendResult = nil
    }

    /// Sets the email service (for testing with mocks).
    func setEmailService(_ service: EmailServiceProtocol) {
        self.emailService = service
    }

    /// Gets count of registered accounts (for testing).
    var accountCount: Int {
        return accounts.count
    }

    /// Gets count of pending verifications (for testing).
    var pendingVerificationCount: Int {
        return pendingVerifications.count
    }

    /// Gets count of active sessions (for testing).
    var activeSessionCount: Int {
        return activeSessions.count
    }
}
