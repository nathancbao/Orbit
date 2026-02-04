// Config.swift
// Configuration settings for the Orbit app.
// Reads sensitive values from environment variables or .env file.

import Foundation

/// Application configuration settings.
/// Sensitive values are loaded from environment variables or bundled .env file.
struct Config {

    // MARK: - Environment Loading

    /// Stores loaded environment values
    private static var loadedEnv: [String: String] = {
        loadEnvironmentFromDotEnv()
    }()

    /// Loads variables from .env file.
    private static func loadEnvironmentFromDotEnv() -> [String: String] {
        var env: [String: String] = [:]

        // Paths to check for .env file (optional paths that might not exist)
        let optionalPaths: [String?] = [
            // 1. Bundled .env file (if added to app bundle)
            Bundle.main.path(forResource: ".env", ofType: nil),
            Bundle.main.path(forResource: "env", ofType: ""),

            // 2. During development with simulator - check project directory
            // The #file path points to where this source file is located
            (((#file as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent + "/../../../.env",

            // 3. Also try common project root patterns
            "/Users/jonathan/Desktop/ECS_191/Orbit/.env"
        ]

        // Filter out nil paths
        let possiblePaths = optionalPaths.compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path),
               let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                env = parseEnvironment(contents)
                #if DEBUG
                print("[Config] Loaded .env from: \(path)")
                #endif
                return env
            }
        }

        #if DEBUG
        print("[Config] Warning: .env file not found. Checked paths:")
        for path in possiblePaths {
            print("  - \(path)")
        }
        #endif

        return env
    }

    /// Parses .env file contents into a dictionary.
    private static func parseEnvironment(_ contents: String) -> [String: String] {
        var env: [String: String] = [:]
        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE (handle values with = in them)
            if let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                let valueStart = trimmed.index(after: equalsIndex)
                var value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)

                // Remove surrounding quotes if present
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }

                if !key.isEmpty {
                    env[key] = value
                }
            }
        }

        return env
    }

    /// Gets a value from loaded environment or process environment.
    private static func getEnvValue(_ key: String, default defaultValue: String = "") -> String {
        // First check our loaded .env values
        if let value = loadedEnv[key], !value.isEmpty {
            return value
        }
        // Fall back to process environment
        return ProcessInfo.processInfo.environment[key] ?? defaultValue
    }

    // MARK: - SendGrid Email Configuration

    /// Your SendGrid API key (loaded from SENDGRID_API_KEY environment variable).
    static var sendGridAPIKey: String {
        return getEnvValue("SENDGRID_API_KEY")
    }

    /// The email address that verification emails will be sent from.
    static var senderEmail: String {
        return getEnvValue("SENDER_EMAIL", default: "noreply@yourdomain.com")
    }

    /// The sender name that appears in emails.
    static var senderName: String {
        return getEnvValue("SENDER_NAME", default: "Orbit App")
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
        let isConfigured = !apiKey.isEmpty &&
                          apiKey != "YOUR_SENDGRID_API_KEY_HERE" &&
                          !email.isEmpty &&
                          email != "noreply@yourdomain.com"

        #if DEBUG
        if !isConfigured {
            print("[Config] Email not configured. API Key empty: \(apiKey.isEmpty), Email: \(email)")
        }
        #endif

        return isConfigured
    }

    // MARK: - Debug

    /// Prints current configuration status (for debugging).
    static func printStatus() {
        #if DEBUG
        print("[Config] Status:")
        print("  - SendGrid API Key: \(sendGridAPIKey.isEmpty ? "NOT SET" : "SET (\(sendGridAPIKey.prefix(10))...)")")
        print("  - Sender Email: \(senderEmail)")
        print("  - Sender Name: \(senderName)")
        print("  - Is Configured: \(isEmailConfigured)")
        #endif
    }
}
