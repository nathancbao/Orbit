//
//  FriendDetailSheet.swift
//  Orbit
//
//  Detailed view of a friend's profile with option to remove.
//

import SwiftUI

struct FriendDetailSheet: View {
    let friend: Friend
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    profileHeader

                    // Profile details
                    VStack(spacing: 20) {
                        // Bio
                        if !friend.friendProfile.bio.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("About", systemImage: "text.quote")
                                    .font(.headline)
                                Text(friend.friendProfile.bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()
                        }

                        // Interests
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Interests", systemImage: "heart.fill")
                                .font(.headline)

                            interestTags
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // Social preferences
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Social Style", systemImage: "person.2.fill")
                                .font(.headline)

                            HStack {
                                socialChip(label: friend.friendProfile.socialPreferences.groupSize, icon: "person.3")
                                socialChip(label: friend.friendProfile.socialPreferences.meetingFrequency, icon: "calendar")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // Connected since
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.green)
                            Text("Friends since \(formattedDate(friend.connectedAt))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 40)

                        // Remove friend button
                        Button(action: {
                            showRemoveConfirmation = true
                        }) {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(friend.friendProfile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove Friend",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    onRemove()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove \(friend.friendProfile.name) as a friend?")
            }
        }
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            VStack(spacing: 8) {
                ProfileAvatarView(
                    photoURL: friend.friendProfile.photos.first,
                    size: 80
                )

                Text("\(friend.friendProfile.name), \(friend.friendProfile.age)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(friend.friendProfile.location.city), \(friend.friendProfile.location.state)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 20)
        }
    }

    private var interestTags: some View {
        // Simple wrapping tags using LazyVGrid as fallback
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
            ForEach(friend.friendProfile.interests, id: \.self) { interest in
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

    private func socialChip(label: String, icon: String) -> some View {
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
