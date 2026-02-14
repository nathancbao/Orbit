//
//  LobbyView.swift
//  Orbit
//
//  Waiting room while signal is accepted but not all members have confirmed.
//  Shows member list with accepted/pending status and pulsing animation.
//

import SwiftUI

struct LobbyView: View {
    let signal: Signal
    let members: [PodMember]
    let onRefresh: () -> Void

    @State private var pulseAnimation = false

    private var totalMembers: Int {
        signal.targetUserIds.count
    }

    private var acceptedCount: Int {
        signal.acceptedUserIds.count
    }

    var body: some View {
        ZStack {
            // Space background
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Pulsing waiting indicator
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.5)

                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.2 : 0.7)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        pulseAnimation = true
                    }
                }

                // Title
                VStack(spacing: 8) {
                    Text("Waiting for Others...")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("\(acceptedCount) of \(totalMembers) accepted")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(acceptedCount) / CGFloat(max(totalMembers, 1)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)

                // Member list
                VStack(spacing: 12) {
                    ForEach(members) { member in
                        let isAccepted = signal.acceptedUserIds.contains(member.userId)

                        HStack(spacing: 12) {
                            Circle()
                                .fill(memberColor(for: member.name))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(member.interests.prefix(2).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Status icon
                            Image(systemName: isAccepted ? "checkmark.circle.fill" : "clock")
                                .font(.title3)
                                .foregroundColor(isAccepted ? .green : .white.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                // Expiry note
                if let expiresAt = signal.expiresAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Signal expires in \(timeRemaining(from: expiresAt))")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Refresh button
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 16)

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func memberColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .cyan, .indigo, .mint]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
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
    LobbyView(
        signal: Signal(
            id: "preview-signal",
            creatorId: 0,
            targetUserIds: [0, 1, 2, 3],
            acceptedUserIds: [0, 1],
            createdAt: nil,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)),
            status: "pending"
        ),
        members: [
            PodMember(userId: 1, name: "Alex", interests: ["Hiking", "Music"], contactInfo: nil),
            PodMember(userId: 2, name: "Jordan", interests: ["Music", "Cooking"], contactInfo: nil),
            PodMember(userId: 3, name: "Sam", interests: ["Cooking", "Art"], contactInfo: nil),
        ],
        onRefresh: {}
    )
}
