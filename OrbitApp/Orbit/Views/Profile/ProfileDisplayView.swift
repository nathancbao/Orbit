import SwiftUI

struct ProfileDisplayView: View {
    let profile: Profile
    var onEdit: (() -> Void)? = nil
    var onProfileUpdated: ((Profile) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack {
                    TopWavyLines().frame(height: 140)
                    Spacer()
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    BottomWavyLines().frame(height: 140)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // Avatar
                        ZStack {
                            if let photoURL = profile.photo, let url = URL(string: photoURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }
                        }
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        .padding(.top, 60)

                        // Name + year
                        VStack(spacing: 6) {
                            Text(profile.name)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                Text(Profile.displayYear(profile.collegeYear))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let email = profile.email {
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Trust score
                        if let score = profile.trustScore {
                            TrustScoreView(score: score)
                        }

                        Divider().padding(.horizontal, 32)

                        // Interests
                        if !profile.interests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("interests")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                    ForEach(profile.interests, id: \.self) { interest in
                                        Text(interest)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(OrbitTheme.blue.opacity(0.12))
                                            .foregroundColor(OrbitTheme.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }

                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(.systemGray3))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEdit = true
                    }
                    .foregroundStyle(OrbitTheme.gradient)
                }
            }
            .navigationDestination(isPresented: $showEdit) {
                QuickProfileSetupView(
                    onComplete: { updatedProfile, _ in
                        onProfileUpdated?(updatedProfile)
                        dismiss()
                    },
                    onCancel: { showEdit = false },
                    initialProfile: profile
                )
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    OrbitTheme.gradientFill
                )
                .frame(width: 110, height: 110)
            Text(String(profile.name.prefix(1)).uppercased())
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Trust Score View

struct TrustScoreView: View {
    let score: Double  // 0.0 – 5.0

    private var stars: Int { Int(score.rounded()) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < stars ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(
                            i < stars
                            ? AnyShapeStyle(OrbitTheme.gradient)
                            : AnyShapeStyle(Color(.systemGray4))
                        )
                }
                Text(String(format: "%.1f", score))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("trust score")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProfileDisplayView(
        profile: Profile(
            name: "Alex Chen",
            collegeYear: "junior",
            interests: ["Hiking", "Coffee", "Gaming"],
            photo: nil,
            trustScore: 3.8,
            email: "alex@ucdavis.edu",
            matchScore: nil
        ),
        onEdit: {}
    )
}
