// EmailService.swift
// Handles sending emails via SendGrid API.
// Used for verification codes and other transactional emails.

import Foundation

// MARK: - EmailError

/// Errors that can occur during email operations.
enum EmailError: Error, Equatable {
    case notConfigured
    case invalidEmail
    case networkError(String)
    case apiError(Int, String)
    case encodingError

    var localizedDescription: String {
        switch self {
        case .notConfigured:
            return "Email service is not configured. Please set up your SendGrid API key in Config.swift"
        case .invalidEmail:
            return "Invalid email address provided."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            return "Email API error (\(code)): \(message)"
        case .encodingError:
            return "Failed to encode email request."
        }
    }

    // Equatable conformance for testing
    static func == (lhs: EmailError, rhs: EmailError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured):
            return true
        case (.invalidEmail, .invalidEmail):
            return true
        case (.encodingError, .encodingError):
            return true
        case (.networkError(let l), .networkError(let r)):
            return l == r
        case (.apiError(let lCode, let lMsg), .apiError(let rCode, let rMsg)):
            return lCode == rCode && lMsg == rMsg
        default:
            return false
        }
    }
}

// MARK: - EmailServiceProtocol

/// Protocol for email sending services.
/// Allows for easy mocking in tests.
protocol EmailServiceProtocol {
    func sendVerificationEmail(to email: String, code: String) async -> Result<Bool, EmailError>
}

// MARK: - EmailService

/// Service for sending emails via SendGrid API.
class EmailService: EmailServiceProtocol {

    // MARK: - Singleton

    /// Shared instance for convenience.
    static let shared = EmailService()

    // MARK: - Properties

    private let apiKey: String
    private let senderEmail: String
    private let senderName: String
    private let session: URLSession

    // MARK: - Initialization

    init(
        apiKey: String = Config.sendGridAPIKey,
        senderEmail: String = Config.senderEmail,
        senderName: String = Config.senderName,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.session = session
    }

    // MARK: - Public Methods

    /// Sends a verification code email to the specified address.
    /// - Parameters:
    ///   - email: The recipient's email address
    ///   - code: The 6-digit verification code
    /// - Returns: Result indicating success or an EmailError
    func sendVerificationEmail(to email: String, code: String) async -> Result<Bool, EmailError> {
        // Check if email service is configured
        guard Config.isEmailConfigured else {
            return .failure(.notConfigured)
        }

        // Validate email format
        guard email.isValidEmail else {
            return .failure(.invalidEmail)
        }

        // Build email content
        let subject = Config.verificationEmailSubject
        let htmlContent = buildVerificationEmailHTML(code: code)
        let plainContent = buildVerificationEmailPlain(code: code)

        // Send via SendGrid
        return await sendEmail(
            to: email,
            subject: subject,
            htmlContent: htmlContent,
            plainContent: plainContent
        )
    }

    // MARK: - Private Methods

    /// Sends an email via SendGrid API.
    private func sendEmail(
        to recipientEmail: String,
        subject: String,
        htmlContent: String,
        plainContent: String
    ) async -> Result<Bool, EmailError> {

        // SendGrid API endpoint
        guard let url = URL(string: "https://api.sendgrid.com/v3/mail/send") else {
            return .failure(.networkError("Invalid API URL"))
        }

        // Build request body
        let requestBody: [String: Any] = [
            "personalizations": [
                [
                    "to": [
                        ["email": recipientEmail]
                    ]
                ]
            ],
            "from": [
                "email": senderEmail,
                "name": senderName
            ],
            "subject": subject,
            "content": [
                [
                    "type": "text/plain",
                    "value": plainContent
                ],
                [
                    "type": "text/html",
                    "value": htmlContent
                ]
            ]
        ]

        // Encode request body
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return .failure(.encodingError)
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        // Send request
        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.networkError("Invalid response"))
            }

            // SendGrid returns 202 Accepted for successful sends
            if httpResponse.statusCode == 202 {
                return .success(true)
            } else {
                return .failure(.apiError(httpResponse.statusCode, "Email send failed"))
            }
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    /// Builds HTML content for verification email.
    private func buildVerificationEmailHTML(code: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px; }
                .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 12px; padding: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .logo { text-align: center; margin-bottom: 30px; }
                .logo h1 { color: #333; font-size: 28px; letter-spacing: 4px; margin: 0; }
                .code-box { background: linear-gradient(135deg, #ff8a80 0%, #b288ff 100%); border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; }
                .code { font-size: 36px; font-weight: bold; color: white; letter-spacing: 8px; font-family: monospace; }
                .message { color: #666; font-size: 16px; line-height: 1.6; text-align: center; }
                .footer { margin-top: 30px; text-align: center; color: #999; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="logo">
                    <h1>ORBIT</h1>
                </div>
                <p class="message">Here's your verification code:</p>
                <div class="code-box">
                    <span class="code">\(code)</span>
                </div>
                <p class="message">Enter this code in the app to verify your email address.<br>This code expires in \(Config.verificationCodeExpirationMinutes) minutes.</p>
                <div class="footer">
                    <p>If you didn't request this code, you can safely ignore this email.</p>
                </div>
            </div>
        </body>
        </html>
        """
    }

    /// Builds plain text content for verification email.
    private func buildVerificationEmailPlain(code: String) -> String {
        return """
        ORBIT - Email Verification

        Your verification code is: \(code)

        Enter this code in the app to verify your email address.
        This code expires in \(Config.verificationCodeExpirationMinutes) minutes.

        If you didn't request this code, you can safely ignore this email.
        """
    }
}

// MARK: - Mock Email Service (for testing)

/// Mock email service for unit testing.
/// Does not actually send emails.
class MockEmailService: EmailServiceProtocol {

    var shouldSucceed: Bool = true
    var lastSentEmail: String?
    var lastSentCode: String?
    var sendCount: Int = 0

    func sendVerificationEmail(to email: String, code: String) async -> Result<Bool, EmailError> {
        lastSentEmail = email
        lastSentCode = code
        sendCount += 1

        if shouldSucceed {
            return .success(true)
        } else {
            return .failure(.networkError("Mock network failure"))
        }
    }

    func reset() {
        shouldSucceed = true
        lastSentEmail = nil
        lastSentCode = nil
        sendCount = 0
    }
}
