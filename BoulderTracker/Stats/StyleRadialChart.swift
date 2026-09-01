import SwiftUI

/// Segmented-wheel breakdown of send rate per style: the top styles form a
/// full circle of muted wedges, and an accent wedge grows outward from the
/// hub inside each slice as the send rate rises.
struct StyleRadialChart: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let chartSize: CGFloat = 320
    private static let holeRadius: CGFloat = 22
    private static let outerRadius: CGFloat = 152
    /// Value wedges stop short of the label band so text always sits on the muted base.
    private static let labelBandDepth: CGFloat = 46
    private static let minValueDepth: CGFloat = 12
    private static let valueInset: CGFloat = 5
    private static let maxPetals = 6

    private struct Petal: Identifiable {
        let id: RouteStyle
        let label: String
        let percent: Int
        let angle: Angle
    }

    private var petals: [Petal] {
        let sessions = self.sessions.persisted
        let rates = StatsAggregator.sendRatePerStyle(of: sessions)
        let styleFrequency = Dictionary(
            grouping: sessions.flatMap(\.problems).flatMap(\.styles), by: \.self
        ).mapValues(\.count)
        let topStyles = styleFrequency
            .sorted { $0.value > $1.value }
            .prefix(Self.maxPetals)
            .map(\.key)
        return topStyles.enumerated().map { index, style in
            Petal(
                id: style,
                label: style.displayName,
                percent: Int(((rates[style] ?? 0) * 100).rounded()),
                angle: .degrees(-90 + 360 / Double(topStyles.count) * Double(index))
            )
        }
    }

    var body: some View {
        let petals = self.petals
        if !petals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Style breakdown")
                wheel(petals)
                    .frame(width: Self.chartSize, height: Self.chartSize)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func wheel(_ petals: [Petal]) -> some View {
        let sliceAngle = Angle.degrees(360 / Double(petals.count))
        return ZStack {
            ForEach(petals) { petal in
                PetalWedgeShape(
                    centerAngle: petal.angle, sliceAngle: sliceAngle,
                    innerRadius: Self.holeRadius, outerRadius: Self.outerRadius,
                    cornerRadius: 16
                )
                .fill(palette.surfaceSunken)
            }
            ForEach(petals) { petal in
                PetalWedgeShape(
                    centerAngle: petal.angle, sliceAngle: sliceAngle,
                    innerRadius: Self.holeRadius + Self.valueInset,
                    outerRadius: valueRadius(for: petal.percent),
                    gapAngle: .degrees(6), cornerRadius: 12
                )
                .fill(ThemePalette.accent.opacity(0.35 + Double(petal.percent) / 100 * 0.65))
            }
            ForEach(petals) { petal in
                petalLabel(petal)
            }
        }
    }

    private func valueRadius(for percent: Int) -> CGFloat {
        let floorRadius = Self.holeRadius + Self.valueInset + Self.minValueDepth
        let ceilingRadius = Self.outerRadius - Self.labelBandDepth
        return floorRadius + CGFloat(percent) / 100 * (ceilingRadius - floorRadius)
    }

    private func petalLabel(_ petal: Petal) -> some View {
        let textRadius = Self.outerRadius - Self.labelBandDepth / 2 - 3
        return VStack(spacing: 0) {
            Text("\(petal.percent)%")
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
            Text(petal.label)
                .font(.system(size: 10))
                .foregroundStyle(palette.textDim)
        }
        .position(polarPoint(radius: textRadius, angle: petal.angle))
    }

    private func polarPoint(radius: CGFloat, angle: Angle) -> CGPoint {
        let center = Self.chartSize / 2
        return CGPoint(
            x: center + radius * cos(angle.radians),
            y: center + radius * sin(angle.radians)
        )
    }
}
