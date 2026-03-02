//
//  MockData.swift
//  Orbit
//
//  Shared mock data for development/testing.
//  Remove or disable when backend is fully integrated.
//

import Foundation

enum MockData {

    // MARK: - Mock Mission (fixed-date community event)

    static var mockMission: Mission {
        Mission(
            id: "mock-mission-1",
            title: "MMA Club Meeting",
            description: "Weekly MMA club meetup. All skill levels welcome!",
            tags: ["Sports", "Fitness", "MMA"],
            location: "Campus Gym - Room 101",
            date: "2026-02-28",
            creatorId: 1,
            creatorType: "seeded",
            maxPodSize: 4,
            status: "open",
            matchScore: 0.85,
            suggestionReason: "Based on your interest in Sports",
            userPodStatus: "not_joined",
            userPodId: nil,
            pods: nil
        )
    }

    static var mockMissions: [Mission] {
        [mockMission]
    }

    // MARK: - Mock Signals (spontaneous activity requests)

    static var mockSignals: [Signal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return [
            Signal(
                id: "mock-signal-1",
                title: "Pickup Basketball",
                description: "Looking for people to play 5v5 at the ARC",
                activityCategory: .sports,
                customActivityName: nil,
                minGroupSize: 6,
                maxGroupSize: 10,
                availability: [
                    AvailabilitySlot(date: today.addingDays(1), timeBlocks: [.afternoon, .evening]),
                    AvailabilitySlot(date: today.addingDays(3), timeBlocks: [.morning, .afternoon]),
                    AvailabilitySlot(date: today.addingDays(5), timeBlocks: [.evening]),
                ],
                status: .pending,
                creatorId: 0,
                createdAt: ISO8601DateFormatter().string(from: today),
                podId: nil,
                links: nil
            ),
            Signal(
                id: "mock-signal-2",
                title: "Cafe Study Session",
                description: "Chill study session, bring your laptop",
                activityCategory: .study,
                customActivityName: nil,
                minGroupSize: 3,
                maxGroupSize: 5,
                availability: [
                    AvailabilitySlot(date: today.addingDays(0), timeBlocks: [.afternoon]),
                    AvailabilitySlot(date: today.addingDays(1), timeBlocks: [.morning, .afternoon]),
                    AvailabilitySlot(date: today.addingDays(2), timeBlocks: [.afternoon, .evening]),
                    AvailabilitySlot(date: today.addingDays(4), timeBlocks: [.morning]),
                ],
                status: .active,
                creatorId: 1,
                createdAt: ISO8601DateFormatter().string(from: today.addingDays(-1)),
                podId: nil,
                links: ["https://example.com/study-group"]
            ),
            Signal(
                id: "mock-signal-3",
                title: "Grab some food",
                description: "Anyone down to try that new ramen place?",
                activityCategory: .food,
                customActivityName: nil,
                minGroupSize: 3,
                maxGroupSize: 8,
                availability: [
                    AvailabilitySlot(date: today.addingDays(6), timeBlocks: [.evening]),
                    AvailabilitySlot(date: today.addingDays(7), timeBlocks: [.evening]),
                    AvailabilitySlot(date: today.addingDays(13), timeBlocks: [.afternoon, .evening]),
                ],
                status: .pending,
                creatorId: 0,
                createdAt: ISO8601DateFormatter().string(from: today),
                podId: nil,
                links: nil
            ),
        ]
    }
}

// MARK: - Date Helper

extension Date {
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
