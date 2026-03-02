import SwiftUI

// MARK: - Signals View
// Spontaneous activity feed with Discover / My Signals segments and a FAB to create.

struct SignalsView: View {
    @Binding var userProfile: Profile
    @EnvironmentObject var notificationVM: NotificationViewModel
    @StateObject private var viewModel = SignalsViewModel()
    @State private var segment: SignalSegment = .discover
    @State private var selectedSignal: Signal?
    @State private var showForm = false
    @State private var showProfile = false
    @State private var showInbox = false

    enum SignalSegment: String, CaseIterable {
        case discover = "Discover"
        case mine = "My Signals"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment picker
                    Picker("", selection: $segment) {
                        ForEach(SignalSegment.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    // Content
                    let signals = segment == .discover
                        ? viewModel.discoverSignals
                        : viewModel.mySignals

                    if viewModel.isLoading && signals.isEmpty {
                        Spacer()
                        ProgressView().tint(OrbitTheme.purple)
                        Spacer()
                    } else if signals.isEmpty {
                        Spacer()
                        EmptySignalsView(segment: segment, onSignalTap: { showForm = true })
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                ForEach(signals) { signal in
                                    SignalCard(
                                        signal: signal,
                                        showDelete: segment == .mine,
                                        onTap: { selectedSignal = signal },
                                        onDelete: { Task { await viewModel.deleteSignal(id: signal.id) } }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                        .refreshable {
                            await viewModel.reload()
                        }
                    }
                }

                // FAB
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showForm = true
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(18)
                        .background(OrbitTheme.gradientFill)
                        .clipShape(Circle())
                        .shadow(color: OrbitTheme.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Signals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showInbox = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .fontWeight(.medium)
                                .foregroundStyle(Color.primary)
                            if notificationVM.unreadCount > 0 {
                                Text("\(min(notificationVM.unreadCount, 99))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        ProfileAvatarView(photo: userProfile.photo, size: 30, name: userProfile.name)
                    }
                }
            }
        }
        .sheet(isPresented: $showInbox) {
            InboxView()
                .environmentObject(notificationVM)
        }
        .sheet(isPresented: $showProfile) {
            ProfileDisplayView(
                profile: userProfile,
                onEdit: { showProfile = false },
                onProfileUpdated: { updated in userProfile = updated }
            )
        }
        .sheet(isPresented: $showForm) {
            SignalFormView()
                .environmentObject(viewModel)
        }
        .sheet(item: $selectedSignal) { signal in
            SignalDetailView(signal: signal, viewModel: viewModel)
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                toastView
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showToast)
        .task {
            await viewModel.loadSignals()
        }
    }

    private var toastView: some View {
        Text(viewModel.toastMessage ?? "")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.22).opacity(0.95))
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}

// MARK: - Signal Card

struct SignalCard: View {
    let signal: Signal
    let showDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                OrbitTheme.gradientFill
                    .frame(height: 4)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: signal.activityCategory.icon)
                            .font(.title3)
                            .foregroundStyle(OrbitTheme.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(signal.displayTitle)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(2)

                            Text(signal.activityCategory.displayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        SignalStatusBadge(status: signal.status)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(signal.availabilitySummary)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text(signal.groupSizeLabel)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))

                    if !signal.description.isEmpty {
                        Text(signal.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                .padding(14)
            }
            .background(OrbitTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if showDelete {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove Signal", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Remove this signal?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Signal Status Badge

struct SignalStatusBadge: View {
    let status: SignalStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                status == .pending
                    ? OrbitTheme.purple.opacity(0.85)
                    : OrbitTheme.blue.opacity(0.85)
            )
            .clipShape(Capsule())
            .foregroundColor(.white)
    }
}

// MARK: - Empty Signals View

struct EmptySignalsView: View {
    let segment: SignalsView.SignalSegment
    var onSignalTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(OrbitTheme.gradient)
            Text(segment == .discover ? "no signals out there" : "you haven't sent any signals")
                .font(.headline)
            Text(segment == .discover
                 ? "check back soon, or be the first to send one"
                 : "let people know what you're down to do")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let onSignalTap {
                Button(action: onSignalTap) {
                    Label("Send a Signal", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(OrbitTheme.gradientFill)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
    }
}
