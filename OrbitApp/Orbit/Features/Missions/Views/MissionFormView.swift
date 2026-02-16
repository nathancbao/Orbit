//
//  MissionFormView.swift
//  Orbit
//
//  Shared create/edit form for missions.
//

import SwiftUI

struct MissionFormView: View {
    enum Mode {
        case create
        case edit(Mission)
    }

    let mode: Mode
    @EnvironmentObject var viewModel: MissionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var startTime = Date().addingTimeInterval(3600)
    @State private var endTime = Date().addingTimeInterval(7200)
    @State private var maxParticipants = 0
    @State private var tags: [String] = []
    @State private var links: [String] = []
    @State private var newTag = ""
    @State private var newLink = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var formTitle: String {
        isEditing ? "Edit Mission" : "Create Mission"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Location", text: $location)
                }

                // Time
                Section("When") {
                    DatePicker("Start", selection: $startTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                }

                // Capacity
                Section("Capacity") {
                    Stepper("Max Participants: \(maxParticipants == 0 ? "Unlimited" : "\(maxParticipants)")",
                            value: $maxParticipants, in: 0...100)
                }

                // Tags
                Section("Tags") {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }

                    if tags.count < 5 {
                        HStack {
                            TextField("Add tag", text: $newTag)
                                .onSubmit { addTag() }
                            Button("Add") { addTag() }
                                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                // Links
                Section("Links (max 3)") {
                    ForEach(links, id: \.self) { link in
                        HStack {
                            Text(link)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                links.removeAll { $0 == link }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    if links.count < 3 {
                        HStack {
                            TextField("Add link", text: $newLink)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .onSubmit { addLink() }
                            Button("Add") { addLink() }
                                .disabled(newLink.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationTitle(formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || description.trimmingCharacters(in: .whitespaces).isEmpty)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .onAppear {
                if case .edit(let mission) = mode {
                    title = mission.title
                    description = mission.description
                    location = mission.location
                    tags = mission.tags
                    links = mission.links
                    maxParticipants = mission.maxParticipants
                    if let start = mission.startDate {
                        startTime = start
                    }
                    if let end = mission.endDate {
                        endTime = end
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func addLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !links.contains(trimmed) else { return }
        links.append(trimmed)
        newLink = ""
    }

    private func submit() async {
        let formatter = ISO8601DateFormatter()
        let data: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespaces),
            "description": description.trimmingCharacters(in: .whitespaces),
            "location": location.trimmingCharacters(in: .whitespaces),
            "start_time": formatter.string(from: startTime),
            "end_time": formatter.string(from: endTime),
            "max_participants": maxParticipants,
            "tags": tags,
            "links": links,
        ]

        if isEditing, case .edit(let mission) = mode {
            if await viewModel.updateMission(id: mission.id, data: data) != nil {
                dismiss()
            }
        } else {
            if await viewModel.createMission(data: data) != nil {
                dismiss()
            }
        }
    }
}
