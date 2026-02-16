//
//  MatchingService.swift
//  Orbit
//
//  Client-side matching using a weighted blend of:
//    - Interest similarity (Jaccard, 70% weight)
//    - Personality similarity (vibe check dimensions, 30% weight)
//
//  When vibe check data is missing for either user, falls back
//  to 100% interest matching.
//

import Foundation

class MatchingService {
    static let shared = MatchingService()
    private init() {}

    /// Weights for the blended score
    private let interestWeight = 0.7
    private let personalityWeight = 0.3

    /// Computes the Jaccard similarity between two profiles' interest sets.
    /// Returns a value from 0.0 (no overlap) to 1.0 (identical interests).
    func interestScore(between a: Profile, and b: Profile) -> Double {
        let setA = Set(a.interests)
        let setB = Set(b.interests)
        let union = setA.union(setB)
        guard !union.isEmpty else { return 0.0 }
        return Double(setA.intersection(setB).count) / Double(union.count)
    }

    /// Computes similarity between two vibe check profiles across all 8 dimensions.
    /// Uses 1 - average absolute difference, so identical = 1.0, opposite = 0.0.
    func personalityScore(between a: VibeCheck, and b: VibeCheck) -> Double {
        let dimensions: [(Double, Double)] = [
            (a.introvertExtrovert, b.introvertExtrovert),
            (a.spontaneousPlanner, b.spontaneousPlanner),
            (a.activeRelaxed, b.activeRelaxed),
            (a.adventurousCautious, b.adventurousCautious),
            (a.expressiveReserved, b.expressiveReserved),
            (a.independentCollaborative, b.independentCollaborative),
            (a.sensingIntuition, b.sensingIntuition),
            (a.thinkingFeeling, b.thinkingFeeling),
        ]
        let avgDiff = dimensions.reduce(0.0) { $0 + abs($1.0 - $1.1) } / Double(dimensions.count)
        return 1.0 - avgDiff
    }

    /// Blended match score: 70% interests + 30% personality.
    /// Falls back to 100% interests if either profile lacks vibe check data.
    func computeMatchScore(between a: Profile, and b: Profile) -> Double {
        let interests = interestScore(between: a, and: b)

        guard let vcA = a.vibeCheck, let vcB = b.vibeCheck else {
            // No vibe check data — interest-only matching
            return interests
        }

        let personality = personalityScore(between: vcA, and: vcB)
        return interests * interestWeight + personality * personalityWeight
    }

    /// Ranks a list of profiles by match score against a reference profile.
    /// Sets `matchScore` on each profile and returns them sorted best-first.
    /// Profiles that already have a `matchScore` (e.g., from the backend) are
    /// left as-is unless `forceRecompute` is true.
    func rankProfiles(_ profiles: [Profile], against reference: Profile, forceRecompute: Bool = false) -> [Profile] {
        var scored = profiles.map { profile -> Profile in
            var p = profile
            if p.matchScore == nil || forceRecompute {
                p.matchScore = computeMatchScore(between: reference, and: p)
            }
            return p
        }
        scored.sort { ($0.matchScore ?? 0) > ($1.matchScore ?? 0) }
        return scored
    }
}
