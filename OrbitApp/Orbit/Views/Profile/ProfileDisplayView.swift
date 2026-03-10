import SwiftUI

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}

struct ProfileDisplayView: View {
    let profile: Profile
    var onEdit: (() -> Void)? = nil
    var onProfileUpdated: ((Profile) -> Void)? = nil
    var otherUserId: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var galleryIndex = 0
    @State private var friendStatus: FriendStatus?
    @State private var isSendingRequest = false
    @State private var showLogoutConfirm = false

    private var isOwnProfile: Bool { otherUserId == nil && onProfileUpdated != nil }

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

                        // Trust score (only show once they have real ratings)
                        if let score = profile.trustScore, score > 0 {
                            TrustScoreView(score: score)
                        }

                        // Add Friend button (only when viewing someone else's profile)
                        if let targetId = otherUserId {
                            FriendActionButton(
                                friendStatus: friendStatus,
                                isSending: isSendingRequest,
                                onSend: {
                                    isSendingRequest = true
                                    Task {
                                        _ = try? await FriendService.shared.sendRequest(toUserId: targetId)
                                        friendStatus = FriendStatus(status: "pending_sent", requestId: nil)
                                        isSendingRequest = false
                                    }
                                },
                                onAccept: {
                                    guard let reqId = friendStatus?.requestId else { return }
                                    Task {
                                        _ = try? await FriendService.shared.acceptRequest(requestId: reqId)
                                        friendStatus = FriendStatus(status: "friends", requestId: nil)
                                    }
                                }
                            )
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

                        // Logout button (own profile only)
                        if isOwnProfile {
                            Button {
                                showLogoutConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Log Out")
                                }
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.8)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 80)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.white)
            .ignoresSafeArea(edges: .top)
            .alert("Log Out", isPresented: $showLogoutConfirm) {
                Button("Log Out", role: .destructive) {
                    Task {
                        try? await AuthService.shared.logout()
                        UserDefaults.standard.removeObject(forKey: "orbit_user_id")
                        UserDefaults.standard.removeObject(forKey: "orbit_user_name")
                        dismiss()
                        NotificationCenter.default.post(name: .didLogout, object: nil)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.black.opacity(0.7), Color.black.opacity(0.15))
                    }
                }
                if onProfileUpdated != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showEdit = true
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    }
                }
            }
            .task {
                if let targetId = otherUserId {
                    friendStatus = try? await FriendService.shared.checkFriendStatus(userId: targetId)
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

// MARK: - Friend Action Button

struct FriendActionButton: View {
    let friendStatus: FriendStatus?
    let isSending: Bool
    let onSend: () -> Void
    let onAccept: () -> Void

    var body: some View {
        Group {
            switch friendStatus?.status {
            case "friends":
                Label("Friends", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            case "pending_sent":
                Label("Request Sent", systemImage: "clock")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            case "pending_received":
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Accept Friend Request")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(OrbitTheme.gradientFill)
                    .clipShape(Capsule())
                }
            default:
                Button(action: onSend) {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friend")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(OrbitTheme.gradientFill)
                    .clipShape(Capsule())
                }
                .disabled(isSending)
            }
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
