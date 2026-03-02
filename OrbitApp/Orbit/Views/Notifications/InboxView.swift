import SwiftUI

struct InboxView: View {
    @EnvironmentObject var viewModel: NotificationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                        .tint(OrbitTheme.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("no notifications yet")
                            .font(.headline)
                        Text("you'll see updates about your pods, messages, and recommended events here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationRow(notification: notification)
                                    .onTapGesture {
                                        if !notification.read {
                                            Task { await viewModel.markRead([notification.id]) }
                                        }
                                    }
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.unreadCount > 0 {
                        Button("Read All") {
                            Task { await viewModel.markAllRead() }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .task { await viewModel.load() }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: notification.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.read ? .regular : .semibold)
                    .foregroundColor(.primary)

                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(notification.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }

            Spacer()

            // Unread dot
            if !notification.read {
                Circle()
                    .fill(OrbitTheme.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notification.read ? Color.clear : OrbitTheme.blue.opacity(0.04))
    }

    private var iconBackground: Color {
        switch notification.type {
        case "pod_join":           return .green
        case "pod_leave":          return .orange
        case "chat_message":       return OrbitTheme.blue
        case "recommended_event":  return OrbitTheme.purple
        default:                   return .gray
        }
    }
}
