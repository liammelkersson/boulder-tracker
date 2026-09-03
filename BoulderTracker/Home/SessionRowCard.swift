import SwiftUI

struct SessionRowCard: View {
    @Environment(\.palette) private var palette
    let session: Session
    var showsGymInSummary = false

    var body: some View {
        // Observation gives this row one last render after its session is
        // deleted; touching persisted properties then traps in SwiftData.
        if session.isInvalidated {
            EmptyView()
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            SessionPhotoThumbnail(session: session, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ClimbTypeChip(climbType: session.climbType)
                    Text(partnerLabel)
                        .scaledFont(size: 11)
                        .foregroundStyle(palette.textFaint)
                }
                Text(summaryLabel)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.startTime, format: .dateTime.month(.abbreviated).day())
                    .scaledFont(size: 12)
                Text(SessionDurationFormat.compactString(from: session.duration))
                    .scaledFont(size: 11)
            }
            .foregroundStyle(palette.textFaint)
            // Both call sites wrap the row in a button that opens the session
            // for editing; without this the row does not read as tappable.
            Image(systemName: "chevron.right")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(palette.textFaint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.surfaceSunken)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(session.climbType.chipColor.opacity(0.3), lineWidth: 1)
        }
    }

    private var partnerLabel: String {
        session.partners.isEmpty ? "Solo" : session.partners.map(\.name).joined(separator: ", ")
    }

    private var summaryLabel: String {
        let problemCount = session.problems.count
        let problemsPart = "\(problemCount) \(problemCount == 1 ? "problem" : "problems")"
        if showsGymInSummary {
            return "\(problemsPart) · \(session.gym?.name ?? "Unknown gym")"
        }
        let sendCount = session.problems.reduce(0) { $0 + $1.sendCount + $1.flashCount }
        let sendsPart = "\(sendCount) \(sendCount == 1 ? "send" : "sends")"
        return "\(problemsPart) · \(sendsPart)"
    }
}

struct ClimbTypeChip: View {
    let climbType: ClimbType

    var body: some View {
        Text(climbType.displayName)
            .scaledFont(size: 10, weight: .semibold)
            .foregroundStyle(climbType.chipColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(climbType.chipColor.opacity(0.14))
            .clipShape(.rect(cornerRadius: 6))
    }
}
