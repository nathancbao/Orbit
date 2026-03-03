//
//  DiscoveryViewModel.swift
//  Orbit
//
//  State management for the Discovery galaxy view — fetches missions (set + flex),
//  AI recommendations, and generates template items from user interests.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Template Item

struct TemplateItem: Identifiable {
    let id = UUID()
    let title: String
    let interest: String
    let suggestedTags: [String]
}

// MARK: - Discovery Item

enum DiscoveryItem: Identifiable, Equatable {
    static func == (lhs: DiscoveryItem, rhs: DiscoveryItem) -> Bool {
        lhs.id == rhs.id
    }

    case hostedMission(Mission)
    case joinedMission(Mission)
    case recommendedMission(Mission)
    case discoverableMission(Mission)
    case template(TemplateItem)

    var id: String {
        switch self {
        case .hostedMission(let m):       return "hm-\(m.id)"
        case .joinedMission(let m):       return "jm-\(m.id)"
        case .recommendedMission(let m):  return "rm-\(m.id)"
        case .discoverableMission(let m): return "dm-\(m.id)"
        case .template(let t):            return "t-\(t.id)"
        }
    }

    /// Priority tier: 0 = hosted (inner ring), 1 = joined, 2 = recommended, 3 = discoverable/template (outer ring)
    var priority: Int {
        switch self {
        case .hostedMission:       return 0
        case .joinedMission:       return 1
        case .recommendedMission:  return 2
        case .discoverableMission: return 3
        case .template:            return 3
        }
    }
}

// MARK: - ViewModel

@MainActor
class DiscoveryViewModel: ObservableObject {

    @Published var items: [DiscoveryItem] = []
    @Published var isLoading = false
    @Published var showRecommendationBadge = false

    let userInterests: [String]

    private var hasLoaded = false
    private var bellTimerTask: Task<Void, Never>?
    private var recommendedItems: [DiscoveryItem] = []

    private var currentUserId: Int {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }

    init(userInterests: [String] = []) {
        self.userInterests = userInterests
    }

    // MARK: - Load

    func load() async {
        guard !hasLoaded else { return }
        isLoading = true
        defer { isLoading = false }

        // Fetch each source independently so a single failure doesn't wipe others.
        let missions = (try? await MissionService.shared.listMissions()) ?? []
        let suggested = (try? await MissionService.shared.suggestedMissions()) ?? []

        // Fetch signals and convert to flex missions
        let mySignals = (try? await SignalService.shared.mySignals()) ?? []
        let discoverSignals = (try? await SignalService.shared.discoverSignals()) ?? []
        let rsvpSignals: [Signal] = (try? await APIService.shared.request(
            endpoint: Constants.API.Endpoints.myRsvps,
            authenticated: true
        )) ?? []

        categorize(
            missions: missions,
            mySignals: mySignals,
            discoverSignals: discoverSignals,
            suggested: suggested,
            rsvpSignals: rsvpSignals
        )
        hasLoaded = true
    }

    func reload() async {
        hasLoaded = false
        showRecommendationBadge = false
        bellTimerTask?.cancel()
        await load()
        startBellTimer()
    }

    // MARK: - Categorize

    private func categorize(
        missions: [Mission],
        mySignals: [Signal],
        discoverSignals: [Signal],
        suggested: [Mission],
        rsvpSignals: [Signal]
    ) {
        var result: [DiscoveryItem] = []
        let userId = currentUserId

        // Convert signals to flex missions
        let myFlexMissions = mySignals.map { Mission.fromSignal($0) }
        let discoverFlexMissions = discoverSignals.map { Mission.fromSignal($0) }
        let rsvpFlexMissions = rsvpSignals.map { Mission.fromSignal($0) }

        // 1. Hosted + Joined set missions
        for mission in missions {
            if mission.creatorId == userId {
                result.append(.hostedMission(mission))
            } else if mission.userPodStatus == "in_pod" {
                result.append(.joinedMission(mission))
            }
        }

        // 2. Hosted flex missions (from mySignals)
        for mission in myFlexMissions {
            result.append(.hostedMission(mission))
        }

        // 3. Joined flex missions (from discover endpoint — have podId)
        let hostedFlexIds = Set(myFlexMissions.map { $0.id })
        for mission in discoverFlexMissions {
            guard !hostedFlexIds.contains(mission.id) else { continue }
            if mission.podId != nil {
                result.append(.joinedMission(mission))
            }
        }

        // 3b. RSVP'd flex missions (from /users/me/rsvps)
        let alreadyAddedFlexIds = Set(result.compactMap { item -> String? in
            switch item {
            case .hostedMission(let m), .joinedMission(let m):
                return m.isFlexMode ? m.id : nil
            default: return nil
            }
        })
        for mission in rsvpFlexMissions {
            if !alreadyAddedFlexIds.contains(mission.id) {
                result.append(.joinedMission(mission))
            }
        }

        // 4. AI-recommended missions (process BEFORE discoverables so they get priority)
        recommendedItems = []
        for mission in suggested {
            let alreadyAdded = result.contains { item in
                switch item {
                case .hostedMission(let m), .joinedMission(let m): return m.id == mission.id
                default: return false
                }
            }
            if !alreadyAdded {
                let item = DiscoveryItem.recommendedMission(mission)
                result.append(item)
                recommendedItems.append(item)
            }
        }

        // 4b. Client-side fallback recommendations (when backend returns none)
        if recommendedItems.isEmpty && !userInterests.isEmpty {
            let candidateMissions = missions.filter { mission in
                mission.creatorId != userId
                    && mission.userPodStatus != "in_pod"
                    && !result.contains { item in
                        switch item {
                        case .hostedMission(let m), .joinedMission(let m): return m.id == mission.id
                        default: return false
                        }
                    }
            }

            let scored = candidateMissions.map { mission -> (Mission, Int) in
                let matchCount = mission.tags.filter { tag in
                    userInterests.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
                }.count
                return (mission, matchCount)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

            for (mission, _) in scored.prefix(5) {
                var m = mission
                let matched = m.tags.filter { tag in
                    userInterests.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
                }
                m.suggestionReason = "Matches your interests: \(matched.joined(separator: ", "))"
                let item = DiscoveryItem.recommendedMission(m)
                result.append(item)
                recommendedItems.append(item)
            }
        }

        // 5. Discoverable set missions (not hosted, not joined, not AI-recommended)
        let addedMissionIds = Set(result.compactMap { item -> String? in
            switch item {
            case .hostedMission(let m), .joinedMission(let m), .recommendedMission(let m):
                return m.id
            default: return nil
            }
        })
        for mission in missions {
            if mission.creatorId != userId
                && mission.userPodStatus != "in_pod"
                && !addedMissionIds.contains(mission.id) {
                result.append(.discoverableMission(mission))
            }
        }

        // 6. Discoverable flex missions (not hosted, not RSVP'd)
        for mission in discoverFlexMissions {
            guard !hostedFlexIds.contains(mission.id) else { continue }
            if mission.podId == nil && !addedMissionIds.contains(mission.id) {
                result.append(.discoverableMission(mission))
            }
        }

        items = result
    }

    // MARK: - Template Generation

    private func generateTemplates(maxCount: Int) -> [DiscoveryItem] {
        let templateMap: [String: (title: String, tags: [String])] = [
            "Hiking":       ("Hiking Meetup",       ["Hiking", "Outdoors"]),
            "Gaming":       ("Gaming Session",      ["Gaming", "Social"]),
            "Movies":       ("Movie Night",         ["Movies", "Social"]),
            "Music":        ("Music Jam",           ["Music", "Hangout"]),
            "Cooking":      ("Cook Together",       ["Cooking", "Food"]),
            "Sports":       ("Sports Pickup Game",  ["Sports", "Fitness"]),
            "Fitness":      ("Workout Buddy",       ["Fitness", "Sports"]),
            "Coffee":       ("Coffee Chat",         ["Coffee", "Social"]),
            "Art":          ("Art Session",         ["Art", "Creative"]),
            "Tech":         ("Tech Meetup",         ["Tech", "Learning"]),
            "Photography":  ("Photo Walk",          ["Photography", "Outdoors"]),
            "Travel":       ("Day Trip",            ["Travel", "Adventure"]),
            "Board Games":  ("Board Game Night",    ["Board Games", "Social"]),
            "Reading":      ("Book Club Meetup",    ["Reading", "Social"]),
            "Dancing":      ("Dance Session",       ["Dancing", "Fitness"]),
            "Yoga":         ("Yoga Group",          ["Yoga", "Fitness"]),
            "Camping":      ("Camping Trip",        ["Camping", "Outdoors"]),
            "Concerts":     ("Concert Outing",      ["Concerts", "Music"]),
            "Comedy":       ("Comedy Night",        ["Comedy", "Social"]),
            "Food":         ("Food Crawl",          ["Food", "Social"]),
            "Study":        ("Study Group",         ["Study", "Academic"]),
        ]

        var templates: [DiscoveryItem] = []
        for interest in userInterests.prefix(maxCount) {
            if let entry = templateMap[interest] {
                templates.append(.template(TemplateItem(
                    title: entry.title,
                    interest: interest,
                    suggestedTags: entry.tags
                )))
            } else {
                templates.append(.template(TemplateItem(
                    title: "\(interest) Meetup",
                    interest: interest,
                    suggestedTags: [interest]
                )))
            }
        }
        return templates
    }

    // MARK: - Bell Timer

    func startBellTimer() {
        bellTimerTask?.cancel()
        bellTimerTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if !recommendedItems.isEmpty {
                withAnimation(.spring(duration: 0.4)) {
                    showRecommendationBadge = true
                }
            }
        }
    }
}
