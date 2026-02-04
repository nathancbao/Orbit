//
//  APIService.swift
//  Orbit
//
//  API SERVICE (Networking Layer)
//  Handles all HTTP requests to the backend server.
//  This is the foundation that all other services (Auth, Profile) use.
//
//  SERVER INTEGRATION (Friend 1):
//  1. Update Constants.API.baseURL with your server URL
//  2. Make sure your API returns responses in this format:
//     Success: { "success": true, "data": { ... } }
//     Error:   { "success": false, "error": { "code": "...", "message": "..." } }
//
//  KEY FEATURES:
//  - Automatic JSON encoding/decoding
//  - Auth token handling (reads from Keychain)
//  - Error handling with user-friendly messages
//  - Snake_case <-> camelCase conversion
//

import Foundation

// MARK: - Network Error
// Custom error types for API failures
// These get converted to user-friendly messages
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return message  // Server-provided error message
        case .unauthorized:
            return "Unauthorized"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - API Service
class APIService {
    // Singleton - use APIService.shared to access
    static let shared = APIService()
    private init() {}

    // Base URL from Constants - update this when server is ready
    private let baseURL = Constants.API.baseURL

    // ============================================================
    // MARK: - JSON Decoder
    // Configured to handle API response format
    // ============================================================
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // Handles ISO date strings
        return decoder
    }

    // ============================================================
    // MARK: - JSON Encoder
    // Configured to send data in API-expected format
    // ============================================================
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase  // camelCase -> snake_case
        return encoder
    }

    // ============================================================
    // MARK: - Auth Header
    // Gets the access token from Keychain for authenticated requests
    // ============================================================
    private func getAuthHeader() -> String? {
        return KeychainHelper.shared.readString(forKey: Constants.Keychain.accessToken)
    }

    // ============================================================
    // MARK: - Generic Request Method
    // All API calls go through this method
    //
    // Parameters:
    //   - endpoint: API path (e.g., "/users/me/profile")
    //   - method: HTTP method ("GET", "POST", "PUT", "DELETE")
    //   - body: Request body as dictionary (will be JSON encoded)
    //   - authenticated: If true, adds Bearer token to request
    //
    // Returns: Decoded response data of type T
    // Throws: NetworkError on failure
    // ============================================================
    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        // Build URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        // Configure request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if required
        if authenticated, let token = getAuthHeader() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add request body if provided
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // Make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noData
            }

            // Handle 401 Unauthorized
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }

            // Handle other error status codes (400+)
            if httpResponse.statusCode >= 400 {
                // Try to decode error response from server
                // Server format: { "success": false, "error": "message" }
                if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data),
                   let errorMessage = errorResponse.error {
                    throw NetworkError.serverError(errorMessage)
                }
                throw NetworkError.serverError("Request failed with status \(httpResponse.statusCode)")
            }

            // Decode successful response
            // Server wraps data in: { "success": true, "data": { ... } }
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            guard let data = apiResponse.data else {
                throw NetworkError.noData
            }
            return data

        } catch let error as NetworkError {
            throw error
        } catch let error as DecodingError {
            print("Decoding error: \(error)")  // Helpful for debugging
            throw NetworkError.decodingError
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}
