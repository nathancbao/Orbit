// AuthenticationServiceTests.swift
// Unit tests for the AuthenticationService.
// Run with: swift AuthenticationServiceTests.swift AuthModels.swift AuthenticationService.swift

import Foundation

// MARK: - Test Framework (Simple)
// A lightweight test framework since we're not using XCTest directly

struct TestResult {
    let name: String
    let passed: Bool
    let message: String?
}

var allTestResults: [TestResult] = []

func test(_ name: String, _ block: () throws -> Bool) {
    do {
        let passed = try block()
        allTestResults.append(TestResult(name: name, passed: passed, message: nil))
        print(passed ? "  \u{2705} \(name)" : "  \u{274C} \(name)")
    } catch {
        allTestResults.append(TestResult(name: name, passed: false, message: error.localizedDescription))
        print("  \u{274C} \(name) - Error: \(error)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") -> Bool {
    if actual != expected {
        print("    Expected: \(expected), Got: \(actual) \(message)")
        return false
    }
    return true
}

func assertTrue(_ condition: Bool, _ message: String = "") -> Bool {
    if !condition {
        print("    Assertion failed: \(message)")
        return false
    }
    return true
}

func assertFalse(_ condition: Bool, _ message: String = "") -> Bool {
    return assertTrue(!condition, message)
}

// MARK: - Test Suites

func runEmailValidationTests() {
    print("\n=== Email Validation Tests ===")

    let service = AuthenticationService()

    test("Valid email should pass validation") {
        let result = service.validateEmail("test@example.com")
        switch result {
        case .success(let email):
            return assertEqual(email, "test@example.com")
        case .failure:
            return false
        }
    }

    test("Valid email with uppercase should be normalized") {
        let result = service.validateEmail("Test@EXAMPLE.COM")
        switch result {
        case .success(let email):
            return assertEqual(email, "test@example.com")
        case .failure:
            return false
        }
    }

    test("Email with leading/trailing spaces should be trimmed") {
        let result = service.validateEmail("  test@example.com  ")
        switch result {
        case .success(let email):
            return assertEqual(email, "test@example.com")
        case .failure:
            return false
        }
    }

    test("Empty email should fail") {
        let result = service.validateEmail("")
        switch result {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.emptyEmail)
        }
    }

    test("Invalid email (no @) should fail") {
        let result = service.validateEmail("testexample.com")
        switch result {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidEmail)
        }
    }

    test("Invalid email (no domain) should fail") {
        let result = service.validateEmail("test@")
        switch result {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidEmail)
        }
    }

    test("Invalid email (no TLD) should fail") {
        let result = service.validateEmail("test@example")
        switch result {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidEmail)
        }
    }

    test("Valid .edu email should pass") {
        let result = service.validateEmail("student@university.edu")
        switch result {
        case .success(let email):
            return assertEqual(email, "student@university.edu")
        case .failure:
            return false
        }
    }

    test("Valid email with subdomain should pass") {
        let result = service.validateEmail("user@mail.example.com")
        switch result {
        case .success(let email):
            return assertEqual(email, "user@mail.example.com")
        case .failure:
            return false
        }
    }

    test("Valid email with plus sign should pass") {
        let result = service.validateEmail("user+tag@example.com")
        switch result {
        case .success(let email):
            return assertEqual(email, "user+tag@example.com")
        case .failure:
            return false
        }
    }
}

func runVerificationCodeTests() {
    print("\n=== Verification Code Tests ===")

    test("Verification code should be 6 digits") {
        let code = VerificationCode(email: "test@example.com")
        return assertEqual(code.code.count, 6) && assertTrue(Int(code.code) != nil)
    }

    test("Verification code should be associated with email") {
        let code = VerificationCode(email: "TEST@Example.com")
        return assertEqual(code.email, "test@example.com")
    }

    test("Fresh verification code should be valid") {
        let code = VerificationCode(email: "test@example.com")
        return assertTrue(code.isValid)
    }

    test("Verification code should match correctly") {
        let code = VerificationCode(email: "test@example.com", code: "123456")
        return assertTrue(code.matches("123456"))
    }

    test("Verification code should not match incorrect code") {
        let code = VerificationCode(email: "test@example.com", code: "123456")
        return assertFalse(code.matches("654321"))
    }

    test("Custom code should work") {
        let code = VerificationCode(email: "test@example.com", code: "999999")
        return assertEqual(code.code, "999999")
    }

    test("Expired code should be invalid") {
        // Create code that expires immediately (0 minutes)
        let code = VerificationCode(email: "test@example.com", expirationMinutes: 0)
        // Wait a tiny bit to ensure expiration
        Thread.sleep(forTimeInterval: 0.1)
        return assertFalse(code.isValid)
    }
}

func runSendVerificationTests() {
    print("\n=== Send Verification Tests ===")

    test("Should send verification code to valid email") {
        let service = AuthenticationService()
        let result = service.sendVerificationCode(to: "test@example.com")
        switch result {
        case .success(let code):
            return assertEqual(code.email, "test@example.com") &&
                   assertEqual(code.code.count, 6) &&
                   assertEqual(service.currentState, AuthenticationState.verificationSent)
        case .failure:
            return false
        }
    }

    test("Should fail to send verification to invalid email") {
        let service = AuthenticationService()
        let result = service.sendVerificationCode(to: "invalid-email")
        switch result {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidEmail)
        }
    }

    test("Pending verification count should increase") {
        let service = AuthenticationService()
        _ = service.sendVerificationCode(to: "test@example.com")
        return assertEqual(service.pendingVerificationCount, 1)
    }

    test("Multiple verifications to same email should overwrite") {
        let service = AuthenticationService()
        _ = service.sendVerificationCode(to: "test@example.com")
        _ = service.sendVerificationCode(to: "test@example.com")
        return assertEqual(service.pendingVerificationCount, 1)
    }
}

func runVerifyCodeTests() {
    print("\n=== Verify Code Tests ===")

    test("Should verify correct code") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "test@example.com")
        guard case .success(let sentCode) = sendResult else { return false }

        let verifyResult = service.verifyCode(sentCode.code, for: "test@example.com")
        switch verifyResult {
        case .success(let verified):
            return assertTrue(verified) &&
                   assertEqual(service.currentState, AuthenticationState.verified)
        case .failure:
            return false
        }
    }

    test("Should fail with incorrect code") {
        let service = AuthenticationService()
        _ = service.sendVerificationCode(to: "test@example.com")

        let verifyResult = service.verifyCode("000000", for: "test@example.com")
        switch verifyResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidVerificationCode)
        }
    }

    test("Should fail with no pending verification") {
        let service = AuthenticationService()
        let verifyResult = service.verifyCode("123456", for: "nonexistent@example.com")
        switch verifyResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidVerificationCode)
        }
    }

    test("Pending verification should be removed after success") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "test@example.com")
        guard case .success(let sentCode) = sendResult else { return false }

        _ = service.verifyCode(sentCode.code, for: "test@example.com")
        return assertEqual(service.pendingVerificationCount, 0)
    }
}

func runAccountCreationTests() {
    print("\n=== Account Creation Tests ===")

    test("Should create account with valid email and password") {
        let service = AuthenticationService()
        // First verify email
        let sendResult = service.sendVerificationCode(to: "new@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "new@example.com")

        // Then create account
        let createResult = service.createAccount(email: "new@example.com", password: "password123")
        switch createResult {
        case .success(let account):
            return assertEqual(account.email, "new@example.com") &&
                   assertTrue(account.isEmailVerified) &&
                   assertEqual(service.accountCount, 1)
        case .failure:
            return false
        }
    }

    test("Should fail with short password") {
        let service = AuthenticationService()
        let createResult = service.createAccount(email: "test@example.com", password: "short")
        switch createResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.passwordTooShort)
        }
    }

    test("Should fail with duplicate email") {
        let service = AuthenticationService()
        _ = service.createAccount(email: "test@example.com", password: "password123")
        let createResult = service.createAccount(email: "test@example.com", password: "password456")
        switch createResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.userAlreadyExists)
        }
    }

    test("Should check if account exists") {
        let service = AuthenticationService()
        _ = service.createAccount(email: "existing@example.com", password: "password123")
        return assertTrue(service.accountExists(email: "existing@example.com")) &&
               assertFalse(service.accountExists(email: "nonexistent@example.com"))
    }
}

func runLoginTests() {
    print("\n=== Login Tests ===")

    test("Should login with correct credentials") {
        let service = AuthenticationService()
        // Create verified account
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")

        // Login
        let loginResult = service.login(email: "user@example.com", password: "password123")
        switch loginResult {
        case .success(let session):
            return assertEqual(session.email, "user@example.com") &&
                   assertEqual(service.currentState, AuthenticationState.authenticated) &&
                   assertTrue(service.currentSession != nil)
        case .failure:
            return false
        }
    }

    test("Should fail login with wrong password") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")

        let loginResult = service.login(email: "user@example.com", password: "wrongpassword")
        switch loginResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.invalidPassword)
        }
    }

    test("Should fail login with nonexistent user") {
        let service = AuthenticationService()
        let loginResult = service.login(email: "nobody@example.com", password: "password123")
        switch loginResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.userNotFound)
        }
    }

    test("Should get current user after login") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")
        _ = service.login(email: "user@example.com", password: "password123")

        guard let currentUser = service.getCurrentUser() else { return false }
        return assertEqual(currentUser.email, "user@example.com")
    }
}

func runLogoutTests() {
    print("\n=== Logout Tests ===")

    test("Should logout successfully") {
        let service = AuthenticationService()
        // Setup: create and login
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")
        _ = service.login(email: "user@example.com", password: "password123")

        // Logout
        service.logout()
        return assertTrue(service.currentSession == nil) &&
               assertEqual(service.currentState, AuthenticationState.unauthenticated)
    }

    test("Should return nil for current user after logout") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")
        _ = service.login(email: "user@example.com", password: "password123")
        service.logout()

        return assertTrue(service.getCurrentUser() == nil)
    }
}

func runPasswordResetTests() {
    print("\n=== Password Reset Tests ===")

    test("Should initiate password reset for existing user") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "oldpassword1")

        let resetResult = service.initiatePasswordReset(email: "user@example.com")
        switch resetResult {
        case .success(let code):
            return assertEqual(code.email, "user@example.com")
        case .failure:
            return false
        }
    }

    test("Should fail password reset for nonexistent user") {
        let service = AuthenticationService()
        let resetResult = service.initiatePasswordReset(email: "nobody@example.com")
        switch resetResult {
        case .success:
            return false
        case .failure(let error):
            return assertEqual(error, AuthError.userNotFound)
        }
    }

    test("Should complete password reset and allow login") {
        let service = AuthenticationService()
        // Create account
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "oldpassword1")

        // Reset password
        let resetResult = service.initiatePasswordReset(email: "user@example.com")
        guard case .success(let resetCode) = resetResult else { return false }
        _ = service.verifyCode(resetCode.code, for: "user@example.com")
        _ = service.completePasswordReset(email: "user@example.com", newPassword: "newpassword1")

        // Try login with new password
        let loginResult = service.login(email: "user@example.com", password: "newpassword1")
        switch loginResult {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

func runSessionTests() {
    print("\n=== Session Tests ===")

    test("New session should be valid") {
        let session = AuthSession(userID: UUID(), email: "test@example.com")
        return assertTrue(session.isValid)
    }

    test("Session validation should work") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")
        let loginResult = service.login(email: "user@example.com", password: "password123")

        guard case .success(let session) = loginResult else { return false }
        return assertTrue(service.isSessionValid(session.id))
    }

    test("Invalid session ID should return false") {
        let service = AuthenticationService()
        return assertFalse(service.isSessionValid(UUID()))
    }
}

func runIntegrationTests() {
    print("\n=== Integration Tests ===")

    test("Full signup flow should work") {
        let service = AuthenticationService()

        // 1. Send verification
        let sendResult = service.sendVerificationCode(to: "newuser@example.com")
        guard case .success(let code) = sendResult else { return false }

        // 2. Verify code
        let verifyResult = service.verifyCode(code.code, for: "newuser@example.com")
        guard case .success(_) = verifyResult else { return false }

        // 3. Create account
        let createResult = service.createAccount(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = createResult else { return false }

        // 4. Login
        let loginResult = service.login(email: "newuser@example.com", password: "mypassword123")
        guard case .success(_) = loginResult else { return false }

        return assertEqual(service.currentState, AuthenticationState.authenticated) &&
               assertTrue(service.getCurrentUser() != nil)
    }

    test("Link student profile should work") {
        let service = AuthenticationService()
        let sendResult = service.sendVerificationCode(to: "student@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "student@example.com")
        _ = service.createAccount(email: "student@example.com", password: "password123")

        let studentID = UUID()
        let linked = service.linkStudentProfile(studentID: studentID, to: "student@example.com")
        return assertTrue(linked)
    }

    test("Service reset should clear all state") {
        let service = AuthenticationService()
        _ = service.sendVerificationCode(to: "test@example.com")
        let sendResult = service.sendVerificationCode(to: "user@example.com")
        guard case .success(let code) = sendResult else { return false }
        _ = service.verifyCode(code.code, for: "user@example.com")
        _ = service.createAccount(email: "user@example.com", password: "password123")
        _ = service.login(email: "user@example.com", password: "password123")

        service.reset()

        return assertEqual(service.accountCount, 0) &&
               assertEqual(service.pendingVerificationCount, 0) &&
               assertEqual(service.activeSessionCount, 0) &&
               assertEqual(service.currentState, AuthenticationState.unauthenticated)
    }
}

// MARK: - Run All Tests

func runAllTests() {
    print("\n" + String(repeating: "=", count: 50))
    print("  AUTHENTICATION SERVICE TESTS")
    print(String(repeating: "=", count: 50))

    runEmailValidationTests()
    runVerificationCodeTests()
    runSendVerificationTests()
    runVerifyCodeTests()
    runAccountCreationTests()
    runLoginTests()
    runLogoutTests()
    runPasswordResetTests()
    runSessionTests()
    runIntegrationTests()

    // Summary
    let passed = allTestResults.filter { $0.passed }.count
    let failed = allTestResults.filter { !$0.passed }.count
    let total = allTestResults.count

    print("\n" + String(repeating: "=", count: 50))
    print("  TEST SUMMARY")
    print(String(repeating: "=", count: 50))
    print("  Total:  \(total)")
    print("  Passed: \(passed) \u{2705}")
    print("  Failed: \(failed) \(failed > 0 ? "\u{274C}" : "")")
    print(String(repeating: "=", count: 50))

    if failed > 0 {
        print("\nFailed tests:")
        for result in allTestResults where !result.passed {
            print("  - \(result.name)")
            if let message = result.message {
                print("    \(message)")
            }
        }
    }
}

// MARK: - Main Entry Point
// Wrap in @main for compiled execution
@main
struct TestRunner {
    static func main() {
        runAllTests()
    }
}
