import SwiftUI

struct ProfileDisplayView: View {
    let profile: Profile
    let photos: [UIImage]
    var onEdit: (() -> Void)? = nil
    var onTakeVibeCheck: (() -> Void)? = nil

    @State private var currentPhotoIndex = 0

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if let onEdit = onEdit {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Edit", action: onEdit)
                        }
                    }
                }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Large photo carousel (Tinder-style)
                photoCarousel

                // Profile info below photos
                VStack(spacing: 20) {
                    // Name, age, location header
                    nameHeader
                        .padding(.top, 20)

                    // Vibe Check banner (shown when quiz not completed)
                    if profile.vibeCheck == nil, let onTakeVibeCheck = onTakeVibeCheck {
                        vibeCheckBanner(action: onTakeVibeCheck)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Bio
                    if !profile.bio.isEmpty {
                        bioSection
                        Divider()
                            .padding(.horizontal)
                    }

                    // Interests
                    interestsSection

                    Divider()
                        .padding(.horizontal)

                    // Personality
                    personalitySection

                    Divider()
                        .padding(.horizontal)

                    // Social Preferences
                    socialPreferencesSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Photo Carousel (Tinder-style)
    private var photoCarousel: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Photo
                if photos.isEmpty {
                    // Placeholder when no photos
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            VStack(spacing: 16) {
                                Text(profile.name.prefix(1).uppercased())
                                    .font(.system(size: 100, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("No photos yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        )
                } else {
                    // Show current photo
                    Image(uiImage: photos[currentPhotoIndex])
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width)
                        .clipped()
                }

                // Gradient overlay at bottom for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Photo indicators (dots)
                if photos.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: index == currentPhotoIndex ? 24 : 8, height: 4)
                                .animation(.easeInOut(duration: 0.2), value: currentPhotoIndex)
                        }
                    }
                    .padding(.bottom, 12)
                }

                // Tap areas for photo navigation
                if photos.count > 1 {
                    HStack(spacing: 0) {
                        // Left tap area - previous photo
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    currentPhotoIndex = max(0, currentPhotoIndex - 1)
                                }
                            }

                        // Right tap area - next photo
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    currentPhotoIndex = min(photos.count - 1, currentPhotoIndex + 1)
                                }
                            }
                    }
                }
            }
        }
        .aspectRatio(1/1.2, contentMode: .fit) // Tinder-style aspect ratio
    }

    // MARK: - Name Header
    private var nameHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(profile.name)
                    .font(.system(size: 32, weight: .bold))

                Text("\(profile.age)")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                Text("\(profile.location.city), \(profile.location.state)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.subheadline)
        }
    }

    // MARK: - Bio Section
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "About Me", icon: "text.quote")

            Text(profile.bio)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Interests Section
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Interests", icon: "heart.fill")

            FlowLayout(spacing: 8) {
                ForEach(profile.interests, id: \.self) { interest in
                    Text(interest)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Personality Section
    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Personality", icon: "sparkles")

            PersonalityBar(
                leftLabel: "Introvert",
                rightLabel: "Extrovert",
                value: profile.personality.introvertExtrovert
            )

            PersonalityBar(
                leftLabel: "Spontaneous",
                rightLabel: "Planner",
                value: profile.personality.spontaneousPlanner
            )

            PersonalityBar(
                leftLabel: "Active",
                rightLabel: "Relaxed",
                value: profile.personality.activeRelaxed
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Social Preferences Section
    private var socialPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Social Preferences", icon: "person.3.fill")

            VStack(spacing: 12) {
                InfoRow(label: "Group Size", value: profile.socialPreferences.groupSize)
                InfoRow(label: "Hangout Frequency", value: profile.socialPreferences.meetingFrequency)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Times")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(profile.socialPreferences.preferredTimes, id: \.self) { time in
                        Text(time)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Vibe Check Banner
extension ProfileDisplayView {
    func vibeCheckBanner(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take the Vibe Check")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Unlock personality-based matching")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .padding(.top, 12)
    }
}

// MARK: - Supporting Views
struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct PersonalityBar: View {
    let leftLabel: String
    let rightLabel: String
    let value: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(leftLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(rightLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    // Filled portion
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * value, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileDisplayView(
            profile: Profile(
                name: "Alex Johnson",
                age: 25,
                location: Location(city: "San Francisco", state: "CA", coordinates: nil),
                bio: "Love hiking, coffee, and meeting new people! Always up for an adventure. Looking for friends who enjoy exploring the city and trying new restaurants.",
                photos: [],
                interests: ["Hiking", "Coffee", "Gaming", "Travel", "Photography"],
                personality: Personality(
                    introvertExtrovert: 0.7,
                    spontaneousPlanner: 0.4,
                    activeRelaxed: 0.6
                ),
                socialPreferences: SocialPreferences(
                    groupSize: "Small groups (3-5)",
                    meetingFrequency: "Weekly",
                    preferredTimes: ["Evenings", "Weekends"]
                ),
                friendshipGoals: []
            ),
            photos: []
        )
        .navigationTitle("Profile")
    }
}
