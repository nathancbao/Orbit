// Models.swift
// These are our data models — the "nouns" of our app.
// In Swift, 'struct' defines a value type (like a blueprint).
// 'enum' defines a fixed set of options.

import Foundation

// MARK: - Interest
// An enum lists every possible interest a student can have.
// 'CaseIterable' lets us loop over all cases later.
// 'String' means each case has a raw string value (its name).
enum Interest: String, CaseIterable {
    case programming    = "Programming"
    case art            = "Art"
    case music          = "Music"
    case sports         = "Sports"
    case gaming         = "Gaming"
    case reading        = "Reading"
    case cooking        = "Cooking"
    case photography    = "Photography"
    case science        = "Science"
    case film           = "Film"
}

// MARK: - Feedback
// Represents a student's reaction to a suggested event.
// This is the input signal that our ML model learns from.
enum Feedback: String {
    case liked    = "Liked"
    case disliked = "Disliked"
}

// MARK: - FeedbackRecord
// Stores one piece of feedback: which student reacted to which event, and how.
// We store 'category' directly so the ML model can update weights without
// needing to look up the full event every time (this is called denormalization).
struct FeedbackRecord: Identifiable {
    let id: UUID
    let studentID: UUID
    let eventID: UUID
    let category: Interest      // the event's interest category
    let feedback: Feedback
    let timestamp: Date

    init(studentID: UUID, eventID: UUID, category: Interest, feedback: Feedback) {
        self.id = UUID()
        self.studentID = studentID
        self.eventID = eventID
        self.category = category
        self.feedback = feedback
        self.timestamp = Date()
    }
}

// MARK: - Student
// Each student has a unique id, a name, and a list of interests.
// 'Identifiable' means this type has an 'id' property (useful for SwiftUI later).
// 'Hashable' lets us put students in Sets and use them as dictionary keys.
struct Student: Identifiable, Hashable {
    let id: UUID            // UUID = universally unique identifier
    let name: String
    var interests: Set<Interest>  // Set = no duplicates, fast lookups

    // A convenience initializer so we don't have to type UUID() every time
    init(name: String, interests: Set<Interest>) {
        self.id = UUID()
        self.name = name
        self.interests = interests
    }
}

// Make Interest conform to Hashable (needed for Set<Interest>).
// Enums with raw values get this automatically, but being explicit is good practice.
extension Interest: Hashable {}

// MARK: - Event
// An event has a name, description, a category (one Interest), and a date.
struct Event: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let category: Interest
    let date: Date

    init(name: String, description: String, category: Interest, date: Date) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.date = date
    }
}

// MARK: - Group
// A group is formed around a shared interest and contains members.
struct Group: Identifiable {
    let id: UUID
    let name: String
    let sharedInterest: Interest
    var members: [Student]

    init(name: String, sharedInterest: Interest, members: [Student] = []) {
        self.id = UUID()
        self.name = name
        self.sharedInterest = sharedInterest
        self.members = members
    }
}

// MARK: - MatchResult
// When we match two students, we store who was matched and how strong the match is.
struct MatchResult {
    let student: Student
    let matchedWith: Student
    let sharedInterests: Set<Interest>

    // A score from 0.0 to 1.0 representing how similar the two students are.
    // We calculate this as: shared interests / total unique interests between them.
    var similarityScore: Double {
        let totalUnique = student.interests.union(matchedWith.interests).count
        guard totalUnique > 0 else { return 0.0 }
        return Double(sharedInterests.count) / Double(totalUnique)
    }
}
