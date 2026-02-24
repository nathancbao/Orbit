import SwiftUI

struct MissionFormView: View {
    let category: ActivityCategory
    @EnvironmentObject var viewModel: MissionsViewModel
    @Environment(\.dismiss) private var dismiss

    // Availability grid state
    @State private var selectedSlots: Set<SlotKey> = []

    // Group size
    @State private var minGroupSize: Int = 2
    @State private var maxGroupSize: Int = 4

    // Optional details
    @State private var customActivityName: String = ""
    @State private var description: String = ""

    private var canSubmit: Bool {
        if category == .custom && customActivityName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return !selectedSlots.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    activityHeader
                    availabilityGridSection
                    groupSizeSection
                    noteSection
                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Activity Header

    private var activityHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(OrbitTheme.gradientFill)
                    .frame(width: 64, height: 64)
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }

            if category == .custom {
                TextField("Name your activity", text: $customActivityName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            } else {
                Text(category.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Availability Grid

    private var availabilityGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "When are you free?")

            Text("Next 14 days — tap to toggle")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    dayHeaderRow
                    ForEach(TimeBlock.allCases) { block in
                        timeBlockRow(block: block)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var dayHeaderRow: some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 36)

            ForEach(0..<14, id: \.self) { dayOffset in
                VStack(spacing: 2) {
                    Text(weekdayLabel(for: dayOffset))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(dateLabel(for: dayOffset))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 44)
            }
        }
        .padding(.bottom, 6)
    }

    private func timeBlockRow(block: TimeBlock) -> some View {
        HStack(spacing: 4) {
            Text(block.shortLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<14, id: \.self) { dayOffset in
                let key = SlotKey(dayOffset: dayOffset, timeBlock: block)
                let isSelected = selectedSlots.contains(key)

                Button {
                    toggleSlot(key)
                } label: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? AnyShapeStyle(OrbitTheme.gradientFill) : AnyShapeStyle(Color(.systemGray5)))
                        .frame(width: 44, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Group Size

    private var groupSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Group Size")

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(minGroupSize)", value: $minGroupSize, in: 2...maxGroupSize)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(maxGroupSize)", value: $maxGroupSize, in: minGroupSize...20)
                        .font(.subheadline)
                }
            }

            Text("\(minGroupSize)-\(maxGroupSize) people")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Note")

            TextField("Add a note (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            submitMission()
        } label: {
            Text("Launch Mission")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? OrbitTheme.gradientFill : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(canSubmit ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func toggleSlot(_ key: SlotKey) {
        if selectedSlots.contains(key) {
            selectedSlots.remove(key)
        } else {
            selectedSlots.insert(key)
        }
    }

    private func dateForOffset(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func weekdayLabel(for offset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: dateForOffset(offset))
    }

    private func dateLabel(for offset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dateForOffset(offset))
    }

    private func submitMission() {
        guard canSubmit else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Group selected slots by dayOffset, build AvailabilitySlot array
        let grouped = Dictionary(grouping: selectedSlots) { $0.dayOffset }
        let slots: [AvailabilitySlot] = grouped.keys.sorted().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            let blocks = grouped[dayOffset]!
                .map(\.timeBlock)
                .sorted { TimeBlock.allCases.firstIndex(of: $0)! < TimeBlock.allCases.firstIndex(of: $1)! }
            return AvailabilitySlot(date: date, timeBlocks: blocks)
        }

        viewModel.createMission(
            activityCategory: category,
            customActivityName: category == .custom ? customActivityName.trimmingCharacters(in: .whitespaces) : nil,
            minGroupSize: minGroupSize,
            maxGroupSize: maxGroupSize,
            availability: slots,
            description: description.trimmingCharacters(in: .whitespaces)
        )

        dismiss()
    }
}

// MARK: - Slot Key

private struct SlotKey: Hashable {
    let dayOffset: Int
    let timeBlock: TimeBlock
}
