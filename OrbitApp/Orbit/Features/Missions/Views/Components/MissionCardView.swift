//
//  MissionCardView.swift
//  Orbit
//
//  Card component for the missions feed.
//

import SwiftUI

struct MissionCardView: View {
    let mission: Mission
    let userRsvpType: RSVPType?
    let isCreator: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title + Creator badge
            HStack {
                Text(mission.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                if isCreator {
                    Text("Creator")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                } else if let rsvp = userRsvpType {
                    Text(rsvp == .hard ? "Going" : "Interested")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rsvp == .hard ? Color.green.opacity(0.8) : Color.blue.opacity(0.8))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }

            // Date range
            if let start = mission.startDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(formatDateRange(start: start, end: mission.endDate))
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.8))
            }

            // Location
            if !mission.location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                    Text(mission.location)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.8))
            }

            // Tags
            if !mission.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(mission.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }

            // Bottom: Participant count
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(mission.totalRsvpCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                    if mission.maxParticipants > 0 {
                        Text("/ \(mission.maxParticipants)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .foregroundColor(.white.opacity(0.9))

                Spacer()

                if mission.totalRsvpCount > 0 {
                    Text("\(mission.hardRsvpCount) confirmed")
                        .font(.caption2)
                        .foregroundColor(.green.opacity(0.9))
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.1, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatDateRange(start: Date, end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var result = dateFormatter.string(from: start)
        if let end = end {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                result += " - " + timeFormatter.string(from: end)
            } else {
                result += " - " + dateFormatter.string(from: end)
            }
        }
        return result
    }
}
