import SwiftUI

// MARK: - Signal Form View
// Sheet for creating a new spontaneous signal.

struct SignalFormView: View {
    @EnvironmentObject var viewModel: SignalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ActivityCategory = .hangout
    @State private var selectedSlots: Set<SlotKey> = []
    @State private var minGroupSize: Int = 2
    @State private var maxGroupSize: Int = 4
    @State private var customActivityName: String = ""
    @State private var description: String = ""

    private var canSubmit: Bool {
        if selectedCategory == .custom && customActivityName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return !selectedSlots.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    categorySection
                    if selectedCategory == .custom {
                        customNameSection
                    }
                    availabilityGridSection
                    groupSizeSection
                    noteSection
                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Signal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Category Picker

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "What do you want to do?")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ActivityCategory.allCases) { category in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedCategory = category
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                Text(category.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                selectedCategory == category
                                    ? AnyShapeStyle(OrbitTheme.gradientFill)
                                    : AnyShapeStyle(Color(.systemGray6))
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedCategory == category
                                            ? Color.clear
                                            : Color(.systemGray4),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Custom Name

    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            OrbitSectionHeader(title: "Activity Name")
            TextField("Name your activity", text: $customActivityName)
                .textFieldStyle(.roundedBorder)
        }
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

            Text("\(minGroupSize)–\(maxGroupSize) people")
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            submitSignal()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isSubmitting ? "Sending..." : "Send Signal")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSubmit && !viewModel.isSubmitting
                    ? OrbitTheme.gradientFill
                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(canSubmit && !viewModel.isSubmitting ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit || viewModel.isSubmitting)
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
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: dateForOffset(offset))
    }

    private func dateLabel(for offset: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: dateForOffset(offset))
    }

    private func submitSignal() {
        guard canSubmit, !viewModel.isSubmitting else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let grouped = Dictionary(grouping: selectedSlots) { $0.dayOffset }
        let slots: [AvailabilitySlot] = grouped.keys.sorted().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            let blocks = grouped[dayOffset]!
                .map(\.timeBlock)
                .sorted { TimeBlock.allCases.firstIndex(of: $0)! < TimeBlock.allCases.firstIndex(of: $1)! }
            return AvailabilitySlot(date: date, timeBlocks: blocks)
        }

        Task {
            await viewModel.createSignal(
                activityCategory: selectedCategory,
                customActivityName: selectedCategory == .custom ? customActivityName.trimmingCharacters(in: .whitespaces) : nil,
                minGroupSize: minGroupSize,
                maxGroupSize: maxGroupSize,
                availability: slots,
                description: description.trimmingCharacters(in: .whitespaces)
            )
            if !viewModel.showError {
                dismiss()
            }
        }
    }
}

// MARK: - Slot Key

struct SlotKey: Hashable {
    let dayOffset: Int
    let timeBlock: TimeBlock
}
