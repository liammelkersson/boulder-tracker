import SwiftUI

/// Terrain angles and hold types tried in the period, with the skipped ones
/// named — the guide's "try one new angle, one new hold type each session".
struct StyleCoverageCard: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let cardCornerRadius: CGFloat = 20
    private static let groupSpacing: CGFloat = 20
    private static let chipSpacing: CGFloat = 6
    private static let groupTitleSize: CGFloat = 14
    private static let detailTextSize: CGFloat = 12

    private var groups: [StyleCoverageGroup] {
        StyleCoverage.groups(of: sessions.persisted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Terrain & holds")
            VStack(alignment: .leading, spacing: Self.groupSpacing) {
                ForEach(groups) { group in
                    groupRows(group)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: Self.cardCornerRadius)
        }
    }

    private func groupRows(_ coverage: StyleCoverageGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(coverage)
            FlowLayout(spacing: Self.chipSpacing) {
                ForEach(coverage.group.styles) { style in
                    StyleCoverageChip(
                        style: style, isTried: coverage.triedStyles.contains(style)
                    )
                }
            }
            Text(coverage.coverageSummary)
                .scaledFont(size: Self.detailTextSize)
                .foregroundStyle(palette.textFaint)
        }
    }

    private func groupHeader(_ coverage: StyleCoverageGroup) -> some View {
        HStack {
            Text(coverage.group.displayName)
                .scaledFont(size: Self.groupTitleSize, weight: .semibold)
                .foregroundStyle(palette.text)
            Spacer()
            Text("\(coverage.triedStyles.count)/\(coverage.group.styles.count)")
                .scaledFont(size: Self.detailTextSize, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(palette.textDim)
        }
    }
}
