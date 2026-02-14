//
//  SignalService.swift
//  Orbit
//
//  Handles signal discovery and pod lifecycle API calls.
//  Set useMockData = false when backend is ready.
//

import Foundation

class SignalService {
    static let shared = SignalService()
    private init() {}

    private let useMockData = true

    // Mock state machine: cycles through the flow for demo purposes
    private var mockCallCount = 0

    // MARK: - Check for Signal

    func checkForSignal() async throws -> SignalCheckResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 600_000_000)
            return mockSignalResponse()
        }

        return try await APIService.shared.request(
            endpoint: "/signals/signal",
            method: "GET",
            authenticated: true
        )
    }

    // MARK: - Accept Signal

    func acceptSignal(signalId: String) async throws -> SignalCheckResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            // After accepting, transition to lobby (has_signal with partial acceptance)
            return SignalCheckResponse(
                status: .hasSignal,
                signal: Signal(
                    id: signalId,
                    creatorId: 0,
                    targetUserIds: [0, 1, 2, 3],
                    acceptedUserIds: [0, 1],
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)),
                    status: "pending"
                ),
                pod: nil,
                members: mockMembers(),
                revealed: nil
            )
        }

        return try await APIService.shared.request(
            endpoint: "/signals/signal/\(signalId)/accept",
            method: "POST",
            authenticated: true
        )
    }

    // MARK: - Update Contact Info

    func updateContactInfo(instagram: String?, phone: String?) async throws -> ContactInfo {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return ContactInfo(instagram: instagram, phone: phone)
        }

        var body: [String: Any] = [:]
        if let instagram = instagram { body["instagram"] = instagram }
        if let phone = phone { body["phone"] = phone }

        return try await APIService.shared.request(
            endpoint: "/signals/contact-info",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    // MARK: - Mock Helpers

    private func mockSignalResponse() -> SignalCheckResponse {
        mockCallCount += 1

        // Cycle: 1=newSignal, 2+=hasPod (revealed)
        if mockCallCount <= 1 {
            // First call: new signal found
            return SignalCheckResponse(
                status: .newSignal,
                signal: Signal(
                    id: "mock-signal-1",
                    creatorId: 0,
                    targetUserIds: [0, 1, 2, 3],
                    acceptedUserIds: [],
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)),
                    status: "pending"
                ),
                pod: nil,
                members: mockMembers(),
                revealed: nil
            )
        } else {
            // Subsequent calls: active pod (revealed)
            return SignalCheckResponse(
                status: .hasPod,
                signal: nil,
                pod: Pod(
                    id: "mock-pod-1",
                    members: [0, 1, 2, 3],
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)),
                    revealed: true,
                    signalId: "mock-signal-1"
                ),
                members: mockMembersWithContact(),
                revealed: true
            )
        }
    }

    private func mockMembers() -> [PodMember] {
        [
            PodMember(userId: 1, name: "Alex", interests: ["Hiking", "Photography", "Music"], contactInfo: nil),
            PodMember(userId: 2, name: "Jordan", interests: ["Music", "Gaming", "Cooking"], contactInfo: nil),
            PodMember(userId: 3, name: "Sam", interests: ["Cooking", "Travel", "Art"], contactInfo: nil),
        ]
    }

    private func mockMembersWithContact() -> [PodMember] {
        [
            PodMember(userId: 1, name: "Alex", interests: ["Hiking", "Photography", "Music"],
                      contactInfo: ContactInfo(instagram: "@alex_explores", phone: nil)),
            PodMember(userId: 2, name: "Jordan", interests: ["Music", "Gaming", "Cooking"],
                      contactInfo: ContactInfo(instagram: "@jordan_beats", phone: "555-0102")),
            PodMember(userId: 3, name: "Sam", interests: ["Cooking", "Travel", "Art"],
                      contactInfo: ContactInfo(instagram: "@sam_creates", phone: nil)),
        ]
    }

    func resetMockState() {
        mockCallCount = 0
    }
}
