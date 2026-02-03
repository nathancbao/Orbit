// GroupManager.swift
// Automatically creates and manages groups based on shared interests.
// Think of this like auto-generating clubs from what students care about.

import Foundation

class GroupManager {

    // All groups that have been created
    private var groups: [Group] = []

    // Minimum number of students needed to form a group
    private let minimumGroupSize: Int

    init(minimumGroupSize: Int = 2) {
        self.minimumGroupSize = minimumGroupSize
    }

    // MARK: - Auto-Create Groups from Students

    /// Scans all students and creates a group for each interest that
    /// has enough students. This is the main "AI grouping" function.
    ///
    /// Algorithm:
    /// 1. Build a dictionary mapping each Interest → [Students who have it]
    /// 2. For each interest with enough students, create a Group
    func generateGroups(from students: [Student]) -> [Group] {

        // Step 1: Build interest → students mapping
        // Dictionary(grouping:by:) is a powerful Swift feature.
        // But here we need a custom approach since students have MULTIPLE interests.

        var interestMap: [Interest: [Student]] = [:]

        for student in students {
            for interest in student.interests {
                // If the key doesn't exist yet, start with an empty array
                interestMap[interest, default: []].append(student)
            }
        }

        // Step 2: Create groups for interests with enough students
        var newGroups: [Group] = []

        for (interest, members) in interestMap {
            // Only create a group if we meet the minimum size
            guard members.count >= minimumGroupSize else { continue }

            let group = Group(
                name: "\(interest.rawValue) Enthusiasts",
                sharedInterest: interest,
                members: members
            )
            newGroups.append(group)
        }

        // Sort groups by member count (largest first) for nicer output
        newGroups.sort { $0.members.count > $1.members.count }

        // Store and return
        self.groups = newGroups
        return newGroups
    }

    // MARK: - Find Groups for a Student

    /// Returns all groups that a specific student belongs to.
    func findGroups(for student: Student) -> [Group] {
        return groups.filter { group in
            group.members.contains(where: { $0.id == student.id })
        }
    }

    // MARK: - Recommend Groups for a Student

    /// Suggests groups the student is NOT in yet, but matches their interests.
    /// Useful for "You might also like..." recommendations.
    func recommendGroups(for student: Student) -> [Group] {
        let currentGroups = findGroups(for: student)
        let currentGroupIDs = Set(currentGroups.map { $0.id })

        return groups.filter { group in
            // Not already a member
            !currentGroupIDs.contains(group.id)
            // But the interest matches
            && student.interests.contains(group.sharedInterest)
        }
    }

    // MARK: - Get All Groups

    func getAllGroups() -> [Group] {
        return groups
    }

    // MARK: - Group Summary

    /// Returns a readable summary of all groups (useful for debugging/display).
    func printGroupSummary() {
        if groups.isEmpty {
            print("No groups have been created yet.")
            return
        }

        print("\n===== GROUP SUMMARY =====")
        for group in groups {
            let memberNames = group.members.map { $0.name }.joined(separator: ", ")
            print("  [\(group.sharedInterest.rawValue)] \(group.name)")
            print("    Members (\(group.members.count)): \(memberNames)")
        }
        print("=========================\n")
    }
}
