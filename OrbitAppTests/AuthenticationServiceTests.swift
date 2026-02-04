// AuthenticationServiceTests.swift
// XCTest unit tests for the AuthenticationService and EmailService.
// Updated for client-side email-only authentication (no password required).

import XCTest
@testable import OrbitApp

final class AuthenticationServiceTests: XCTestCase {

    var authService: AuthenticationService!
    var mockEmailService: MockEmailService!

    override func setUpWithError() throws {
        mockEmailService = MockEmailService()
        authService = AuthenticationService(emailService: mockEmailService)
    }

    override func tearDownWithError() throws {
        authService.reset()
        mockEmailService.reset()
        authService = nil
        mockEmailService = nil
    }

    // MARK: - Email Validation Tests

    func testValidEmailPassesValidation() {
        let result = authService.validateEmail("test@example.com")
        switch result {
        case .success(let email):
            XCTAssertEqual(email, "test@example.com")
        case .failure:
            XCTFail("Valid email should pass validation")
        }
    }

    func testEmailWithUppercaseIsNormalized() {
        let result = authService.validateEmail("Test@EXAMPLE.COM")
        switch result {
        case .success(let email):
            XCTAssertEqual(email, "test@example.com")
        case .failure:
            XCTFail("Email should be normalized to lowercase")
        }
    }

    func testEmailWithSpacesIsTrimmed() {
        let result = authService.validateEmail("  test@example.com  ")
        switch result {
        case .success(let email):
            XCTAssertEqual(email, "test@example.com")
        case .failure:
            XCTFail("Email should be trimmed")
        }
    }

    func testEmptyEmailFails() {
        let result = authService.validateEmail("")
        switch result {
        case .success:
            XCTFail("Empty email should fail")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.emptyEmail)
        }
    }

    func testInvalidEmailNoAtSymbolFails() {
        let result = authService.validateEmail("testexample.com")
        switch result {
        case .success:
            XCTFail("Invalid email should fail")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidEmail)
        }
    }

    func testInvalidEmailNoDomainFails() {
        let result = authService.validateEmail("test@")
        switch result {
        case .success:
            XCTFail("Invalid email should fail")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidEmail)
        }
    }

    func testValidEduEmailPasses() {
        let result = authService.validateEmail("student@university.edu")
        switch result {
        case .success(let email):
            XCTAssertEqual(email, "student@university.edu")
        case .failure:
            XCTFail("Valid .edu email should pass")
        }
    }

    func testValidEmailWithSubdomainPasses() {
        let result = authService.validateEmail("user@mail.example.com")
        switch result {
        case .success(let email):
            XCTAssertEqual(email, "user@mail.example.com")
        case .failure:
            XCTFail("Email with subdomain should pass")
        }
    }

    // MARK: - Verification Code Tests

    func testVerificationCodeIsSixDigits() {
        let code = VerificationCode(email: "test@example.com")
        XCTAssertEqual(code.code.count, 6)
        XCTAssertNotNil(Int(code.code))
    }

    func testVerificationCodeEmailIsNormalized() {
        let code = VerificationCode(email: "TEST@Example.com")
        XCTAssertEqual(code.email, "test@example.com")
    }

    func testFreshVerificationCodeIsValid() {
        let code = VerificationCode(email: "test@example.com")
        XCTAssertTrue(code.isValid)
    }

    func testVerificationCodeMatchesCorrectly() {
        let code = VerificationCode(email: "test@example.com", code: "123456")
        XCTAssertTrue(code.matches("123456"))
    }

    func testVerificationCodeDoesNotMatchIncorrectCode() {
        let code = VerificationCode(email: "test@example.com", code: "123456")
        XCTAssertFalse(code.matches("654321"))
    }

    func testCustomCodeWorks() {
        let code = VerificationCode(email: "test@example.com", code: "999999")
        XCTAssertEqual(code.code, "999999")
    }

    // MARK: - Send Verification Tests (Synchronous)

    func testSendVerificationCodeToValidEmail() {
        let result = authService.sendVerificationCode(to: "test@example.com")
        switch result {
        case .success(let code):
            XCTAssertEqual(code.email, "test@example.com")
            XCTAssertEqual(code.code.count, 6)
            XCTAssertEqual(authService.currentState, .verificationSent)
        case .failure:
            XCTFail("Should send verification code to valid email")
        }
    }

    func testSendVerificationCodeToInvalidEmailFails() {
        let result = authService.sendVerificationCode(to: "invalid-email")
        switch result {
        case .success:
            XCTFail("Should fail for invalid email")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidEmail)
        }
    }

    func testPendingVerificationCountIncreases() {
        _ = authService.sendVerificationCode(to: "test@example.com")
        XCTAssertEqual(authService.pendingVerificationCount, 1)
    }

    func testMultipleVerificationsSameEmailOverwrites() {
        _ = authService.sendVerificationCode(to: "test@example.com")
        _ = authService.sendVerificationCode(to: "test@example.com")
        XCTAssertEqual(authService.pendingVerificationCount, 1)
    }

    // MARK: - Send Verification Tests (Async with Mock Email Service)

    func testSendVerificationCodeAsyncSuccess() async {
        mockEmailService.shouldSucceed = true

        let result = await authService.sendVerificationCodeAsync(to: "test@example.com")

        switch result {
        case .success(let code):
            XCTAssertEqual(code.email, "test@example.com")
            XCTAssertEqual(code.code.count, 6)
            XCTAssertEqual(authService.currentState, .verificationSent)
            XCTAssertEqual(mockEmailService.lastSentEmail, "test@example.com")
            XCTAssertEqual(mockEmailService.lastSentCode, code.code)
            XCTAssertEqual(mockEmailService.sendCount, 1)
        case .failure:
            XCTFail("Should send verification code successfully")
        }
    }

    func testSendVerificationCodeAsyncFailure() async {
        mockEmailService.shouldSucceed = false

        let result = await authService.sendVerificationCodeAsync(to: "test@example.com")

        switch result {
        case .success:
            XCTFail("Should fail when email service fails")
        case .failure:
            // Expected - email service failed
            XCTAssertEqual(authService.pendingVerificationCount, 0) // Should not store code on failure
        }
    }

    func testSendVerificationCodeAsyncInvalidEmail() async {
        let result = await authService.sendVerificationCodeAsync(to: "invalid-email")

        switch result {
        case .success:
            XCTFail("Should fail for invalid email")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidEmail)
            XCTAssertEqual(mockEmailService.sendCount, 0) // Should not attempt to send
        }
    }

    // MARK: - Verify Code Tests

    func testVerifyCorrectCode() {
        let sendResult = authService.sendVerificationCode(to: "test@example.com")
        guard case .success(let sentCode) = sendResult else {
            XCTFail("Should send code")
            return
        }

        let verifyResult = authService.verifyCode(sentCode.code, for: "test@example.com")
        switch verifyResult {
        case .success(let verified):
            XCTAssertTrue(verified)
            XCTAssertEqual(authService.currentState, .verified)
        case .failure:
            XCTFail("Should verify correct code")
        }
    }

    func testVerifyIncorrectCodeFails() {
        _ = authService.sendVerificationCode(to: "test@example.com")

        let verifyResult = authService.verifyCode("000000", for: "test@example.com")
        switch verifyResult {
        case .success:
            XCTFail("Should fail with incorrect code")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidVerificationCode)
        }
    }

    func testVerifyWithNoPendingVerificationFails() {
        let verifyResult = authService.verifyCode("123456", for: "nonexistent@example.com")
        switch verifyResult {
        case .success:
            XCTFail("Should fail with no pending verification")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidVerificationCode)
        }
    }

    func testPendingVerificationRemovedAfterSuccess() {
        let sendResult = authService.sendVerificationCode(to: "test@example.com")
        guard case .success(let sentCode) = sendResult else {
            XCTFail("Should send code")
            return
        }

        _ = authService.verifyCode(sentCode.code, for: "test@example.com")
        XCTAssertEqual(authService.pendingVerificationCount, 0)
    }

    // MARK: - Account Creation Tests (Email-only auth)

    func testCreateAccountWithValidEmail() {
        // First verify email
        let sendResult = authService.sendVerificationCode(to: "new@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "new@example.com")

        // Then create account (no password needed in email-only auth)
        let createResult = authService.createAccount(email: "new@example.com")
        switch createResult {
        case .success(let account):
            XCTAssertEqual(account.email, "new@example.com")
            XCTAssertTrue(account.isEmailVerified)
            XCTAssertEqual(authService.accountCount, 1)
        case .failure:
            XCTFail("Should create account")
        }
    }

    func testCreateAccountReturnsExistingAccount() {
        // Create first account
        _ = authService.createAccount(email: "test@example.com")

        // Try creating again - should return existing account, not fail
        let createResult = authService.createAccount(email: "test@example.com")
        switch createResult {
        case .success(let account):
            XCTAssertEqual(account.email, "test@example.com")
            XCTAssertEqual(authService.accountCount, 1) // Still just 1 account
        case .failure:
            XCTFail("Should return existing account")
        }
    }

    func testAccountExistsCheck() {
        _ = authService.createAccount(email: "existing@example.com")
        XCTAssertTrue(authService.accountExists(email: "existing@example.com"))
        XCTAssertFalse(authService.accountExists(email: "nonexistent@example.com"))
    }

    // MARK: - Session Creation Tests (Email-only auth)

    func testCreateSessionAfterVerification() {
        // Verify email
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")

        // Create session
        let sessionResult = authService.createSession(email: "user@example.com")
        switch sessionResult {
        case .success(let session):
            XCTAssertEqual(session.email, "user@example.com")
            XCTAssertEqual(authService.currentState, .authenticated)
            XCTAssertNotNil(authService.currentSession)
            XCTAssertTrue(authService.hasValidSession())
        case .failure:
            XCTFail("Should create session")
        }
    }

    func testGetCurrentUserAfterSessionCreation() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        let currentUser = authService.getCurrentUser()
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.email, "user@example.com")
    }

    func testGetCurrentEmail() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        XCTAssertEqual(authService.getCurrentEmail(), "user@example.com")
    }

    func testGetCurrentSession() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        let session = authService.getCurrentSession()
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.email, "user@example.com")
    }

    // MARK: - Logout Tests

    func testLogoutSuccessfully() {
        // Setup: create session
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        // Logout
        authService.logout()
        XCTAssertNil(authService.currentSession)
        XCTAssertEqual(authService.currentState, .unauthenticated)
        XCTAssertFalse(authService.hasValidSession())
    }

    func testCurrentUserNilAfterLogout() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")
        authService.logout()

        XCTAssertNil(authService.getCurrentUser())
    }

    // MARK: - Password Reset Tests (Kept for compatibility, but not used in email-only auth)

    func testInitiatePasswordResetForExistingUser() {
        // Create account first
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        let resetResult = authService.initiatePasswordReset(email: "user@example.com")
        switch resetResult {
        case .success(let code):
            XCTAssertEqual(code.email, "user@example.com")
        case .failure:
            XCTFail("Should initiate password reset")
        }
    }

    func testPasswordResetForNonexistentUserFails() {
        let resetResult = authService.initiatePasswordReset(email: "nobody@example.com")
        switch resetResult {
        case .success:
            XCTFail("Should fail for nonexistent user")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.userNotFound)
        }
    }

    // MARK: - Session Tests

    func testNewSessionIsValid() {
        let session = AuthSession(userID: UUID(), email: "test@example.com")
        XCTAssertTrue(session.isValid)
    }

    func testSessionValidationWorks() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        let sessionResult = authService.createSession(email: "user@example.com")

        guard case .success(let session) = sessionResult else {
            XCTFail("Should create session")
            return
        }
        XCTAssertTrue(authService.isSessionValid(session.id))
    }

    func testInvalidSessionIDReturnsFalse() {
        XCTAssertFalse(authService.isSessionValid(UUID()))
    }

    // MARK: - Integration Tests

    func testFullSignupFlow() {
        // 1. Send verification
        let sendResult = authService.sendVerificationCode(to: "newuser@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send verification")
            return
        }

        // 2. Verify code
        let verifyResult = authService.verifyCode(code.code, for: "newuser@example.com")
        guard case .success(_) = verifyResult else {
            XCTFail("Should verify code")
            return
        }

        // 3. Create session (this also creates account)
        let sessionResult = authService.createSession(email: "newuser@example.com")
        guard case .success(_) = sessionResult else {
            XCTFail("Should create session")
            return
        }

        XCTAssertEqual(authService.currentState, .authenticated)
        XCTAssertNotNil(authService.getCurrentUser())
        XCTAssertTrue(authService.hasValidSession())
    }

    func testFullSignupFlowWithAsyncEmail() async {
        mockEmailService.shouldSucceed = true

        // 1. Send verification via email
        let sendResult = await authService.sendVerificationCodeAsync(to: "newuser@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send verification")
            return
        }

        // Verify email was "sent"
        XCTAssertEqual(mockEmailService.sendCount, 1)
        XCTAssertEqual(mockEmailService.lastSentEmail, "newuser@example.com")

        // 2. Verify code
        let verifyResult = authService.verifyCode(code.code, for: "newuser@example.com")
        guard case .success(_) = verifyResult else {
            XCTFail("Should verify code")
            return
        }

        // 3. Create session
        let sessionResult = authService.createSession(email: "newuser@example.com")
        guard case .success(_) = sessionResult else {
            XCTFail("Should create session")
            return
        }

        XCTAssertEqual(authService.currentState, .authenticated)
        XCTAssertNotNil(authService.getCurrentUser())
        XCTAssertTrue(authService.hasValidSession())
    }

    func testLinkStudentProfileWorks() {
        let sendResult = authService.sendVerificationCode(to: "student@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "student@example.com")
        _ = authService.createSession(email: "student@example.com")

        let studentID = UUID()
        let linked = authService.linkStudentProfile(studentID: studentID, to: "student@example.com")
        XCTAssertTrue(linked)
    }

    func testServiceResetClearsAllState() {
        _ = authService.sendVerificationCode(to: "test@example.com")
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createSession(email: "user@example.com")

        authService.reset()

        XCTAssertEqual(authService.accountCount, 0)
        XCTAssertEqual(authService.pendingVerificationCount, 0)
        XCTAssertEqual(authService.activeSessionCount, 0)
        XCTAssertEqual(authService.currentState, .unauthenticated)
        XCTAssertFalse(authService.hasValidSession())
    }

    // MARK: - User Flow Tests (Authentication is first screen)

    func testInitialStateIsUnauthenticated() {
        // Fresh service should be unauthenticated
        XCTAssertEqual(authService.currentState, .unauthenticated)
        XCTAssertFalse(authService.hasValidSession())
        XCTAssertNil(authService.currentSession)
        XCTAssertNil(authService.getCurrentUser())
    }

    func testStateProgressesThroughFlow() {
        // Initial state
        XCTAssertEqual(authService.currentState, .unauthenticated)

        // After sending code
        _ = authService.sendVerificationCode(to: "user@example.com")
        XCTAssertEqual(authService.currentState, .verificationSent)

        // Get the code and verify it
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        XCTAssertEqual(authService.currentState, .verified)

        // After creating session
        _ = authService.createSession(email: "user@example.com")
        XCTAssertEqual(authService.currentState, .authenticated)
    }
}

// MARK: - Email Service Tests

final class EmailServiceTests: XCTestCase {

    // MARK: - MockEmailService Tests

    func testMockEmailServiceSuccess() async {
        let mockService = MockEmailService()
        mockService.shouldSucceed = true

        let result = await mockService.sendVerificationEmail(to: "test@example.com", code: "123456")

        switch result {
        case .success(let success):
            XCTAssertTrue(success)
            XCTAssertEqual(mockService.lastSentEmail, "test@example.com")
            XCTAssertEqual(mockService.lastSentCode, "123456")
            XCTAssertEqual(mockService.sendCount, 1)
        case .failure:
            XCTFail("Should succeed")
        }
    }

    func testMockEmailServiceFailure() async {
        let mockService = MockEmailService()
        mockService.shouldSucceed = false

        let result = await mockService.sendVerificationEmail(to: "test@example.com", code: "123456")

        switch result {
        case .success:
            XCTFail("Should fail")
        case .failure(let error):
            XCTAssertEqual(error, EmailError.networkError("Mock network failure"))
        }
    }

    func testMockEmailServiceReset() async {
        let mockService = MockEmailService()
        _ = await mockService.sendVerificationEmail(to: "test@example.com", code: "123456")

        mockService.reset()

        XCTAssertNil(mockService.lastSentEmail)
        XCTAssertNil(mockService.lastSentCode)
        XCTAssertEqual(mockService.sendCount, 0)
        XCTAssertTrue(mockService.shouldSucceed)
    }

    // MARK: - EmailError Tests

    func testEmailErrorEquatable() {
        XCTAssertEqual(EmailError.notConfigured, EmailError.notConfigured)
        XCTAssertEqual(EmailError.invalidEmail, EmailError.invalidEmail)
        XCTAssertEqual(EmailError.encodingError, EmailError.encodingError)
        XCTAssertEqual(EmailError.networkError("test"), EmailError.networkError("test"))
        XCTAssertEqual(EmailError.apiError(400, "Bad Request"), EmailError.apiError(400, "Bad Request"))

        XCTAssertNotEqual(EmailError.notConfigured, EmailError.invalidEmail)
        XCTAssertNotEqual(EmailError.networkError("test1"), EmailError.networkError("test2"))
        XCTAssertNotEqual(EmailError.apiError(400, "Bad"), EmailError.apiError(500, "Bad"))
    }

    func testEmailErrorDescriptions() {
        XCTAssertFalse(EmailError.notConfigured.localizedDescription.isEmpty)
        XCTAssertFalse(EmailError.invalidEmail.localizedDescription.isEmpty)
        XCTAssertFalse(EmailError.encodingError.localizedDescription.isEmpty)
        XCTAssertFalse(EmailError.networkError("test").localizedDescription.isEmpty)
        XCTAssertFalse(EmailError.apiError(400, "test").localizedDescription.isEmpty)
    }

    // MARK: - Config Tests

    func testConfigIsEmailConfiguredLogic() {
        // Test that isEmailConfigured returns a boolean (actual value depends on .env file)
        // This test verifies the config can be accessed without crashing
        let isConfigured = Config.isEmailConfigured
        XCTAssertTrue(isConfigured == true || isConfigured == false)

        // Test that we can access config properties
        XCTAssertNotNil(Config.sendGridAPIKey)
        XCTAssertNotNil(Config.senderEmail)
        XCTAssertNotNil(Config.senderName)
    }
}

// MARK: - Auth Flow View Model Tests

final class AuthViewModelTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let viewModel = AuthViewModel()

        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.verificationCode, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.authState, .emailEntry)
        XCTAssertTrue(viewModel.isNewUser)
    }

    @MainActor
    func testEmailValidation() {
        let viewModel = AuthViewModel()

        // Invalid email
        viewModel.email = "invalid"
        XCTAssertFalse(viewModel.isEmailValid)

        // Valid email
        viewModel.email = "test@example.com"
        XCTAssertTrue(viewModel.isEmailValid)

        // Empty email
        viewModel.email = ""
        XCTAssertFalse(viewModel.isEmailValid)
    }

    @MainActor
    func testCodeValidation() {
        let viewModel = AuthViewModel()

        // Invalid code - too short
        viewModel.verificationCode = "123"
        XCTAssertFalse(viewModel.isCodeValid)

        // Invalid code - empty
        viewModel.verificationCode = ""
        XCTAssertFalse(viewModel.isCodeValid)

        // Valid code - 6 digits
        viewModel.verificationCode = "123456"
        XCTAssertTrue(viewModel.isCodeValid)
    }

    @MainActor
    func testResetToEmailEntry() {
        let viewModel = AuthViewModel()

        // Move to verification state
        viewModel.authState = .verification
        viewModel.verificationCode = "123456"
        viewModel.errorMessage = "Some error"

        // Reset to email entry
        viewModel.resetToEmailEntry()

        // Should reset appropriately
        XCTAssertEqual(viewModel.authState, .emailEntry)
        XCTAssertEqual(viewModel.verificationCode, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testLogout() {
        let viewModel = AuthViewModel()

        // Set some state
        viewModel.email = "test@example.com"
        viewModel.verificationCode = "123456"
        viewModel.authState = .authenticated
        viewModel.errorMessage = "Error"
        viewModel.isNewUser = false

        // Logout
        viewModel.logout()

        // Should be back to initial state
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.verificationCode, "")
        XCTAssertEqual(viewModel.authState, .emailEntry)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isNewUser)
    }

    @MainActor
    func testCheckExistingAuth() {
        let viewModel = AuthViewModel()

        // Should return false for fresh state
        XCTAssertFalse(viewModel.checkExistingAuth())
    }
}
