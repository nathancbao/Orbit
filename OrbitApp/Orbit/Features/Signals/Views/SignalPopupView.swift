//
//  SignalPopupView.swift
//  Orbit
//
//  Incoming signal card — shows matched members with accept/skip actions.
//  Space-themed with glowing animation.
//

import SwiftUI

struct SignalPopupView: View {
    let signal: Signal
    let members: [PodMember]
    let onAccept: () -> Void
    let onSkip: () -> Void

    @State private var isGlowing = false
    @State private var starPositions: [(CGPoint, CGFloat, Double)] = []

    var body: some View {
        ZStack {
            // Space background
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            // Star dots
            GeometryReader { geo in
                ForEach(0..<30, id: \.self) { i in
                    let pos = starPosition(index: i, in: geo.size)
                    Circle()
                        .fill(Color.white.opacity(pos.2))
                        .frame(width: pos.1, height: pos.1)
                        .position(pos.0)
                }
            }

            VStack(spacing: 28) {
                Spacer()

                // Signal icon with glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(isGlowing ? 1.3 : 1.0)
                        .opacity(isGlowing ? 0.6 : 1.0)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isGlowing = true
                    }
                }

                // Title
                VStack(spacing: 8) {
                    Text("Incoming Signal!")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("\(members.count) Matches Found")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Member avatars row
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(memberColor(for: member.name))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                )
                                .shadow(color: memberColor(for: member.name).opacity(0.5), radius: 6)

                            Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                // Shared interests
                if !sharedInterests.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Shared: \(sharedInterests.prefix(3).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Expiry countdown
                if let expiresAt = signal.expiresAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Expires in \(timeRemaining(from: expiresAt))")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Accept button
                Button(action: onAccept) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept Signal")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.4), radius: 12, y: 4)
                }

                // Skip option
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private var sharedInterests: [String] {
        guard members.count >= 2 else { return [] }
        var common = Set(members[0].interests)
        for member in members.dropFirst() {
            common = common.intersection(Set(member.interests))
        }
        return Array(common).sorted()
    }

    private func memberColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .cyan, .indigo, .mint]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func starPosition(index: Int, in size: CGSize) -> (CGPoint, CGFloat, Double) {
        let x = CGFloat((index * 73 + 29) % Int(max(size.width, 1)))
        let y = CGFloat((index * 97 + 13) % Int(max(size.height, 1)))
        let starSize = CGFloat(1 + (index % 3))
        let opacity = 0.3 + Double(index % 7) / 10.0
        return (CGPoint(x: x, y: y), starSize, opacity)
    }

    private func timeRemaining(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "7 days" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "expired" }
        let days = Int(remaining / 86400)
        let hours = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h"
    }
}

#Preview {
    SignalPopupView(
        signal: Signal(
            id: "preview-signal",
            creatorId: 0,
            targetUserIds: [0, 1, 2, 3],
            acceptedUserIds: [],
            createdAt: nil,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)),
            status: "pending"
        ),
        members: [
            PodMember(userId: 1, name: "Alex", interests: ["Hiking", "Music"], contactInfo: nil),
            PodMember(userId: 2, name: "Jordan", interests: ["Music", "Cooking"], contactInfo: nil),
            PodMember(userId: 3, name: "Sam", interests: ["Cooking", "Art"], contactInfo: nil),
        ],
        onAccept: {},
        onSkip: {}
    )
}
