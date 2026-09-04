import SwiftUI

/// The pyramid: one row per tier, apex first, each row as wide as its target so
/// a thin base reads as a totem pole at a glance.
struct PyramidCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let sessions: [Session]

    private static let maxTarget = 8.0
    private static let rowHeight: CGFloat = 34

    private var pyramid: GradePyramid { GradePyramid(sessions: sessions.persisted) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Pyramid")
            VStack(alignment: .leading, spacing: 14) {
                let pyramid = self.pyramid
                if pyramid.tiers.isEmpty {
                    emptyState
                } else {
                    ForEach(pyramid.tiers) { tier in
                        tierRow(tier)
                    }
                    verdict(pyramid)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: 20)
        }
    }

    private var emptyState: some View {
        Text("Send something and your pyramid starts building")
            .scaledFont(size: 14)
            .foregroundStyle(palette.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func tierRow(_ tier: PyramidTier) -> some View {
        HStack(spacing: 10) {
            Text(tier.grade.shortLabel(in: gradeSystem))
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(palette.text)
                .frame(width: 34, alignment: .leading)
            tierBar(tier)
            Text("\(tier.sentCount)/\(tier.target)")
                .scaledFont(size: 12, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(tier.isMet ? palette.text : palette.textDim)
                .frame(width: 40, alignment: .trailing)
        }
    }

    /// The track's width carries the tier's target, the fill carries progress:
    /// a met base tier is a long full bar, a thin one a long mostly-empty bar.
    private func tierBar(_ tier: PyramidTier) -> some View {
        let trackFraction = Double(tier.target) / Self.maxTarget
        let fillFraction = min(1, Double(tier.sentCount) / Double(tier.target))
        return GeometryReader { geometry in
            let trackWidth = geometry.size.width * trackFraction
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(palette.surfaceSunken)
                    .frame(width: trackWidth)
                RoundedRectangle(cornerRadius: 7)
                    .fill(tier.grade.displayColor)
                    .frame(width: trackWidth * fillFraction)
                    .overlay {
                        if tier.grade.needsOutline {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(palette.border.opacity(0.2), lineWidth: 1)
                                .frame(width: trackWidth * fillFraction)
                        }
                    }
            }
        }
        .frame(height: Self.rowHeight)
    }

    private func verdict(_ pyramid: GradePyramid) -> some View {
        Text(verdictText(pyramid))
            .scaledFont(size: 13)
            .foregroundStyle(pyramid.isTotemPole ? palette.text : palette.textDim)
            .padding(.top, 2)
    }

    private func verdictText(_ pyramid: GradePyramid) -> String {
        if pyramid.isTotemPole {
            return "Totem pole — base is thin. \(shortfallText(pyramid.unmetTiers)) to even it out."
        }
        guard let nextBand = pyramid.nextBand else {
            return "Base is solid all the way up."
        }
        return "Base is solid. \(nextBand.displayName) is fair game."
    }

    private func shortfallText(_ tiers: [PyramidTier]) -> String {
        tiers
            .map { "\($0.shortfall) more \($0.grade.displayName.lowercased())" }
            .formatted(.list(type: .and))
    }
}
