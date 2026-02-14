//
//  DiscoverView.swift
//  Orbit
//
//  Space map showing your profile as a central planet
//  with other users as planets you can tap to view.
//

import SwiftUI

struct DiscoverView: View {
    let userProfile: Profile?
    @EnvironmentObject private var friendsViewModel: FriendsViewModel
    @State private var profiles: [Profile] = []
    @State private var isLoading: Bool = true
    @State private var selectedProfile: Profile? = nil
    @State private var stars: [Star] = []
    @State private var planetPositions: [String: CGPoint] = [:] // Cache positions by name
    @State private var showSignalSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                // Space background
                spaceBackground

                if isLoading {
                    ProgressView("Scanning the cosmos...")
                        .foregroundColor(.white)
                } else {
                    // Space map with planets
                    spaceMap
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSignalSheet = true
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showSignalSheet) {
                NavigationView {
                    SignalView()
                        .navigationTitle("Signals")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showSignalSheet = false }
                            }
                        }
                }
            }
            .sheet(item: $selectedProfile) { profile in
                ProfileDetailSheet(profile: profile)
                    .environmentObject(friendsViewModel)
            }
        }
        .task {
            await loadProfiles()
        }
    }

    // MARK: - Space Background

    private var spaceBackground: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep space gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Stars
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(star.position)
                        .blur(radius: star.size > 2 ? 0.5 : 0)
                }
            }
            .onAppear {
                if stars.isEmpty {
                    generateStars(in: geometry.size)
                }
            }
        }
    }

    // MARK: - Space Map

    private var spaceMap: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Orbit rings (decorative)
                ForEach(1..<4) { ring in
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(
                            width: CGFloat(ring) * min(geometry.size.width, geometry.size.height) * 0.3,
                            height: CGFloat(ring) * min(geometry.size.width, geometry.size.height) * 0.3
                        )
                        .position(center)
                }

                // Other user planets — size scales with match score
                ForEach(Array(profiles.enumerated()), id: \.element.name) { index, profile in
                    let score = profile.matchScore ?? 0
                    let planetSize: CGFloat = 60 + CGFloat(score) * 30 // 60–90 based on match
                    UserPlanet(profile: profile, size: planetSize)
                        .position(getOrCreatePosition(for: profile, index: index, total: profiles.count, center: center, radius: min(geometry.size.width, geometry.size.height) * 0.35))
                        .onTapGesture {
                            selectedProfile = profile
                        }
                }

                // Your planet (center)
                YourPlanet(size: 90)
                    .position(center)
            }
        }
    }

    // Get cached position or create one
    private func getOrCreatePosition(for profile: Profile, index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        if let cached = planetPositions[profile.name] {
            return cached
        }
        let position = calculatePlanetPosition(index: index, total: total, center: center, radius: radius)
        DispatchQueue.main.async {
            planetPositions[profile.name] = position
        }
        return position
    }

    // MARK: - Helpers

    private func generateStars(in size: CGSize) {
        stars = (0..<100).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0)
            )
        }
    }

    private func calculatePlanetPosition(index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (2.0 * Double.pi / Double(total)) * Double(index) - Double.pi / 2.0
        // Use deterministic "jitter" based on index instead of random
        let jitterX = Double((index * 17) % 40) - 20.0
        let jitterY = Double((index * 23) % 40) - 20.0
        let radiusOffset = Double((index * 31) % 60) - 30.0
        let radiusVariation = Double(radius) + radiusOffset

        return CGPoint(
            x: center.x + CGFloat(Foundation.cos(angle) * radiusVariation + jitterX),
            y: center.y + CGFloat(Foundation.sin(angle) * radiusVariation + jitterY)
        )
    }

    private func loadProfiles() async {
        do {
            var loaded = try await DiscoverService.shared.getDiscoverProfiles()
            // If we have the user's profile, compute match scores client-side
            // for any profiles that don't already have one from the backend
            if let user = userProfile {
                loaded = MatchingService.shared.rankProfiles(loaded, against: user)
            }
            profiles = loaded
        } catch {
            print("Failed to load profiles: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Star Model

struct Star: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}

// MARK: - Your Planet (Center)

struct YourPlanet: View {
    let size: CGFloat
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.5 : 0.8)

            // Planet
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.7), Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: size * 0.3, height: size * 0.3)
                        .offset(x: -size * 0.2, y: -size * 0.2)
                )
                .shadow(color: .blue.opacity(0.5), radius: 10)

            // Label
            Text("YOU")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .offset(y: size * 0.7)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - User Planet

struct UserPlanet: View {
    let profile: Profile
    let size: CGFloat
    @State private var isAnimating = false

    // Generate consistent color based on name
    private var planetColor: Color {
        let colors: [Color] = [.orange, .pink, .green, .yellow, .red, .mint, .cyan, .indigo]
        let index = abs(profile.name.hashValue) % colors.count
        return colors[index]
    }

    // Consistent animation duration based on name
    private var animationDuration: Double {
        return 2.0 + Double(abs(profile.name.hashValue) % 100) / 100.0
    }

    // Consistent animation delay based on name
    private var animationDelay: Double {
        return Double(abs(profile.name.hashValue) % 50) / 50.0
    }

    // Badge color based on match strength
    private func matchBadgeColor(score: Double) -> Color {
        if score >= 0.5 { return .green }
        if score >= 0.25 { return .orange }
        return .gray
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Subtle glow
                Circle()
                    .fill(planetColor.opacity(0.3))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: 8)

                // Planet body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [planetColor, planetColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        // Shine
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: size * 0.25, height: size * 0.25)
                            .offset(x: -size * 0.15, y: -size * 0.15)
                    )
                    .overlay(
                        // Initial
                        Text(profile.name.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    )
                    .shadow(color: planetColor.opacity(0.5), radius: 5)
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)

            // Match score badge
            if let score = profile.matchScore, score > 0 {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(matchBadgeColor(score: score))
                    .cornerRadius(6)
                    .offset(x: size * 0.35, y: -size * 0.35)
            }

            // Name label
            Text(profile.name.split(separator: " ").first ?? "")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
                .delay(animationDelay)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Profile Detail Sheet

struct ProfileDetailSheet: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var friendsViewModel: FriendsViewModel
    @State private var currentPhotoIndex = 0
    @State private var requestStatus: FriendRequestStatus?
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 300)
        .overlay(
            Text(profile.name.prefix(1).uppercased())
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with gradient
                    profileHeader

                    // Profile details
                    VStack(spacing: 20) {
                        // Match score
                        if let score = profile.matchScore, score > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Int(score * 100))% Match")
                                        .font(.headline)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(.systemGray5))
                                                .frame(height: 6)
                                            Capsule()
                                                .fill(score >= 0.5 ? Color.green : score >= 0.25 ? Color.orange : Color.gray)
                                                .frame(width: geo.size.width * score, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            Divider()
                        }

                        // Bio
                        if !profile.bio.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("About", systemImage: "text.quote")
                                    .font(.headline)
                                Text(profile.bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()

                        // Interests
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Interests", systemImage: "heart.fill")
                                .font(.headline)

                            FlowLayout(spacing: 8) {
                                ForEach(profile.interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // Social preferences
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Social Style", systemImage: "person.2.fill")
                                .font(.headline)

                            HStack {
                                InfoChip(label: profile.socialPreferences.groupSize, icon: "person.3")
                                InfoChip(label: profile.socialPreferences.meetingFrequency, icon: "calendar")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 40)

                        // Connect button
                        connectButton
                    }
                    .padding()
                }
            }
            .navigationTitle(profile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                requestStatus = FriendService.shared.getRequestStatus(for: profile)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if let status = requestStatus {
            switch status {
            case .pending:
                Label("Request Pending", systemImage: "clock")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
            case .accepted:
                Label("Already Friends", systemImage: "checkmark.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
            case .denied:
                sendRequestButton
            }
        } else {
            sendRequestButton
        }
    }

    private var sendRequestButton: some View {
        Button(action: {
            Task {
                isSending = true
                let success = await friendsViewModel.sendFriendRequest(to: profile)
                if success {
                    requestStatus = .pending
                } else {
                    errorMessage = friendsViewModel.errorMessage ?? "Failed to send request"
                    showError = true
                }
                isSending = false
            }
        }) {
            if isSending {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            } else {
                Label("Connect", systemImage: "link")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .disabled(isSending)
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            // Photo or gradient background
            if let firstPhotoURL = profile.photos.first, let url = URL(string: firstPhotoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                    case .failure(_):
                        placeholderGradient
                    case .empty:
                        placeholderGradient
                            .overlay(ProgressView())
                    @unknown default:
                        placeholderGradient
                    }
                }
            } else {
                placeholderGradient
            }

            // Info overlay at bottom
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.name)
                        .font(.title.bold())
                    Text("\(profile.age)")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                    Text("\(profile.location.city), \(profile.location.state)")
                }
                .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Info Chip

struct InfoChip: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DiscoverView(userProfile: nil)
}
