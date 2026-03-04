//
//  FlexPodFormingView.swift
//  Orbit
//
//  Forming state container for flex mode pods. Shows the When2Meet scheduling
//  grid with phase-dependent status banners and action buttons.
//  Replaces the chat UI until scheduling is confirmed.
//

import SwiftUI

struct FlexPodFormingView: View {
    let pod: Pod
    @ObservedObject var scheduleVM: ScheduleViewModel
    @ObservedObject var podVM: PodViewModel

    private let currentUserId: Int = {
        UserDefaults.standard.integer(forKey: "orbit_user_id")
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Member strip (reuse existing from PodView)
            if let members = pod.members {
                MemberStripView(
                    members: members,
                    currentUserId: currentUserId,
                    onKick: { _ in },
                    onTapMember: nil
                )
            }

            Divider()

            // Phase-dependent status banner
            phaseHeader

            Divider()

            // Schedule grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Selection count
                    if scheduleVM.isEditable {
                        HStack {
                            Image(systemName: "hand.tap")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Drag to select hours — \(scheduleVM.currentUserSlots.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    ScheduleGridView(viewModel: scheduleVM, pod: pod)
                        .padding(.horizontal, 12)

                    // Overlap summary
                    if !scheduleVM.overlapSlots.isEmpty {
                        overlapSummary
                    }

                    // Near-overlap hints
                    if !scheduleVM.nearOverlapInfo.isEmpty && scheduleVM.overlapSlots.isEmpty {
                        nearOverlapHints
                    }
                }
                .padding(.bottom, 100) // Space for bottom action button
            }

            Spacer(minLength: 0)

            // Bottom action area
            bottomActions
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Phase Header

    @ViewBuilder
    private var phaseHeader: some View {
        switch scheduleVM.phase {
        case .forming:
            StatusBanner(
                icon: "calendar.badge.plus",
                text: "Add your availability (\(pod.memberIds.count)/3 members)",
                color: .orange
            )
        case .locked(let hasOverlap):
            if hasOverlap {
                StatusBanner(
                    icon: "checkmark.circle",
                    text: "Overlap found! Waiting for leader to pick a time...",
                    color: .green
                )
            } else {
                StatusBanner(
                    icon: "exclamationmark.triangle",
                    text: "Grid locked. No overlap found.",
                    color: .orange
                )
            }
        case .leaderPicking:
            StatusBanner(
                icon: "crown",
                text: "You're the leader! Tap an overlap slot to confirm.",
                color: OrbitTheme.purple
            )
        case .noOverlapCountdown:
            StatusBanner(
                icon: "clock.badge.exclamationmark",
                text: "No overlap yet. Update your availability! \(scheduleVM.countdownText)",
                color: .red
            )
        case .scheduled:
            StatusBanner(
                icon: "checkmark.seal.fill",
                text: "Meeting scheduled! Chat is now open.",
                color: .green
            )
        case .dissolved:
            StatusBanner(
                icon: "xmark.octagon.fill",
                text: "Pod dissolved — scheduling timed out.",
                color: .red
            )
        }
    }

    // MARK: - Overlap Summary

    private var overlapSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                Text("Overlap slots (\(scheduleVM.overlapSlots.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            TagFlowLayout(spacing: 6) {
                ForEach(Array(scheduleVM.overlapSlots).sorted(by: { $0.key < $1.key }), id: \.key) { slot in
                    Text(ScheduleViewModel.formatSlot(slot))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Near-Overlap Hints

    private var nearOverlapHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                Text("Almost there! These slots need 1 more person:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TagFlowLayout(spacing: 6) {
                ForEach(Array(scheduleVM.nearOverlapInfo.keys).sorted(by: { $0.key < $1.key }).prefix(6), id: \.key) { slot in
                    Text(ScheduleViewModel.formatSlot(slot))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Bottom Actions

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 0) {
            Divider()

            Group {
                switch scheduleVM.phase {
                case .forming, .noOverlapCountdown:
                    // Save availability button
                    Button {
                        scheduleVM.saveAvailability(pod: pod)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save Availability")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(scheduleVM.currentUserSlots.isEmpty
                                    ? AnyShapeStyle(Color(.systemGray4))
                                    : AnyShapeStyle(OrbitTheme.gradientFill))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(scheduleVM.currentUserSlots.isEmpty)

                case .leaderPicking:
                    if let selected = scheduleVM.selectedConfirmSlot {
                        Button {
                            Task { await scheduleVM.confirmTimeSlot() }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.seal")
                                Text("Confirm: \(ScheduleViewModel.formatSlot(selected))")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(OrbitTheme.gradientFill)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        Text("Tap an overlap slot above to select it")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }

                case .locked:
                    Text("Waiting for the leader to pick a time...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                case .scheduled:
                    EmptyView()

                case .dissolved:
                    Text("This pod has been dissolved")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Status Banner

struct StatusBanner: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
    }
}
