//
//  MissionDetailView.swift
//  Orbit
//
//  Detail view for a single mission with map, participants, and actions.
//

import SwiftUI
import MapKit

struct MissionDetailView: View {
    let mission: Mission
    @EnvironmentObject var viewModel: MissionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Map (if coordinates available)
                if mission.hasCoordinates, let lat = mission.latitude, let lng = mission.longitude {
                    mapSection(lat: lat, lng: lng)
                }

                // Description
                if !mission.description.isEmpty {
                    descriptionSection
                }

                // Links
                if !mission.links.isEmpty {
                    linksSection
                }

                // Tags
                if !mission.tags.isEmpty {
                    tagsSection
                }

                // Participants
                participantsSection

                // Action Buttons
                actionButtons

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle(mission.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isCreator(mission) {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MissionFormView(mode: .edit(mission))
        }
        .confirmationDialog("Delete Mission", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    let deleted = await viewModel.deleteMission(id: mission.id)
                    if deleted { dismiss() }
                }
            }
        } message: {
            Text("Are you sure you want to delete this mission? This cannot be undone.")
        }
        .task {
            await viewModel.loadParticipants(missionId: mission.id)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date range
            if let start = mission.startDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(formatFullDateRange(start: start, end: mission.endDate))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            // Location
            if !mission.location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(mission.location)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            // Participant count
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                Text("\(mission.totalRsvpCount) attending")
                if mission.maxParticipants > 0 {
                    Text("(max \(mission.maxParticipants))")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: - Map

    private func mapSection(lat: Double, lng: Double) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        return Map(initialPosition: .region(region)) {
            Marker(mission.location.isEmpty ? mission.title : mission.location, coordinate: coordinate)
        }
        .frame(height: 200)
        .cornerRadius(12)
        .onTapGesture {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = mission.location.isEmpty ? mission.title : mission.location
            mapItem.openInMaps()
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(mission.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)
            ForEach(mission.links, id: \.self) { link in
                if let url = URL(string: link) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text(link)
                                .lineLimit(1)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(mission.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants")
                .font(.headline)

            let hardParticipants = viewModel.participants.filter { $0.rsvpType == .hard }
            let softParticipants = viewModel.participants.filter { $0.rsvpType == .soft }

            if !hardParticipants.isEmpty {
                Text("Confirmed (\(hardParticipants.count))")
                    .font(.subheadline)
                    .foregroundColor(.green)
                ForEach(hardParticipants) { participant in
                    participantRow(participant)
                }
            }

            if !softParticipants.isEmpty {
                Text("Interested (\(softParticipants.count))")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                ForEach(softParticipants) { participant in
                    participantRow(participant)
                }
            }

            if viewModel.participants.isEmpty {
                Text("No participants yet. Be the first to join!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func participantRow(_ participant: MissionParticipant) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photoURL: participant.profile?.photos.first,
                size: 36
            )
            Text(participant.profile?.name ?? "User \(participant.userId)")
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isCreator(mission) {
                // Creator sees nothing here (edit/delete in toolbar)
                EmptyView()
            } else if let rsvpType = viewModel.getUserRsvpType(missionId: mission.id) {
                // Already RSVPed - show leave button
                HStack {
                    Text(rsvpType == .hard ? "You're confirmed!" : "You're interested")
                        .font(.subheadline)
                        .foregroundColor(rsvpType == .hard ? .green : .blue)
                    Spacer()
                }
                Button {
                    Task { await viewModel.leaveMission(mission) }
                } label: {
                    Text("Leave Mission")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            } else {
                // Not RSVPed - show join buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.rsvpToMission(mission, rsvpType: .hard) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                            Text("I'm Going")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }

                    Button {
                        Task { await viewModel.rsvpToMission(mission, rsvpType: .soft) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.title2)
                            Text("Interested")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatFullDateRange(start: Date, end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var result = dateFormatter.string(from: start)
        if let end = end {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            if Calendar.current.isDate(start, inSameDayAs: end) {
                result += " - " + timeFormatter.string(from: end)
            } else {
                result += " - " + dateFormatter.string(from: end)
            }
        }
        return result
    }
}
