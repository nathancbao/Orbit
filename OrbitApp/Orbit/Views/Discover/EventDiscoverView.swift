import SwiftUI

// MARK: - Event Discover View
// Main discovery screen: AI-suggested events strip + full event list.
// Design: white bg, pink-blue gradient accents, wavy lines.

struct EventDiscoverView: View {
    let userProfile: Profile
    @StateObject private var viewModel = EventDiscoverViewModel()
    @State private var selectedEvent: Event?

    private let allTags = [
        "Hiking", "Gaming", "Music", "Food", "Sports",
        "Art", "Coffee", "Tech", "Fitness", "Travel"
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("discover")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("find your next adventure")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Year filter toggle
                        Button(action: {
                            Task { await viewModel.toggleYearFilter() }
                        }) {
                            Label(
                                viewModel.showMyYearOnly ? "My Year" : "All Years",
                                systemImage: viewModel.showMyYearOnly ? "person.fill.checkmark" : "person.2"
                            )
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.showMyYearOnly
                                ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.15))
                                : AnyShapeStyle(Color(.systemGray6))
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // AI Suggested Strip
                    if !viewModel.suggestedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("suggested for you")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(viewModel.suggestedEvents) { event in
                                        SuggestedEventCard(event: event) {
                                            selectedEvent = event
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Tag Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagFilterChip(label: "all", isSelected: viewModel.filterTag == nil) {
                                Task { await viewModel.applyTag(nil) }
                            }
                            ForEach(allTags, id: \.self) { tag in
                                TagFilterChip(
                                    label: tag.lowercased(),
                                    isSelected: viewModel.filterTag == tag
                                ) {
                                    Task { await viewModel.applyTag(viewModel.filterTag == tag ? nil : tag) }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // All Events List
                    if viewModel.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 40)
                    } else if viewModel.allEvents.isEmpty {
                        EmptyEventsView()
                            .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(viewModel.allEvents) { event in
                                EventCard(event: event) {
                                    selectedEvent = event
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
            }
            .refreshable {
                await viewModel.reload()
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event, onJoined: {
                Task { await viewModel.reload() }
                selectedEvent = nil
            })
        }
        .task {
            await viewModel.load(userYear: userProfile.collegeYear)
        }
        .navigationBarHidden(true)
    }

}

// MARK: - Suggested Event Card (horizontal strip)

struct SuggestedEventCard: View {
    let event: Event
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Reason chip
                if let reason = event.suggestionReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(OrbitTheme.gradient)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OrbitTheme.pink.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(event.displayDate)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(event.location.isEmpty ? "TBD" : event.location)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)

                PodSpotsLabel(event: event)
            }
            .padding(14)
            .frame(width: 200)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Event Card (vertical list)

struct EventCard: View {
    let event: Event
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Gradient left accent bar
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [OrbitTheme.pink, OrbitTheme.blue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(event.displayDate)
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(event.location.isEmpty ? "TBD" : event.location)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.secondary)

                    // Tags
                    if !event.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(event.tags.prefix(4), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(OrbitTheme.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                        .foregroundColor(OrbitTheme.blue)
                                }
                            }
                        }
                    }

                    PodSpotsLabel(event: event)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pod Spots Label

struct PodSpotsLabel: View {
    let event: Event

    var body: some View {
        Group {
            switch event.userPodStatus {
            case "in_pod":
                Label("you're in!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "pod_full":
                Label("pods full", systemImage: "person.fill.xmark")
                    .foregroundColor(.secondary)
            default:
                if let pods = event.pods, !pods.isEmpty {
                    let open = pods.filter { $0.status == "open" }
                    if let first = open.first {
                        Label("\(first.spotsLeft) spot\(first.spotsLeft == 1 ? "" : "s") left", systemImage: "person.badge.plus")
                            .foregroundStyle(
                                OrbitTheme.gradient
                            )
                    } else {
                        Label("join waitlist", systemImage: "person.badge.clock")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("be the first to join", systemImage: "star")
                        .foregroundStyle(
                            OrbitTheme.gradient
                        )
                }
            }
        }
        .font(.caption)
        .fontWeight(.medium)
    }
}

// MARK: - Tag Filter Chip

struct TagFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected
                    ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.2))
                    : AnyShapeStyle(Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? AnyShapeStyle(OrbitTheme.gradient)
                            : AnyShapeStyle(Color.clear),
                            lineWidth: 1.5
                        )
                )
                .clipShape(Capsule())
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Events View

struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(
                    OrbitTheme.gradient
                )
            Text("no events yet")
                .font(.headline)
            Text("pull down to refresh, or check back later!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
