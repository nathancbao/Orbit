import SwiftUI

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}

struct ProfileDisplayView: View {
    @State private var profile: Profile
    var onEdit: (() -> Void)? = nil
    var onProfileUpdated: ((Profile) -> Void)? = nil
    var otherUserId: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var galleryIndex = 0
    @State private var friendStatus: FriendStatus?
    @State private var isSendingRequest = false
    @State private var showLogoutConfirm = false
    @State private var showComingSoon = false

    init(profile: Profile, onEdit: (() -> Void)? = nil,
         onProfileUpdated: ((Profile) -> Void)? = nil, otherUserId: Int? = nil) {
        self._profile = State(initialValue: profile)
        self.onEdit = onEdit
        self.onProfileUpdated = onProfileUpdated
        self.otherUserId = otherUserId
    }

    private var isOwnProfile: Bool { otherUserId == nil && onProfileUpdated != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Name + gender
                    VStack(spacing: 4) {
                        Text(profile.name)
                            .font(.title)
                            .fontWeight(.bold)

                        if !profile.gender.isEmpty {
                            Text(Profile.displayGender(profile.gender))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(OrbitTheme.gradient)
                        }
                    }
                    .padding(.top, 12)

                    // Circular avatar with astral mascot badge (mascot = future feature)
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let photoURL = profile.photo, let url = URL(string: photoURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    circlePlaceholder
                                }
                            } else {
                                circlePlaceholder
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1.5))

                        Image("coloredStar")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                            .offset(x: -2, y: -2)
                    }

                    // Grade level + age (age is a placeholder — no birthdate field yet)
                    VStack(spacing: 2) {
                        Text(Profile.displayYear(profile.collegeYear))
                            .font(.headline)
                            .foregroundStyle(OrbitTheme.gradient)

                        Text("{Age} Years Old")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 24) {

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

                        // Bio
                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

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
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }

                        // Habits sentence (template — feature in progress, no data yet)
                        habitsSentence
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity, alignment: .leading)

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
            .alert("Coming Soon", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This feature isn't available yet.")
            }
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
                } else if otherUserId != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showComingSoon = true
                            } label: {
                                Label("Block", systemImage: "hand.raised")
                            }
                            Button {
                                showComingSoon = true
                            } label: {
                                Label("Report", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .task {
                if let targetId = otherUserId {
                    async let statusFetch: FriendStatus? = try? FriendService.shared.checkFriendStatus(userId: targetId)
                    async let profileFetch: Profile? = try? ProfileService.shared.getUserProfile(id: targetId)
                    friendStatus = await statusFetch
                    if let full = await profileFetch {
                        profile = full
                    }
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

    private var circlePlaceholder: some View {
        ZStack {
            OrbitTheme.gradientFill
            Text(String(profile.name.prefix(1)).uppercased())
                .orbitFont(56, weight: .bold)
                .foregroundColor(.white)
        }
    }

    // Template sentence — habits feature is in progress, no real data yet.
    private var habitsSentence: Text {
        let firstName = profile.name.split(separator: " ").first.map(String.init) ?? profile.name
        return (Text(firstName + " prefers ").italic()
                + Text("larger group settings").italic().foregroundColor(OrbitTheme.blue)
                + Text(", in the ").italic()
                + Text("morning").italic().foregroundColor(OrbitTheme.pink))
            .font(.subheadline)
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
            Text("Trust Score")
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
