//
//  VibeCheckView.swift
//  Orbit
//
//  Vibe Check quiz UI — 22 questions (scenario + 1–7 rating).
//  Space-themed dark background with star dots.
//  Shows MBTI result after final question before advancing.
//

import SwiftUI

// MARK: - Main Vibe Check View
struct VibeCheckView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var currentQuestion = 0
    @State private var showMBTIResult = false
    @State private var slideDirection: Edge = .trailing

    private let questions = ProfileViewModel.quizQuestions

    var body: some View {
        ZStack {
            // Space background
            spaceBackground

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Question counter
                Text("Question \(currentQuestion + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)

                if showMBTIResult {
                    mbtiResultView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    // Question content
                    questionView
                        .id(currentQuestion) // force re-render on change
                        .transition(.asymmetric(
                            insertion: .move(edge: slideDirection),
                            removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
                        ))
                }

                Spacer()

                // Back button
                if currentQuestion > 0 && !showMBTIResult {
                    Button {
                        slideDirection = .leading
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestion -= 1
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Space Background

    private var spaceBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.02, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.25),
                    Color(red: 0.05, green: 0.02, blue: 0.15),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Star dots
            ForEach(0..<40, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.2...0.7)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat(((i * 37 + 13) % 390)),
                        y: CGFloat(((i * 53 + 7) % 800))
                    )
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
    }

    private var progress: CGFloat {
        if showMBTIResult { return 1.0 }
        return CGFloat(currentQuestion + 1) / CGFloat(questions.count)
    }

    // MARK: - Question View

    private var questionView: some View {
        let question = questions[currentQuestion]

        return ScrollView {
            VStack(spacing: 24) {
                // Question text
                Text(question.text)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                if question.type == .scenario {
                    scenarioOptions(for: question)
                } else {
                    ratingScale(for: question)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Scenario Options

    private func scenarioOptions(for question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                let isSelected = viewModel.quizAnswers[question.id]?.selectedOptionIndex == index

                Button {
                    // Select the answer
                    viewModel.quizAnswers[question.id] = QuizAnswer(selectedOptionIndex: index, ratingValue: nil)

                    // Auto-advance after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        advanceToNext()
                    }
                } label: {
                    Text(option.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ?
                                    Color.purple.opacity(0.4) :
                                    Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ?
                                    Color.purple :
                                    Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Rating Scale (1–7)

    private func ratingScale(for question: QuizQuestion) -> some View {
        VStack(spacing: 20) {
            // Scale labels
            HStack {
                Text("Strongly\nDisagree")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                Spacer()
                Text("Neutral")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("Strongly\nAgree")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            // 7 circles
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { value in
                    let isSelected = viewModel.quizAnswers[question.id]?.ratingValue == value
                    let size: CGFloat = isSelected ? 44 : 36

                    Button {
                        viewModel.quizAnswers[question.id] = QuizAnswer(selectedOptionIndex: nil, ratingValue: value)

                        // Auto-advance after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            advanceToNext()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ?
                                    ratingColor(for: value) :
                                    Color.white.opacity(0.1))
                                .frame(width: size, height: size)

                            Circle()
                                .stroke(isSelected ?
                                    ratingColor(for: value) :
                                    Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1)
                                .frame(width: size, height: size)

                            Text("\(value)")
                                .font(.subheadline.bold())
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        }
                    }
                    .animation(.spring(response: 0.3), value: isSelected)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func ratingColor(for value: Int) -> Color {
        switch value {
        case 1, 2: return .red.opacity(0.7)
        case 3: return .orange.opacity(0.7)
        case 4: return .gray.opacity(0.5)
        case 5: return .cyan.opacity(0.7)
        case 6, 7: return .purple.opacity(0.8)
        default: return .gray
        }
    }

    // MARK: - MBTI Result View

    private var mbtiResultView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Based on your answers, you're an")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))

            Text(viewModel.derivedMBTI)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(mbtiDescription(for: viewModel.derivedMBTI))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Navigation

    private func advanceToNext() {
        if currentQuestion < questions.count - 1 {
            slideDirection = .trailing
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestion += 1
            }
        } else {
            // Last question answered — compute and show MBTI
            viewModel.computeVibeCheck()
            withAnimation(.easeInOut(duration: 0.5)) {
                showMBTIResult = true
            }
        }
    }

    // MARK: - MBTI Descriptions

    private func mbtiDescription(for type: String) -> String {
        let descriptions: [String: String] = [
            "ISTJ": "The Inspector — Reliable, thorough, and dependable",
            "ISFJ": "The Protector — Warm, caring, and detail-oriented",
            "INFJ": "The Advocate — Insightful, principled, and compassionate",
            "INTJ": "The Architect — Strategic, independent, and determined",
            "ISTP": "The Craftsman — Practical, observant, and analytical",
            "ISFP": "The Composer — Gentle, sensitive, and creative",
            "INFP": "The Mediator — Idealistic, empathetic, and imaginative",
            "INTP": "The Thinker — Logical, innovative, and curious",
            "ESTP": "The Dynamo — Energetic, pragmatic, and spontaneous",
            "ESFP": "The Performer — Fun-loving, generous, and sociable",
            "ENFP": "The Champion — Enthusiastic, creative, and free-spirited",
            "ENTP": "The Visionary — Clever, resourceful, and quick-witted",
            "ESTJ": "The Supervisor — Organized, dedicated, and outspoken",
            "ESFJ": "The Provider — Caring, sociable, and traditional",
            "ENFJ": "The Teacher — Charismatic, empathetic, and inspiring",
            "ENTJ": "The Commander — Bold, strategic, and goal-driven",
        ]
        return descriptions[type] ?? "A unique personality blend!"
    }
}

#Preview {
    VibeCheckView(viewModel: ProfileViewModel())
}
