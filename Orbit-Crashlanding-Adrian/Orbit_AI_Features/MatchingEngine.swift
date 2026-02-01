// MatchingEngine.swift
// This is the core "AI" logic — it compares students and finds the best matches.
//
// The algorithm: Jaccard Similarity
//   score = (interests in common) / (total unique interests between both students)
//   Example: Student A likes [Programming, Art, Music]
//            Student B likes [Programming, Music, Gaming]
//            Shared = [Programming, Music] → 2
//            Total unique = [Programming, Art, Music, Gaming] → 4
//            Score = 2/4 = 0.5 (50% similar)

import Foundation

// 'class' is like struct but is a reference type (one shared copy, not a value copy).
// We use a class here because the engine manages state (the student list).
class MatchingEngine {

    // All registered students
    private var students: [Student] = []

    // MARK: - Add Students

    func addStudent(_ student: Student) {
        students.append(student)
    }

    func addStudents(_ newStudents: [Student]) {
        students.append(contentsOf: newStudents)
    }

    // MARK: - Find Matches for One Student

    /// Returns all other students ranked by similarity, best match first.
    /// - Parameters:
    ///   - student: The student to find matches for
    ///   - minScore: Only return matches above this threshold (0.0 to 1.0)
    /// - Returns: Array of MatchResult sorted by similarity (highest first)
    func findMatches(for student: Student, minScore: Double = 0.0) -> [MatchResult] {

        // 'compactMap' transforms each element and removes nil results.
        // 'filter' keeps only items that pass a condition.
        // 'sorted' orders the results.
        let results: [MatchResult] = students.compactMap { other in

            // Don't match a student with themselves
            guard other.id != student.id else { return nil }

            // 'intersection' gives us the interests both students share
            let shared = student.interests.intersection(other.interests)

            // Skip if they have nothing in common
            guard !shared.isEmpty else { return nil }

            return MatchResult(
                student: student,
                matchedWith: other,
                sharedInterests: shared
            )
        }
        .filter { $0.similarityScore >= minScore }
        .sorted { $0.similarityScore > $1.similarityScore }

        return results
    }

    // MARK: - Find Top Match

    /// Returns the single best match for a student, or nil if none found.
    func findTopMatch(for student: Student) -> MatchResult? {
        return findMatches(for: student).first
    }

    // MARK: - Find Mutual Matches

    /// Finds pairs where both students are each other's top match.
    /// Think of it like a "mutual best friend" finder.
    func findMutualMatches() -> [(MatchResult, MatchResult)] {
        var mutualPairs: [(MatchResult, MatchResult)] = []
        var alreadyPaired: Set<UUID> = []

        for student in students {
            // Skip if this student is already in a mutual pair
            guard !alreadyPaired.contains(student.id) else { continue }

            // Find this student's top match
            guard let topMatch = findTopMatch(for: student) else { continue }

            // Check if the top match's top match is the original student
            guard let reverseMatch = findTopMatch(for: topMatch.matchedWith),
                  reverseMatch.matchedWith.id == student.id else { continue }

            // It's mutual! Record the pair
            mutualPairs.append((topMatch, reverseMatch))
            alreadyPaired.insert(student.id)
            alreadyPaired.insert(topMatch.matchedWith.id)
        }

        return mutualPairs
    }

    // MARK: - Get All Students

    func getAllStudents() -> [Student] {
        return students
    }
}
