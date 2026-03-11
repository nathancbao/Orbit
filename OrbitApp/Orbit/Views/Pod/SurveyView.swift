//
//  SurveyView.swift
//  Orbit
//
//  Post-activity survey: rate enjoyment, add interests, vote on pod members.
//

import SwiftUI

struct SurveyView: View {
    let pod: Pod
    @StateObject private var vm: SurveyViewModel
    @Environment(\.dismiss) private var dismiss

    init(pod: Pod) {
        self.pod = pod
        _vm = StateObject(wrappedValue: SurveyViewModel(pod: pod))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Text("How was it?")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(pod.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Section 1: Enjoyment Rating
                    enjoymentSection

                    // Section 2: Add Interests
                    if !vm.availableTags.isEmpty {
                        interestsSection
                    }

                    // Section 3: Pod Members
                    if !vm.otherMembers.isEmpty {
                        membersSection
                    }

                    // Error
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }

                    // Submit
                    Button(action: {
                        Task { await vm.submit() }
                    }) {
                        HStack {
                            if vm.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Submit Survey")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(vm.canSubmit ? OrbitTheme.gradientFill : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!vm.canSubmit || vm.isSubmitting)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: vm.didSubmit) { _, submitted in
                if submitted { dismiss() }
            }
        }
    }

    // MARK: - Enjoyment Section

    private var enjoymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Rate your enjoyment")

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { vm.enjoymentRating = star }) {
                        Image(systemName: star <= vm.enjoymentRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(
                                star <= vm.enjoymentRating
                                    ? AnyShapeStyle(OrbitTheme.gradient)
                                    : AnyShapeStyle(Color.gray.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Add to your interests")
            Text("Tap tags you'd like to add to your profile")
                .font(.caption)
                .foregroundColor(.secondary)

            TagFlowLayout(spacing: 8) {
                ForEach(vm.availableTags, id: \.self) { tag in
                    Button(action: { vm.toggleInterest(tag) }) {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(
                                vm.selectedInterests.contains(tag)
                                    ? AnyShapeStyle(Color.white)
                                    : AnyShapeStyle(OrbitTheme.gradient)
                            )
                            .background(
                                vm.selectedInterests.contains(tag)
                                    ? AnyShapeStyle(OrbitTheme.gradientFill)
                                    : AnyShapeStyle(OrbitTheme.purple.opacity(0.1))
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Pod members")
            Text("How were your pod mates?")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(vm.otherMembers) { member in
                    HStack(spacing: 12) {
                        ProfileAvatarView(photo: member.photo, size: 40, name: member.name)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !member.collegeYear.isEmpty {
                                Text(member.collegeYear)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Vote buttons
                        HStack(spacing: 12) {
                            Button(action: { vm.toggleVote(for: member.userId, vote: "up") }) {
                                Image(systemName: vm.memberVotes[member.userId] == "up" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.title3)
                                    .foregroundColor(vm.memberVotes[member.userId] == "up" ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            Button(action: { vm.toggleVote(for: member.userId, vote: "down") }) {
                                Image(systemName: vm.memberVotes[member.userId] == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .font(.title3)
                                    .foregroundColor(vm.memberVotes[member.userId] == "down" ? .red : .gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}
