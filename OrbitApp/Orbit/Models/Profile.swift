import Foundation

struct Profile: Codable, Identifiable, Equatable {
    // Use name as a stable identifier within a session; real identity is the user_id from the server.
    var id: String { name }

    var name: String
    var collegeYear: String       // freshman | sophomore | junior | senior | grad
    var interests: [String]
    var photo: String?            // Optional profile photo URL
    var trustScore: Double?       // 0.0 – 5.0, server-computed
    var email: String?

    // Computed in discover flow
    var matchScore: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case collegeYear = "college_year"
        case interests
        case photo
        case trustScore = "trust_score"
        case email
        case matchScore = "match_score"
    }

    static let collegeYears = ["freshman", "sophomore", "junior", "senior", "grad"]

    static func displayYear(_ year: String) -> String {
        year.prefix(1).uppercased() + year.dropFirst()
    }
}
