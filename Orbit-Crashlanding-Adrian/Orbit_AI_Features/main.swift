// main.swift
// Entry point — demonstrates matching, event suggestions, and group creation.
// On a Mac, run with: swift main.swift Models.swift MatchingEngine.swift EventSuggester.swift GroupManager.swift

import Foundation

// ============================================================
// 1. CREATE SAMPLE STUDENTS. Use real data later
// ============================================================
print("===== STUDENT INTEREST MATCHER =====\n")

let alice   = Student(name: "Alice",   interests: [.programming, .gaming, .music])
let bob     = Student(name: "Bob",     interests: [.programming, .science, .reading])
let charlie = Student(name: "Charlie", interests: [.art, .photography, .film])
let diana   = Student(name: "Diana",   interests: [.programming, .gaming, .art])
let ethan   = Student(name: "Ethan",   interests: [.sports, .cooking, .music])
let fiona   = Student(name: "Fiona",   interests: [.science, .reading, .programming])
let george  = Student(name: "George",  interests: [.gaming, .film, .music])
let hannah  = Student(name: "Hannah",  interests: [.photography, .art, .cooking])

let allStudents = [alice, bob, charlie, diana, ethan, fiona, george, hannah]

print("Registered \(allStudents.count) students:\n")
for student in allStudents {
    let interestList = student.interests.map { $0.rawValue }.joined(separator: ", ")
    print("  \(student.name): \(interestList)")
}

// ============================================================
// 2. MATCH STUDENTS
// ============================================================
print("\n===== MATCHING RESULTS =====\n")

let engine = MatchingEngine()
engine.addStudents(allStudents)

// Find matches for Alice example
let aliceMatches = engine.findMatches(for: alice, minScore: 0.1)
print("Matches for \(alice.name):")
for match in aliceMatches {
    let shared = match.sharedInterests.map { $0.rawValue }.joined(separator: ", ")
    let percent = Int(match.similarityScore * 100)
    print("  \(match.matchedWith.name) — \(percent)% similar (shared: \(shared))")
}

// Find Alice's top match
if let topMatch = engine.findTopMatch(for: alice) {
    print("\n  Best match: \(topMatch.matchedWith.name)!")
}

// Find mutual best matches across all students
print("\nMutual Best Matches (both students rank each other #1):")
let mutualMatches = engine.findMutualMatches()
if mutualMatches.isEmpty {
    print("  No mutual best matches found.")
} else {
    for (matchA, _) in mutualMatches {
        let shared = matchA.sharedInterests.map { $0.rawValue }.joined(separator: ", ")
        print("  \(matchA.student.name) <-> \(matchA.matchedWith.name) (shared: \(shared))")
    }
}

// ============================================================
// 3. SUGGEST EVENTS
// ============================================================
print("\n===== EVENT SUGGESTIONS =====\n")

let suggester = EventSuggester()

// Suggest events for Alice
let aliceEvents = suggester.suggestTopEvents(for: alice, count: 3)
print("Top events for \(alice.name):")
for event in aliceEvents {
    print("  [\(event.category.rawValue)] \(event.name) — \(event.description)")
}

// Suggest events for Charlie
let charlieEvents = suggester.suggestTopEvents(for: charlie, count: 3)
print("\nTop events for \(charlie.name):")
for event in charlieEvents {
    print("  [\(event.category.rawValue)] \(event.name) — \(event.description)")
}

// ============================================================
// 4. CREATE GROUPS
// ============================================================
print("\n===== AUTO-GENERATED GROUPS =====")

let groupManager = GroupManager(minimumGroupSize: 2)
let groups = groupManager.generateGroups(from: allStudents)

groupManager.printGroupSummary()

// Show which groups Alice belongs to
let aliceGroups = groupManager.findGroups(for: alice)
print("Groups \(alice.name) belongs to:")
for group in aliceGroups {
    print("  - \(group.name) (\(group.members.count) members)")
}

// Show group recommendations for Ethan
let ethanRecs = groupManager.recommendGroups(for: ethan)
if !ethanRecs.isEmpty {
    print("\nRecommended groups for \(ethan.name):")
    for group in ethanRecs {
        print("  - \(group.name) (\(group.members.count) members)")
    }
}

// ============================================================
// 5. ML-POWERED EVENT RECOMMENDATIONS
// ============================================================
print("\n===== ML-POWERED EVENT RECOMMENDATIONS =====\n")

let mlRecommender = MLEventRecommender()
let allEvents = suggester.getAllEvents()

// --- 5a: Show Alice's initial weights (before any feedback) ---
print("Alice's interest weights BEFORE feedback:")
if let initialWeights = mlRecommender.getWeights(for: alice) {
    for interest in Interest.allCases {
        let w = initialWeights[interest] ?? 0.0
        let bar = String(repeating: "█", count: Int(w * 10))
        print("  \(interest.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%.2f", w)) \(bar)")
    }
}

// --- 5b: Show initial ML-ranked events ---
let initialRecs = mlRecommender.recommendEvents(from: allEvents, for: alice, count: 5)
print("\nAlice's top 5 events BEFORE feedback:")
for (i, rec) in initialRecs.enumerated() {
    print("  \(i + 1). [\(rec.event.category.rawValue)] \(rec.event.name) — score: \(String(format: "%.2f", rec.score))")
}

// --- 5c: Alice gives feedback ---
print("\n--- Alice gives feedback ---")

// Alice likes a science event (she never declared science as an interest!)
let astronomyEvent = allEvents.first { $0.name == "Astronomy Night" }!
mlRecommender.recordFeedback(student: alice, event: astronomyEvent, feedback: .liked)
print("  ✓ Alice LIKED: Astronomy Night (Science)")

// Alice dislikes a gaming event (she declared gaming, but changed her mind)
let smashEvent = allEvents.first { $0.name == "Smash Tournament" }!
mlRecommender.recordFeedback(student: alice, event: smashEvent, feedback: .disliked)
print("  ✗ Alice DISLIKED: Smash Tournament (Gaming)")

// Alice likes a programming event (reinforces her declared interest)
let hackathonEvent = allEvents.first { $0.name == "Hackathon 2025" }!
mlRecommender.recordFeedback(student: alice, event: hackathonEvent, feedback: .liked)
print("  ✓ Alice LIKED: Hackathon 2025 (Programming)")

// --- 5d: Show updated weights ---
print("\nAlice's interest weights AFTER feedback:")
if let updatedWeights = mlRecommender.getWeights(for: alice) {
    for interest in Interest.allCases {
        let w = updatedWeights[interest] ?? 0.0
        let bar = String(repeating: "█", count: Int(w * 10))
        print("  \(interest.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%.2f", w)) \(bar)")
    }
}

// --- 5e: Show updated recommendations ---
let updatedRecs = mlRecommender.recommendEvents(from: allEvents, for: alice, count: 5)
print("\nAlice's top 5 events AFTER feedback:")
for (i, rec) in updatedRecs.enumerated() {
    print("  \(i + 1). [\(rec.event.category.rawValue)] \(rec.event.name) — score: \(String(format: "%.2f", rec.score))")
}

// --- 5f: Show feedback history ---
let aliceFeedbackHistory = mlRecommender.getFeedbackHistory(for: alice)
print("\nAlice's feedback history (\(aliceFeedbackHistory.count) entries):")
for record in aliceFeedbackHistory {
    print("  \(record.feedback.rawValue) — \(record.category.rawValue)")
}

// --- 5g: Contrast with Bob (no feedback yet) ---
let bobRecs = mlRecommender.recommendEvents(from: allEvents, for: bob, count: 5)
print("\nBob's top 5 events (no feedback yet — pure initial weights):")
for (i, rec) in bobRecs.enumerated() {
    print("  \(i + 1). [\(rec.event.category.rawValue)] \(rec.event.name) — score: \(String(format: "%.2f", rec.score))")
}

print("\n===== DONE =====")
