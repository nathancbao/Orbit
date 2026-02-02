// AuthenticationServiceTests.swift
// XCTest unit tests for the AuthenticationService and EmailService.

import XCTest

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

    // MARK: - Account Creation Tests

    func testCreateAccountWithValidEmailAndPassword() {
        // First verify email
        let sendResult = authService.sendVerificationCode(to: "new@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "new@example.com")

        // Then create account
        let createResult = authService.createAccount(email: "new@example.com", password: "password123")
        switch createResult {
        case .success(let account):
            XCTAssertEqual(account.email, "new@example.com")
            XCTAssertTrue(account.isEmailVerified)
            XCTAssertEqual(authService.accountCount, 1)
        case .failure:
            XCTFail("Should create account")
        }
    }

    func testCreateAccountWithShortPasswordFails() {
        let createResult = authService.createAccount(email: "test@example.com", password: "short")
        switch createResult {
        case .success:
            XCTFail("Should fail with short password")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.passwordTooShort)
        }
    }

    func testCreateAccountWithDuplicateEmailFails() {
        _ = authService.createAccount(email: "test@example.com", password: "password123")
        let createResult = authService.createAccount(email: "test@example.com", password: "password456")
        switch createResult {
        case .success:
            XCTFail("Should fail with duplicate email")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.userAlreadyExists)
        }
    }

    func testAccountExistsCheck() {
        _ = authService.createAccount(email: "existing@example.com", password: "password123")
        XCTAssertTrue(authService.accountExists(email: "existing@example.com"))
        XCTAssertFalse(authService.accountExists(email: "nonexistent@example.com"))
    }

    // MARK: - Login Tests

    func testLoginWithCorrectCredentials() {
        // Create verified account
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "password123")

        // Login
        let loginResult = authService.login(email: "user@example.com", password: "password123")
        switch loginResult {
        case .success(let session):
            XCTAssertEqual(session.email, "user@example.com")
            XCTAssertEqual(authService.currentState, .authenticated)
            XCTAssertNotNil(authService.currentSession)
        case .failure:
            XCTFail("Should login with correct credentials")
        }
    }

    func testLoginWithWrongPasswordFails() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "password123")

        let loginResult = authService.login(email: "user@example.com", password: "wrongpassword")
        switch loginResult {
        case .success:
            XCTFail("Should fail with wrong password")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.invalidPassword)
        }
    }

    func testLoginWithNonexistentUserFails() {
        let loginResult = authService.login(email: "nobody@example.com", password: "password123")
        switch loginResult {
        case .success:
            XCTFail("Should fail with nonexistent user")
        case .failure(let error):
            XCTAssertEqual(error, AuthError.userNotFound)
        }
    }

    func testGetCurrentUserAfterLogin() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "password123")
        _ = authService.login(email: "user@example.com", password: "password123")

        let currentUser = authService.getCurrentUser()
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.email, "user@example.com")
    }

    // MARK: - Logout Tests

    func testLogoutSuccessfully() {
        // Setup: create and login
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "password123")
        _ = authService.login(email: "user@example.com", password: "password123")

        // Logout
        authService.logout()
        XCTAssertNil(authService.currentSession)
        XCTAssertEqual(authService.currentState, .unauthenticated)
    }

    func testCurrentUserNilAfterLogout() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "password123")
        _ = authService.login(email: "user@example.com", password: "password123")
        authService.logout()

        XCTAssertNil(authService.getCurrentUser())
    }

    // MARK: - Password Reset Tests

    func testInitiatePasswordResetForExistingUser() {
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "oldpassword1")

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

    func testCompletePasswordResetAndLogin() {
        // Create account
        let sendResult = authService.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "user@example.com")
        _ = authService.createAccount(email: "user@example.com", password: "oldpassword1")

        // Reset password
        let resetResult = authService.initiatePasswordReset(email: "user@example.com")
        guard case .success(let resetCode) = resetResult else {
            XCTFail("Should initiate reset")
            return
        }
        _ = authService.verifyCode(resetCode.code, for: "user@example.com")
        _ = authService.completePasswordReset(email: "user@example.com", newPassword: "newpassword1")

        // Try login with new password
        let loginResult = authService.login(email: "user@example.com", password: "newpassword1")
        switch loginResult {
        case .success:
            break // Test passed
        case .failure:
            XCTFail("Should login with new password")
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
        _ = authService.createAccount(email: "user@example.com", password: "password123")
        let loginResult = authService.login(email: "user@example.com", password: "password123")

        guard case .success(let session) = loginResult else {
            XCTFail("Should login")
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

        // 3. Create account
        let createResult = authService.createAccount(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = createResult else {
            XCTFail("Should create account")
            return
        }

        // 4. Login
        let loginResult = authService.login(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = loginResult else {
            XCTFail("Should login")
            return
        }

        XCTAssertEqual(authService.currentState, .authenticated)
        XCTAssertNotNil(authService.getCurrentUser())
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

        // 3. Create account
        let createResult = authService.createAccount(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = createResult else {
            XCTFail("Should create account")
            return
        }

        // 4. Login
        let loginResult = authService.login(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = loginResult else {
            XCTFail("Should login")
            return
        }

        XCTAssertEqual(authService.currentState, .authenticated)
        XCTAssertNotNil(authService.getCurrentUser())
    }

    func testLinkStudentProfileWorks() {
        let sendResult = authService.sendVerificationCode(to: "student@example.com")
        guard case .success(let code) = sendResult else {
            XCTFail("Should send code")
            return
        }
        _ = authService.verifyCode(code.code, for: "student@example.com")
        _ = authService.createAccount(email: "student@example.com", password: "password123")

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
        _ = authService.createAccount(email: "user@example.com", password: "password123")
        _ = authService.login(email: "user@example.com", password: "password123")

        authService.reset()

        XCTAssertEqual(authService.accountCount, 0)
        XCTAssertEqual(authService.pendingVerificationCount, 0)
        XCTAssertEqual(authService.activeSessionCount, 0)
        XCTAssertEqual(authService.currentState, .unauthenticated)
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

    func testConfigIsEmailConfiguredReturnsFalseByDefault() {
        // Default config has placeholder values
        XCTAssertFalse(Config.isEmailConfigured)
    }
}
