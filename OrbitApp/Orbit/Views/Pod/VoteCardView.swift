import SwiftUI

// MARK: - Vote Card View
// Inline card in the chat for time/place voting.

struct VoteCardView: View {
    let vote: Vote
    let currentUserId: Int
    let onVote: (String, Int) -> Void  // (voteId, optionIndex)

    private var userVote: Int? {
        vote.votes[String(currentUserId)]
    }

    private var totalVotes: Int { vote.votes.count }

    private func votesFor(_ index: Int) -> Int {
        vote.votes.values.filter { $0 == index }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: vote.voteType == "time" ? "clock" : "mappin")
                    .foregroundStyle(orbitGradient)
                Text("Vote on a \(vote.voteType)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(vote.status == "closed" ? "closed ✓" : "\(totalVotes) vote\(totalVotes == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let result = vote.result, vote.status == "closed" {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(result)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .cornerRadius(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(vote.options.enumerated()), id: \.offset) { index, option in
                        let isMyVote = userVote == index
                        let count = votesFor(index)
                        let fraction = totalVotes > 0 ? CGFloat(count) / CGFloat(totalVotes) : 0

                        Button(action: {
                            if vote.status == "open" {
                                onVote(vote.id, index)
                            }
                        }) {
                            ZStack(alignment: .leading) {
                                // Progress bar background
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(orbitGradient.opacity(0.15))
                                        .frame(width: geo.size.width * fraction)
                                        .animation(.easeInOut(duration: 0.3), value: fraction)
                                }
                                .frame(height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                HStack {
                                    if isMyVote {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(orbitGradient)
                                    }
                                    Text(option)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                            }
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isMyVote
                                        ? AnyShapeStyle(orbitGradient)
                                        : AnyShapeStyle(Color(.systemGray4)),
                                        lineWidth: isMyVote ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(vote.status == "closed")
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var orbitGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.45, green: 0.55, blue: 0.85)],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
