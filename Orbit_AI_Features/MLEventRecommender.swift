// MLEventRecommender.swift
// A machine learning-based event recommender that learns from student feedback.
//
// How it works (Online Gradient Descent):
//   Each student gets a "weight vector" — one weight per Interest category.
//   Declared interests start at 1.0, undeclared at 0.1.
//   When a student likes an event, we increase the weight for that category.
//   When they dislike one, we decrease it.
//   Events are scored by their category's weight and sorted best-first.
//
//   The update rule:
//     Like:    w += learningRate * (1.0 - w)   → pushes weight toward 1.0
//     Dislike: w -= learningRate * w            → pushes weight toward 0.0
//
//   This is a form of online stochastic gradient descent, where the "loss"
//   is the difference between the predicted preference (current weight)
//   and the observed signal (1.0 for like, 0.0 for dislike).

import Foundation

class MLEventRecommender {

    // MARK: - Properties

    // All feedback records (our "training data")
    private var feedbackHistory: [FeedbackRecord] = []

    // Per-student weight vectors: studentID → [Interest: weight]
    // This is the "model" — these weights are learned, not hardcoded.
    private var studentWeights: [UUID: [Interest: Double]] = [:]

    // Hyperparameters
    // 'learningRate' controls how fast the model adapts.
    // Too high = overreacts to single feedback. Too low = learns too slowly.
    private let learningRate: Double

    // Default weight for interests the student didn't declare.
    // A small positive value so undeclared interests can still be discovered.
    private let defaultWeight: Double

    // Weight for interests the student explicitly declared.
    private let declaredWeight: Double

    init(learningRate: Double = 0.2, defaultWeight: Double = 0.1, declaredWeight: Double = 1.0) {
        self.learningRate = learningRate
        self.defaultWeight = defaultWeight
        self.declaredWeight = declaredWeight
    }

    // MARK: - Initialize Weights

    /// Sets up the weight vector for a student if it doesn't exist yet.
    /// Declared interests get a high weight; everything else gets a low default.
    /// 'Interest.allCases' iterates over every case in the enum (enabled by CaseIterable).
    private func initializeWeights(for student: Student) {
        // Only initialize once per student
        guard studentWeights[student.id] == nil else { return }

        var weights: [Interest: Double] = [:]
        for interest in Interest.allCases {
            if student.interests.contains(interest) {
                weights[interest] = declaredWeight
            } else {
                weights[interest] = defaultWeight
            }
        }
        studentWeights[student.id] = weights
    }

    // MARK: - Record Feedback (Training Step)

    /// Records a student's like/dislike on an event and updates the model.
    /// This is the "training" step — each call teaches the model something new.
    ///
    /// - Returns: The feedback record that was created.
    @discardableResult
    func recordFeedback(student: Student, event: Event, feedback: Feedback) -> FeedbackRecord {

        // 1. Create and store the feedback record
        let record = FeedbackRecord(
            studentID: student.id,
            eventID: event.id,
            category: event.category,
            feedback: feedback
        )
        feedbackHistory.append(record)

        // 2. Ensure this student has a weight vector
        initializeWeights(for: student)

        // 3. Update weights based on the feedback (the ML step)
        updateWeights(for: student.id, category: event.category, feedback: feedback)

        return record
    }

    // MARK: - Update Weights (The ML Algorithm)

    /// Adjusts the weight for a single interest category based on feedback.
    /// This is online gradient descent:
    ///   - Like:    w += α * (1.0 - w)   moves weight toward 1.0
    ///   - Dislike: w -= α * w            moves weight toward 0.0
    /// where α is the learning rate.
    ///
    /// The update is proportional to how far the weight is from the target,
    /// so it naturally slows down as it converges — a key property of gradient descent.
    private func updateWeights(for studentID: UUID, category: Interest, feedback: Feedback) {
        guard var weights = studentWeights[studentID] else { return }

        let currentWeight = weights[category] ?? defaultWeight

        let newWeight: Double
        switch feedback {
        case .liked:
            // Move toward 1.0 — the further away, the bigger the step
            newWeight = currentWeight + learningRate * (1.0 - currentWeight)
        case .disliked:
            // Move toward 0.0 — the further away, the bigger the step
            newWeight = currentWeight - learningRate * currentWeight
        }

        // Clamp to [0.0, 1.0] to prevent impossible values
        weights[category] = max(0.0, min(1.0, newWeight))
        studentWeights[studentID] = weights
    }

    // MARK: - Score Events

    /// Scores every event based on the student's learned weight vector.
    /// Returns (event, score) pairs sorted by score descending (best first).
    func scoreEvents(_ events: [Event], for student: Student) -> [(event: Event, score: Double)] {
        initializeWeights(for: student)

        let weights = studentWeights[student.id]!

        return events
            .map { event in
                let score = weights[event.category] ?? defaultWeight
                return (event: event, score: score)
            }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Recommend Events

    /// Returns the top N events for a student, ranked by learned preferences.
    func recommendEvents(from events: [Event], for student: Student, count: Int = 5) -> [(event: Event, score: Double)] {
        let scored = scoreEvents(events, for: student)
        return Array(scored.prefix(count))
    }

    // MARK: - Diagnostics

    /// Returns the current weight vector for a student (useful for debugging/display).
    /// Returns nil if the student has no weights yet.
    func getWeights(for student: Student) -> [Interest: Double]? {
        initializeWeights(for: student)
        return studentWeights[student.id]
    }

    /// Returns all feedback records for a specific student.
    func getFeedbackHistory(for student: Student) -> [FeedbackRecord] {
        return feedbackHistory.filter { $0.studentID == student.id }
    }
}
