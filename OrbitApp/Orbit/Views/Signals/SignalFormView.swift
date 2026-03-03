import SwiftUI

// MARK: - Signal Form View
// Sheet for creating a new spontaneous signal with hourly scheduling.

struct SignalFormView: View {
    @EnvironmentObject var viewModel: SignalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ActivityCategory = .hangout
    @State private var customActivityName: String = ""
    @State private var description: String = ""
    @State private var link1: String = ""
    @State private var link2: String = ""
    @State private var minGroupSize: Int = 3
    @State private var maxGroupSize: Int = 8

    // Scheduling state
    @State private var selectedDays: Set<Int> = []          // day offsets (0 = today, 1 = tomorrow)
    @State private var selectedHours: Set<HourSlotKey> = [] // (dayOffset, hour)
    @State private var timeRangeStart: Int = 9
    @State private var timeRangeEnd: Int = 21

    private let maxDayOffset = 1  // Can only set 1 day in advance

    private var wordCount: Int {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var isOverWordLimit: Bool { wordCount > 250 }

    private var canSubmit: Bool {
        if selectedCategory == .custom && customActivityName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if isOverWordLimit { return false }
        return !selectedHours.isEmpty
    }

    private var linksArray: [String] {
        [link1, link2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Hours visible in the grid based on the time range.
    private var visibleHours: [Int] {
        guard timeRangeStart < timeRangeEnd else { return [] }
        return Array(timeRangeStart..<timeRangeEnd)
    }

    /// Sorted selected day offsets.
    private var sortedDays: [Int] {
        selectedDays.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    categorySection
                    if selectedCategory == .custom {
                        customNameSection
                    }
                    dayPickerSection
                    timeRangeSection
                    if !selectedDays.isEmpty {
                        hourlyGridSection
                    }
                    groupSizeSection
                    descriptionSection
                    linksSection
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

    // MARK: - Day Picker

    private var dayPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Which days?")

            Text("Select the days you're available (up to tomorrow)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(0...maxDayOffset, id: \.self) { offset in
                    let isSelected = selectedDays.contains(offset)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isSelected {
                            selectedDays.remove(offset)
                            // Remove hours for this day
                            selectedHours = selectedHours.filter { $0.dayOffset != offset }
                        } else {
                            selectedDays.insert(offset)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLabel(for: offset))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(dateLabel(for: offset))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? AnyShapeStyle(OrbitTheme.gradientFill)
                                : AnyShapeStyle(Color(.systemGray6))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.clear : Color(.systemGray4),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Time Range

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Time Range")

            Text("Set the window of hours to show")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Start", selection: $timeRangeStart) {
                        ForEach(0..<23, id: \.self) { h in
                            Text(hourString(h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: timeRangeStart) { newVal in
                        if newVal >= timeRangeEnd {
                            timeRangeEnd = min(newVal + 1, 23)
                        }
                        pruneHoursOutsideRange()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("End", selection: $timeRangeEnd) {
                        ForEach((timeRangeStart + 1)...23, id: \.self) { h in
                            Text(hourString(h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: timeRangeEnd) { _ in
                        pruneHoursOutsideRange()
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Hourly Grid (when2meet style)

    private var hourlyGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Pick your hours")

            Text("Tap hours you're free — \(selectedHours.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            // Grid: hour labels on left, day columns on right
            VStack(spacing: 0) {
                // Day column headers
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 56)

                    ForEach(sortedDays, id: \.self) { offset in
                        VStack(spacing: 2) {
                            Text(dayLabel(for: offset))
                                .font(.system(size: 12, weight: .semibold))
                            Text(dateLabel(for: offset))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)

                // Hour rows
                ForEach(visibleHours, id: \.self) { hour in
                    HStack(spacing: 0) {
                        Text(hourString(hour))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 56, alignment: .trailing)
                            .padding(.trailing, 6)

                        ForEach(sortedDays, id: \.self) { dayOffset in
                            let key = HourSlotKey(dayOffset: dayOffset, hour: hour)
                            let isSelected = selectedHours.contains(key)

                            Button {
                                toggleHourSlot(key)
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected
                                          ? AnyShapeStyle(OrbitTheme.gradientFill)
                                          : AnyShapeStyle(Color(.systemGray5)))
                                    .frame(height: 36)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 3)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quick actions
            HStack(spacing: 12) {
                Button("Select All") {
                    for day in sortedDays {
                        for hour in visibleHours {
                            selectedHours.insert(HourSlotKey(dayOffset: day, hour: hour))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(OrbitTheme.purple)

                Button("Clear") {
                    selectedHours.removeAll()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
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
                    Stepper("\(minGroupSize)", value: $minGroupSize, in: 3...maxGroupSize)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(maxGroupSize)", value: $maxGroupSize, in: minGroupSize...8)
                        .font(.subheadline)
                }
            }

            Text("\(minGroupSize)–\(maxGroupSize) people")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Description")
            TextField("Describe the activity (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...6)

            HStack {
                Spacer()
                Text("\(wordCount)/250 words")
                    .font(.caption2)
                    .foregroundColor(isOverWordLimit ? .red : .secondary)
            }
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionHeader(title: "Links (optional)")

            TextField("Paste a link", text: $link1)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Paste a second link", text: $link2)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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

    private func toggleHourSlot(_ key: HourSlotKey) {
        if selectedHours.contains(key) {
            selectedHours.remove(key)
        } else {
            selectedHours.insert(key)
        }
    }

    private func pruneHoursOutsideRange() {
        selectedHours = selectedHours.filter { $0.hour >= timeRangeStart && $0.hour < timeRangeEnd }
    }

    private func dateForOffset(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func dayLabel(for offset: Int) -> String {
        if offset == 0 { return "Today" }
        if offset == 1 { return "Tomorrow" }
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

        // Group selected hour slots by day, build AvailabilitySlot with hours
        let grouped = Dictionary(grouping: selectedHours) { $0.dayOffset }
        let slots: [AvailabilitySlot] = grouped.keys.sorted().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            let hours = grouped[dayOffset]!.map(\.hour).sorted()
            return AvailabilitySlot(date: date, hours: hours)
        }

        Task {
            await viewModel.createSignal(
                activityCategory: selectedCategory,
                customActivityName: selectedCategory == .custom ? customActivityName.trimmingCharacters(in: .whitespaces) : nil,
                minGroupSize: minGroupSize,
                maxGroupSize: maxGroupSize,
                availability: slots,
                description: description.trimmingCharacters(in: .whitespaces),
                links: linksArray,
                timeRangeStart: timeRangeStart,
                timeRangeEnd: timeRangeEnd
            )
            if !viewModel.showError {
                dismiss()
            }
        }
    }
}

// MARK: - Hour Slot Key

struct HourSlotKey: Hashable {
    let dayOffset: Int
    let hour: Int
}
