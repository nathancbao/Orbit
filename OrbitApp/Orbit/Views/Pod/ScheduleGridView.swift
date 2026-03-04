//
//  ScheduleGridView.swift
//  Orbit
//
//  Multi-user When2Meet-style availability grid with coordinate-based drag gesture.
//  Shows each member's slots in their assigned color with overlap indicators.
//

import SwiftUI

struct ScheduleGridView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let pod: Pod

    // Coordinate-based gesture mapping: slot key → global frame
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var lastDragSlotKey: String?

    // Layout constants
    private let hourLabelWidth: CGFloat = 50
    private let cellHeight: CGFloat = 36
    private let cellSpacing: CGFloat = 2
    private let dayHeaderHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            legendBar
            gridContent
        }
    }

    // MARK: - Legend Bar

    private var legendBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(viewModel.grid.entries) { entry in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(entry.memberColor.color)
                            .frame(width: 10, height: 10)
                        Text(entry.displayName)
                            .font(.caption)
                            .foregroundColor(.primary)
                        if entry.hasSubmitted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }
                }

                if viewModel.grid.entries.isEmpty {
                    Text("No members yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 0) {
                // Day column headers
                dayHeaders

                // Hour rows with cells
                ForEach(Array(ScheduleGrid.hourRange), id: \.self) { hour in
                    hourRow(hour: hour)
                }
            }
            .padding(8)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onPreferenceChange(CellFramePreferenceKey.self) { frames in
                cellFrames = frames
            }
        }
    }

    // MARK: - Day Headers

    private var dayHeaders: some View {
        HStack(spacing: cellSpacing) {
            // Empty corner for hour labels
            Text("")
                .frame(width: hourLabelWidth, height: dayHeaderHeight)

            ForEach(viewModel.grid.dates, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(dayLabel(for: date))
                        .font(.system(size: 11, weight: .semibold))
                    Text(dateLabel(for: date))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: dayHeaderHeight)
            }
        }
    }

    // MARK: - Hour Row

    private func hourRow(hour: Int) -> some View {
        HStack(spacing: cellSpacing) {
            // Hour label
            Text(hourLabel(hour))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: hourLabelWidth, alignment: .trailing)
                .padding(.trailing, 4)

            // Cells for each day
            ForEach(viewModel.grid.dates, id: \.self) { date in
                let slot = TimeSlot(date: date, hour: hour)
                cellView(for: slot)
                    .frame(width: 48, height: cellHeight)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: CellFramePreferenceKey.self,
                                value: [slot.key: proxy.frame(in: .global)]
                            )
                        }
                    )
            }
        }
        .padding(.vertical, 1)
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(for slot: TimeSlot) -> some View {
        let members = viewModel.grid.members(for: slot)
        let count = members.count
        let isCurrentUserSlot = viewModel.currentUserSlots.contains(slot)
        let isOverlap = viewModel.overlapSlots.contains(slot)
        let isNearOverlap = viewModel.nearOverlapInfo.keys.contains(slot)
        let isLeaderPickable = viewModel.phase == .leaderPicking && isOverlap
        let isSelected = viewModel.selectedConfirmSlot == slot

        ZStack {
            // Background based on member count
            cellBackground(members: members, count: count)

            // Current user's uncommitted selection indicator
            if isCurrentUserSlot && count == 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(currentUserColor.opacity(0.5))
            }

            // Overlap checkmark
            if isOverlap && count >= 2 {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }

            // Leader pick selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            // Near-overlap dashed border
            Group {
                if isNearOverlap && !isOverlap {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .foregroundColor(.orange.opacity(0.6))
                }
            }
        )
        // Full overlap glow
        .shadow(color: isOverlap && count >= 2 ? .white.opacity(0.4) : .clear, radius: 3)
        // Leader-pickable tap
        .onTapGesture {
            if isLeaderPickable {
                viewModel.selectOverlapSlot(slot)
            }
        }
    }

    // MARK: - Cell Background by Member Count

    @ViewBuilder
    private func cellBackground(members: [ScheduleEntry], count: Int) -> some View {
        switch count {
        case 0:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))

        case 1:
            RoundedRectangle(cornerRadius: 4)
                .fill(members[0].memberColor.color)

        case 2:
            HStack(spacing: 0) {
                members[0].memberColor.color
                members[1].memberColor.color
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))

        default:
            // 3+ members: striped with glow border
            StripedCellView(colors: members.map(\.memberColor.color))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                )
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard viewModel.isEditable else { return }
                guard let slot = slotAt(point: value.location) else { return }
                let key = slot.key
                guard key != lastDragSlotKey else { return }
                lastDragSlotKey = key

                if !viewModel.isDragging {
                    viewModel.beginDrag(at: slot)
                } else {
                    viewModel.continueDrag(over: slot)
                }
            }
            .onEnded { _ in
                viewModel.endDrag()
                lastDragSlotKey = nil
            }
    }

    /// Map a global screen coordinate to a TimeSlot using captured cell frames.
    private func slotAt(point: CGPoint) -> TimeSlot? {
        for (key, frame) in cellFrames {
            if frame.contains(point) {
                return parseSlotKey(key)
            }
        }
        return nil
    }

    /// Parse a slot key back into a TimeSlot. Key format: "YYYY-M-D-HH".
    private func parseSlotKey(_ key: String) -> TimeSlot? {
        let parts = key.split(separator: "-")
        guard parts.count == 4,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              let hour = Int(parts[3]) else { return nil }
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        guard let date = Calendar.current.date(from: c) else { return nil }
        return TimeSlot(date: date, hour: hour)
    }

    // MARK: - Formatting Helpers

    private func dayLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df.string(from: date)
    }

    private func dateLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df.string(from: date)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }

    /// Current user's assigned color (from their entry, or default pink).
    private var currentUserColor: Color {
        if let entry = viewModel.grid.entries.first(where: { $0.userId == viewModel.currentUserId }) {
            return entry.memberColor.color
        }
        return MemberColor.pink.color
    }
}

// MARK: - Striped Cell View (3+ Members)

struct StripedCellView: View {
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<colors.count, id: \.self) { i in
                    colors[i]
                        .frame(width: max(1, geo.size.width / CGFloat(colors.count)))
                }
            }
        }
    }
}

// MARK: - Cell Frame Preference Key

/// Collects cell frames for coordinate-based gesture mapping.
struct CellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
