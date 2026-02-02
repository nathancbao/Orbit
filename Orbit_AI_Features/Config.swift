// Config.swift
// Configuration settings for the Orbit app.
// IMPORTANT: Fill in your API keys before using email functionality.

import Foundation

/// Application configuration settings.
/// Update these values with your own API keys and settings.
struct Config {

    // MARK: - SendGrid Email Configuration

    /// Your SendGrid API key.
    /// Get one at: https://sendgrid.com/ → Settings → API Keys → Create API Key
    /// Choose "Restricted Access" and enable "Mail Send" permission.
    static let sendGridAPIKey = "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"

    /// The email address that verification emails will be sent from.
    /// This must be verified in your SendGrid account under:
    /// Settings → Sender Authentication → Single Sender Verification
    static let senderEmail = "lewjon12345@gmail.com"

    /// The sender name that appears in emails.
    static let senderName = "Jonathan"

    // MARK: - Email Settings

    /// Subject line for verification emails.
    static let verificationEmailSubject = "Your Orbit Verification Code"

    /// How long verification codes are valid (in minutes).
    static let verificationCodeExpirationMinutes = 10

    // MARK: - Validation

    /// Checks if the SendGrid API key has been configured.
    static var isEmailConfigured: Bool {
        return sendGridAPIKey != "YOUR_SENDGRID_API_KEY_HERE" &&
               !sendGridAPIKey.isEmpty &&
               senderEmail != "noreply@yourdomain.com"
    }
}
