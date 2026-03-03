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

    // Extended profile fields (all optional)
    var galleryPhotos: [String]
    var bio: String
    var links: [String]
    var gender: String
    var mbti: String

    // Computed in discover flow
    var matchScore: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case collegeYear = "college_year"
        case interests
        case photo
        case trustScore = "trust_score"
        case email
        case galleryPhotos = "gallery_photos"
        case bio
        case links
        case gender
        case mbti
        case matchScore = "match_score"
    }

    init(name: String, collegeYear: String, interests: [String],
         photo: String? = nil, trustScore: Double? = nil, email: String? = nil,
         galleryPhotos: [String] = [], bio: String = "", links: [String] = [],
         gender: String = "", mbti: String = "", matchScore: Double? = nil) {
        self.name = name
        self.collegeYear = collegeYear
        self.interests = interests
        self.photo = photo
        self.trustScore = trustScore
        self.email = email
        self.galleryPhotos = galleryPhotos
        self.bio = bio
        self.links = links
        self.gender = gender
        self.mbti = mbti
        self.matchScore = matchScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        collegeYear = try container.decode(String.self, forKey: .collegeYear)
        interests = try container.decode([String].self, forKey: .interests)
        photo = try container.decodeIfPresent(String.self, forKey: .photo)
        trustScore = try container.decodeIfPresent(Double.self, forKey: .trustScore)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        galleryPhotos = try container.decodeIfPresent([String].self, forKey: .galleryPhotos) ?? []
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        links = try container.decodeIfPresent([String].self, forKey: .links) ?? []
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? ""
        mbti = try container.decodeIfPresent(String.self, forKey: .mbti) ?? ""
        matchScore = try container.decodeIfPresent(Double.self, forKey: .matchScore)
    }

    static let collegeYears = ["freshman", "sophomore", "junior", "senior", "grad"]

    static func displayYear(_ year: String) -> String {
        year.prefix(1).uppercased() + year.dropFirst()
    }

    // MARK: - MBTI Data

    static let mbtiGroupOrder = ["Analysts", "Diplomats", "Sentinels", "Explorers"]

    static let mbtiTypes: [String: [String]] = [
        "Analysts": ["INTJ", "INTP", "ENTJ", "ENTP"],
        "Diplomats": ["INFJ", "INFP", "ENFJ", "ENFP"],
        "Sentinels": ["ISTJ", "ISFJ", "ESTJ", "ESFJ"],
        "Explorers": ["ISTP", "ISFP", "ESTP", "ESFP"],
    ]

    // MARK: - Gender Data

    static let genderOptions = ["male", "female", "non-binary", "other"]

    static func displayGender(_ gender: String) -> String {
        switch gender {
        case "male": return "Male"
        case "female": return "Female"
        case "non-binary": return "Non-binary"
        case "other": return "Other"
        default: return gender.capitalized
        }
    }
}
