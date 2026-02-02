//
//  DiscoverService.swift
//  Orbit
//
//  Fetches suggested profiles for discovery.
//  Set useMockData = false when server is ready.
//

import Foundation

class DiscoverService {
    static let shared = DiscoverService()
    private init() {}

    // Keep true until there are real profiles to discover
    private let useMockData = true

    func getDiscoverProfiles() async throws -> [Profile] {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return Self.mockProfiles
        }

        // Real API call
        let response: [Profile] = try await APIService.shared.request(
            endpoint: "/discover/users",
            method: "GET",
            authenticated: true
        )
        return response
    }

    // Mock profiles for testing
    static let mockProfiles: [Profile] = [
        Profile(
            name: "Alex Chen",
            age: 22,
            location: Location(city: "San Francisco", state: "CA", coordinates: nil),
            bio: "CS major who loves hiking and photography. Always down for a coffee chat or exploring new trails!",
            photos: [],
            interests: ["Hiking", "Photography", "Coffee", "Coding", "Travel"],
            personality: Personality(introvertExtrovert: 0.6, spontaneousPlanner: 0.4, activeRelaxed: 0.7),
            socialPreferences: SocialPreferences(groupSize: "Small groups (3-5)", meetingFrequency: "Weekly", preferredTimes: ["Weekends", "Evenings"]),
            friendshipGoals: []
        ),
        Profile(
            name: "Jordan Miller",
            age: 21,
            location: Location(city: "Los Angeles", state: "CA", coordinates: nil),
            bio: "Film student and amateur chef. Looking for friends to watch movies and try new restaurants with.",
            photos: [],
            interests: ["Movies", "Cooking", "Music", "Art", "Food"],
            personality: Personality(introvertExtrovert: 0.4, spontaneousPlanner: 0.7, activeRelaxed: 0.5),
            socialPreferences: SocialPreferences(groupSize: "One-on-one", meetingFrequency: "Bi-weekly", preferredTimes: ["Evenings"]),
            friendshipGoals: []
        ),
        Profile(
            name: "Sam Rodriguez",
            age: 23,
            location: Location(city: "San Diego", state: "CA", coordinates: nil),
            bio: "Grad student in biology. Love board games, beach volleyball, and late-night study sessions.",
            photos: [],
            interests: ["Board Games", "Volleyball", "Science", "Beach", "Reading"],
            personality: Personality(introvertExtrovert: 0.7, spontaneousPlanner: 0.3, activeRelaxed: 0.8),
            socialPreferences: SocialPreferences(groupSize: "Small groups (3-5)", meetingFrequency: "Weekly", preferredTimes: ["Weekends", "Afternoons"]),
            friendshipGoals: []
        ),
        Profile(
            name: "Taylor Kim",
            age: 20,
            location: Location(city: "Berkeley", state: "CA", coordinates: nil),
            bio: "Econ major, part-time barista. Into running, podcasts, and trying every boba shop in the Bay.",
            photos: [],
            interests: ["Running", "Podcasts", "Boba", "Economics", "Coffee"],
            personality: Personality(introvertExtrovert: 0.5, spontaneousPlanner: 0.6, activeRelaxed: 0.6),
            socialPreferences: SocialPreferences(groupSize: "One-on-one", meetingFrequency: "Weekly", preferredTimes: ["Mornings", "Afternoons"]),
            friendshipGoals: []
        ),
        Profile(
            name: "Diddy",
            age: 54,
            location: Location(city: "Miami", state: "FL", coordinates: nil),
            bio: "Music mogul, entrepreneur, and party enthusiast. Let's make hits and take bad boys for life. No cap, I changed the game.",
            photos: [],
            interests: ["Music", "Parties", "Fashion", "Business", "Yachts"],
            personality: Personality(introvertExtrovert: 1.0, spontaneousPlanner: 0.9, activeRelaxed: 0.95),
            socialPreferences: SocialPreferences(groupSize: "Large groups (6+)", meetingFrequency: "Daily", preferredTimes: ["Late Night"]),
            friendshipGoals: []
        )
    ]
}
