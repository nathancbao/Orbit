// EventSuggester.swift
// Suggests events to students based on their interests.
// Also provides sample events so we have data to work with.

import Foundation

class EventSuggester {

    // Our catalog of available events
    private var events: [Event] = []

    // MARK: - Setup

    init() {
        // Populate with sample events on creation
        loadSampleEvents()
    }

    // MARK: - Suggest Events for a Student

    /// Returns events that match any of the student's interests.
    /// Results are sorted so direct interest matches come first.
    func suggestEvents(for student: Student) -> [Event] {
        // 'filter' keeps only events whose category is in the student's interests
        return events.filter { event in
            student.interests.contains(event.category)
        }
    }

    /// Returns the top N suggested events for a student.
    func suggestTopEvents(for student: Student, count: Int = 3) -> [Event] {
        return Array(suggestEvents(for: student).prefix(count))
    }

    // MARK: - Suggest Events for a Group

    /// Suggests events that match the group's shared interest.
    func suggestEvents(for group: Group) -> [Event] {
        return events.filter { $0.category == group.sharedInterest }
    }

    // MARK: - Add Custom Events

    func addEvent(_ event: Event) {
        events.append(event)
    }

    /// Returns all available events so other systems (like MLEventRecommender)
    /// can score the full catalog.
    func getAllEvents() -> [Event] {
        return events
    }

    // MARK: - Sample Data

    /// Creates a set of sample events across all interest categories.
    /// In a real app, these would come from a database or API.
    private func loadSampleEvents() {

        // Helper to create a date N days from now
        func futureDate(daysFromNow days: Int) -> Date {
            return Calendar.current.date(
                byAdding: .day,
                value: days,
                to: Date()
            ) ?? Date()
        }

        events = [
            // Programming events
            Event(name: "Hackathon 2025",
                  description: "24-hour coding competition. Build anything!",
                  category: .programming,
                  date: futureDate(daysFromNow: 14)),
            Event(name: "Swift Workshop",
                  description: "Learn iOS development from scratch.",
                  category: .programming,
                  date: futureDate(daysFromNow: 7)),

            // Art events
            Event(name: "Figure Drawing Night",
                  description: "Open studio with live models.",
                  category: .art,
                  date: futureDate(daysFromNow: 3)),
            Event(name: "Digital Art Showcase",
                  description: "Student gallery featuring digital works.",
                  category: .art,
                  date: futureDate(daysFromNow: 21)),

            // Music events
            Event(name: "Open Mic Night",
                  description: "Perform or just come enjoy live music.",
                  category: .music,
                  date: futureDate(daysFromNow: 5)),
            Event(name: "Music Production Workshop",
                  description: "Learn to make beats with GarageBand.",
                  category: .music,
                  date: futureDate(daysFromNow: 10)),

            // Sports events
            Event(name: "Intramural Basketball Signup",
                  description: "Join a casual basketball league.",
                  category: .sports,
                  date: futureDate(daysFromNow: 2)),
            Event(name: "Yoga in the Park",
                  description: "Beginner-friendly outdoor yoga session.",
                  category: .sports,
                  date: futureDate(daysFromNow: 4)),

            // Gaming events
            Event(name: "Game Jam Weekend",
                  description: "Design and build a game in 48 hours.",
                  category: .gaming,
                  date: futureDate(daysFromNow: 20)),
            Event(name: "Smash Tournament",
                  description: "Super Smash Bros. campus championship.",
                  category: .gaming,
                  date: futureDate(daysFromNow: 8)),

            // Reading events
            Event(name: "Book Club: Sci-Fi Month",
                  description: "This month: Dune by Frank Herbert.",
                  category: .reading,
                  date: futureDate(daysFromNow: 6)),

            // Cooking events
            Event(name: "Cooking Class: Pasta Night",
                  description: "Learn to make fresh pasta from scratch.",
                  category: .cooking,
                  date: futureDate(daysFromNow: 9)),

            // Photography events
            Event(name: "Golden Hour Photo Walk",
                  description: "Campus photo walk during sunset.",
                  category: .photography,
                  date: futureDate(daysFromNow: 3)),

            // Science events
            Event(name: "Astronomy Night",
                  description: "Telescope viewing on the science building roof.",
                  category: .science,
                  date: futureDate(daysFromNow: 11)),

            // Film events
            Event(name: "Student Film Festival",
                  description: "Watch and vote on student-made short films.",
                  category: .film,
                  date: futureDate(daysFromNow: 15)),
        ]
    }
}
