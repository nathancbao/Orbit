//
//  SignalModels.swift
//  Orbit
//
//  Data models for the Signals/Pods feature.
//  Signals are pending group invites; Pods are accepted groups.
//

import Foundation

// MARK: - Signal Status

enum SignalStatus: String, Codable {
    case hasPod = "has_pod"
    case hasSignal = "has_signal"
    case newSignal = "new_signal"
    case noMatch = "no_match"
}

// MARK: - Signal (pending invite)

struct Signal: Codable, Identifiable {
    let id: String
    let creatorId: Int?
    let targetUserIds: [Int]
    let acceptedUserIds: [Int]
    let createdAt: String?
    let expiresAt: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case targetUserIds = "target_user_ids"
        case acceptedUserIds = "accepted_user_ids"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case status
    }
}

// MARK: - Pod (accepted group)

struct Pod: Codable, Identifiable {
    let id: String
    let members: [Int]
    let createdAt: String?
    let expiresAt: String?
    let revealed: Bool
    let signalId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case members
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case revealed
        case signalId = "signal_id"
    }
}

// MARK: - Pod Member (preview with optional contact info)

struct PodMember: Codable, Identifiable {
    let userId: Int
    let name: String
    let interests: [String]
    let contactInfo: ContactInfo?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case interests
        case contactInfo = "contact_info"
    }
}

// MARK: - Contact Info (revealed after pod reveal)

struct ContactInfo: Codable {
    let instagram: String?
    let phone: String?
}

// MARK: - API Response for signal check

struct SignalCheckResponse: Codable {
    let status: SignalStatus
    let signal: Signal?
    let pod: Pod?
    let members: [PodMember]?
    let revealed: Bool?
}
