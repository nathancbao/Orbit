import SwiftUI

struct ProfileDisplayView: View {
    let profile: Profile
    var onEdit: (() -> Void)? = nil
    var onProfileUpdated: ((Profile) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var galleryIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Hero profile photo (large, Tinder-style)
                    GeometryReader { geo in
                        if let photoURL = profile.photo, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                heroPlaceholder
                            }
                            .frame(width: geo.size.width, height: geo.size.width * 1.15)
                            .clipped()
                        } else {
                            heroPlaceholder
                                .frame(width: geo.size.width, height: geo.size.width * 1.15)
                        }
                    }
                    .aspectRatio(1 / 1.15, contentMode: .fit)

                    // Content below the hero photo
                    VStack(spacing: 24) {

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
                        .padding(.top, 20)

                        // Gender + MBTI badges
                        if !profile.gender.isEmpty || !profile.mbti.isEmpty {
                            HStack(spacing: 8) {
                                if !profile.gender.isEmpty {
                                    Text(Profile.displayGender(profile.gender))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(OrbitTheme.gradient.opacity(0.15))
                                        .foregroundStyle(OrbitTheme.gradient)
                                        .clipShape(Capsule())
                                }
                                if !profile.mbti.isEmpty {
                                    Text(profile.mbti)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(OrbitTheme.gradient.opacity(0.15))
                                        .foregroundStyle(OrbitTheme.gradient)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        // Bio
                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
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

                        // Gallery photos (swipeable carousel)
                        if !profile.galleryPhotos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("gallery")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(galleryIndex + 1)/\(profile.galleryPhotos.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 28)

                                TabView(selection: $galleryIndex) {
                                    ForEach(Array(profile.galleryPhotos.enumerated()), id: \.offset) { index, urlString in
                                        AsyncImage(url: URL(string: urlString)) { image in
                                            image.resizable().scaledToFit()
                                        } placeholder: {
                                            Color(.systemGray5)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal, 28)
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(height: 320)
                            }
                        }

                        // Links
                        if !profile.links.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("links")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(profile.links, id: \.self) { link in
                                    if let url = URL(string: link) {
                                        Link(destination: url) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "link")
                                                    .font(.caption)
                                                Text(link)
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            .foregroundStyle(OrbitTheme.gradient)
                                        }
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "link")
                                                .font(.caption)
                                            Text(link)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }

                        Spacer(minLength: 80)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.white)
            .ignoresSafeArea(edges: .top)
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
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
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

    private var heroPlaceholder: some View {
        ZStack {
            OrbitTheme.gradientFill
            Text(String(profile.name.prefix(1)).uppercased())
                .font(.system(size: 72, weight: .bold))
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
            galleryPhotos: [],
            bio: "Coffee enthusiast and avid hiker. Always down for board games!",
            links: ["https://github.com/alexchen"],
            gender: "male",
            mbti: "ENFP"
        ),
        onEdit: {}
    )
}
