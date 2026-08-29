import SwiftUI
import SwiftData

/// Chips for problems previously logged at the session's gym, tap to re-add.
struct SuggestedProblemsRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    let session: Session
    let allSessions: [Session]

    private static let suggestionLimit = 6

    private struct Suggestion: Hashable {
        let name: String
        let grade: ColorGrade
        let styles: [RouteStyle]
    }

    private var suggestions: [Suggestion] {
        guard let gymName = session.gym?.name else { return [] }
        let alreadyAdded = Set(session.problems.map(\.name))
        let pastProblems = allSessions
            .filter { !$0.isLive && $0.gym?.name == gymName }
            .sorted { $0.startTime > $1.startTime }
            .flatMap(\.problems)
            .filter { !$0.name.isEmpty && !alreadyAdded.contains($0.name) }
        var seenNames: Set<String> = []
        var unique: [Suggestion] = []
        for problem in pastProblems where seenNames.insert(problem.name).inserted {
            unique.append(Suggestion(
                name: problem.name, grade: problem.colorGrade, styles: problem.styles
            ))
            if unique.count == Self.suggestionLimit { break }
        }
        return unique
    }

    var body: some View {
        let suggestions = self.suggestions
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Suggested at \(session.gym?.name ?? "")")
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func suggestionChip(_ suggestion: Suggestion) -> some View {
        Button {
            addProblem(from: suggestion)
        } label: {
            HStack(spacing: 7) {
                GradeDot(grade: suggestion.grade, size: 9)
                Text(suggestion.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.pill)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private func addProblem(from suggestion: Suggestion) {
        let problem = SessionProblem(
            name: suggestion.name, colorGrade: suggestion.grade, styles: suggestion.styles
        )
        session.problems.append(problem)
        try? modelContext.save()
    }
}

/// Simple leading-aligned wrap layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let placements = layout(proposal: proposal, subviews: subviews).placements
        for (subview, position) in zip(subviews, placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize,
                        subviews: Subviews) -> (size: CGSize, placements: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var placements: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }
            placements.append(cursor)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, cursor.x - spacing)
        }
        return (CGSize(width: totalWidth, height: cursor.y + rowHeight), placements)
    }
}
