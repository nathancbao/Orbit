// Config.swift
// Configuration settings for the Orbit app.
// Reads sensitive values from environment variables or .env file.

import Foundation

/// Application configuration settings.
/// Sensitive values are loaded from environment variables.
struct Config {

    // MARK: - Environment Loading

    /// Loads environment variables from .env file if they aren't already set.
    private static var environmentLoaded: Bool = {
        loadEnvironmentFromDotEnv()
        return true
    }()

    /// Loads variables from .env file into the process environment.
    private static func loadEnvironmentFromDotEnv() {
        // Try to find .env file in common locations
        let possiblePaths = [
            Bundle.main.path(forResource: ".env", ofType: nil),
            Bundle.main.bundlePath + "/../.env",
            FileManager.default.currentDirectoryPath + "/.env"
        ].compactMap { $0 }

        for path in possiblePaths {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                parseAndSetEnvironment(contents)
                return
            }
        }

        // Also try the project root (useful during development)
        let projectEnvPath = (#file as NSString).deletingLastPathComponent + "/../.env"
        if let contents = try? String(contentsOfFile: projectEnvPath, encoding: .utf8) {
            parseAndSetEnvironment(contents)
        }
    }

    /// Parses .env file contents and sets environment variables.
    private static func parseAndSetEnvironment(_ contents: String) {
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            // Parse KEY=VALUE
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                // Only set if not already in environment
                if ProcessInfo.processInfo.environment[key] == nil {
                    setenv(key, value, 1)
                }
            }
        }
    }

    // MARK: - SendGrid Email Configuration

    /// Your SendGrid API key (loaded from SENDGRID_API_KEY environment variable).
    static var sendGridAPIKey: String {
        _ = environmentLoaded // Ensure environment is loaded
        return ProcessInfo.processInfo.environment["SENDGRID_API_KEY"] ?? ""
    }

    /// The email address that verification emails will be sent from.
    static var senderEmail: String {
        _ = environmentLoaded
        return ProcessInfo.processInfo.environment["SENDER_EMAIL"] ?? "noreply@yourdomain.com"
    }

    /// The sender name that appears in emails.
    static var senderName: String {
        _ = environmentLoaded
        return ProcessInfo.processInfo.environment["SENDER_NAME"] ?? "Orbit App"
    }

    // MARK: - Email Settings

    /// Subject line for verification emails.
    static let verificationEmailSubject = "Your Orbit Verification Code"

    /// How long verification codes are valid (in minutes).
    static let verificationCodeExpirationMinutes = 10

    // MARK: - Validation

    /// Checks if the SendGrid API key has been configured.
    static var isEmailConfigured: Bool {
        let apiKey = sendGridAPIKey
        let email = senderEmail
        return !apiKey.isEmpty &&
               apiKey != "YOUR_SENDGRID_API_KEY_HERE" &&
               !email.isEmpty &&
               email != "noreply@yourdomain.com"
    }
}
