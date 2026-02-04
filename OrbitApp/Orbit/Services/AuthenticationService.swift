// AuthenticationService.swift
// Handles all authentication logic: signup, login, email verification.
// This is the main service that coordinates the auth flow.
// Modified to include Keychain persistence for sessions.

import Foundation

// MARK: - AuthenticationService
/// Main service for handling user authentication.
/// Manages user accounts, verification codes, and sessions.
/// Sessions are persisted to Keychain for persistence across app restarts.
class AuthenticationService {

    // MARK: - Singleton

    static let shared = AuthenticationService()

    // MARK: - Keychain Keys

    private let sessionKey = "auth_session"
    private let accountKey = "auth_account"

    // MARK: - Properties

    /// Storage for user accounts (email -> account)
    /// Note: In production, this should be persisted to Keychain or server
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
        loadSessionFromKeychain()
        loadAccountFromKeychain()
    }

    // MARK: - Keychain Persistence

    /// Saves the current session to Keychain for persistence across app restarts.
    private func saveSessionToKeychain(_ session: AuthSession) {
        if let data = try? JSONEncoder().encode(session) {
            _ = KeychainHelper.shared.save(data, forKey: sessionKey)
        }
    }

    /// Loads session from Keychain on app launch.
    private func loadSessionFromKeychain() {
        if let data = KeychainHelper.shared.read(forKey: sessionKey),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            if session.isValid {
                self.currentSession = session
                self.activeSessions[session.id] = session
                self.currentState = .authenticated
            } else {
                // Session expired, clear it
                clearSessionFromKeychain()
            }
        }
    }

    /// Clears session from Keychain.
    private func clearSessionFromKeychain() {
        _ = KeychainHelper.shared.delete(forKey: sessionKey)
    }

    /// Saves account to Keychain for persistence.
    private func saveAccountToKeychain(_ account: UserAccount) {
        if let data = try? JSONEncoder().encode(account) {
            _ = KeychainHelper.shared.save(data, forKey: accountKey)
        }
    }

    /// Loads account from Keychain.
    private func loadAccountFromKeychain() {
        if let data = KeychainHelper.shared.read(forKey: accountKey),
           let account = try? JSONDecoder().decode(UserAccount.self, from: data) {
            self.accounts[account.email] = account
        }
    }

    /// Clears account from Keychain.
    private func clearAccountFromKeychain() {
        _ = KeychainHelper.shared.delete(forKey: accountKey)
    }

    // MARK: - Session Validation

    /// Checks if user has a valid session (for auto-login).
    func hasValidSession() -> Bool {
        return currentSession?.isValid ?? false
    }

    /// Gets the current user's email if logged in.
    func getCurrentEmail() -> String? {
        return currentSession?.email
    }

    /// Gets the current session (for API token handling).
    func getCurrentSession() -> AuthSession? {
        return currentSession
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
            saveAccountToKeychain(account)
        }

        return .success(true)
    }

    // MARK: - Create Account (Simplified for email-only auth)

    /// Creates a new user account after email verification.
    /// Simplified version without password for email-only auth.
    /// - Parameter email: Verified email address
    /// - Returns: Result with the new UserAccount or AuthError
    func createAccount(email: String) -> Result<UserAccount, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if email is valid
        switch validateEmail(normalizedEmail) {
        case .failure(let error):
            return .failure(error)
        case .success(_):
            break
        }

        // Check if account already exists
        if let existingAccount = accounts[normalizedEmail] {
            // Account exists, just return it (user is logging in again)
            return .success(existingAccount)
        }

        // Create account
        var newAccount = UserAccount(email: normalizedEmail)
        newAccount.isEmailVerified = true  // Since we verified the email first

        // Store account
        accounts[normalizedEmail] = newAccount
        saveAccountToKeychain(newAccount)

        return .success(newAccount)
    }

    // MARK: - Login (Create Session)

    /// Creates a session for the user after successful verification.
    /// - Parameter email: User's verified email
    /// - Returns: Result with AuthSession or AuthError
    func createSession(email: String) -> Result<AuthSession, AuthError> {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Create or get account
        let accountResult = createAccount(email: normalizedEmail)

        switch accountResult {
        case .failure(let error):
            return .failure(error)
        case .success(let account):
            // Update last login
            var updatedAccount = account
            updatedAccount.lastLoginAt = Date()
            accounts[normalizedEmail] = updatedAccount
            saveAccountToKeychain(updatedAccount)

            // Create session
            let session = AuthSession(userID: account.id, email: normalizedEmail)
            activeSessions[session.id] = session
            currentSession = session
            currentState = .authenticated

            // Persist session to Keychain
            saveSessionToKeychain(session)

            return .success(session)
        }
    }

    // MARK: - Logout

    /// Logs out the current user and clears persisted session.
    func logout() {
        if let session = currentSession {
            activeSessions.removeValue(forKey: session.id)
        }
        currentSession = nil
        currentState = .unauthenticated

        // Clear persisted session
        clearSessionFromKeychain()
    }

    // MARK: - Password Reset (Not used in email-only auth, but kept for compatibility)

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
        saveAccountToKeychain(account)
        return true
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
        clearSessionFromKeychain()
        clearAccountFromKeychain()
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
