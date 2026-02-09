//
//  MatchingService.swift
//  Orbit
//
//  Client-side interest matching using Jaccard similarity.
//  Adapted from Orbit_AI_Features/MatchingEngine.swift to work
//  with the app's Profile model (interests as [String]).
//
//  Jaccard Similarity:
//    score = |A ∩ B| / |A ∪ B|
//    Example: User A interests = ["Hiking", "Coffee", "Gaming"]
//             User B interests = ["Hiking", "Gaming", "Music"]
//             Shared = ["Hiking", "Gaming"] → 2
//             Total  = ["Hiking", "Coffee", "Gaming", "Music"] → 4
//             Score  = 2/4 = 0.5 (50% match)
//

import Foundation

class MatchingService {
    static let shared = MatchingService()
    private init() {}

    /// Computes the Jaccard similarity between two profiles' interest sets.
    /// Returns a value from 0.0 (no overlap) to 1.0 (identical interests).
    func computeMatchScore(between a: Profile, and b: Profile) -> Double {
        let setA = Set(a.interests)
        let setB = Set(b.interests)
        let union = setA.union(setB)
        guard !union.isEmpty else { return 0.0 }
        return Double(setA.intersection(setB).count) / Double(union.count)
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
