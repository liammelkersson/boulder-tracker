import SwiftUI

/// Radial "petal" chart of send rate per style, like the mockup's style breakdown.
struct StyleRadialChart: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let chartSize: CGFloat = 280
    private static let holeRadius: CGFloat = 22
    private static let minPetalLength: CGFloat = 56
    private static let maxPetalLength: CGFloat = 118
    private static let petalWidth: CGFloat = 58
    private static let maxPetals = 6

    private struct Petal: Identifiable {
        let id: RouteStyle
        let label: String
        let percent: Int
        let angle: Angle
    }

    private var petals: [Petal] {
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
                ZStack {
                    ForEach(petals) { petal in
                        petalShape(petal)
                        petalLabel(petal)
                    }
                }
                .frame(width: Self.chartSize, height: Self.chartSize)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func petalLength(for percent: Int) -> CGFloat {
        Self.minPetalLength
            + CGFloat(percent) / 100 * (Self.maxPetalLength - Self.minPetalLength)
    }

    private func petalShape(_ petal: Petal) -> some View {
        let length = petalLength(for: petal.percent)
        let midRadius = Self.holeRadius + length / 2
        let fillStrength = 0.25 + Double(petal.percent) / 100 * 0.75
        return UnevenRoundedRectangle(
            topLeadingRadius: Self.petalWidth / 2, bottomLeadingRadius: 10,
            bottomTrailingRadius: 10, topTrailingRadius: Self.petalWidth / 2
        )
        .fill(palette.surfaceSunken.mix(with: ThemePalette.accent, by: fillStrength))
        .frame(width: Self.petalWidth, height: length)
        .rotationEffect(petal.angle + .degrees(90))
        .position(polarPoint(radius: midRadius, angle: petal.angle))
    }

    private func petalLabel(_ petal: Petal) -> some View {
        let length = petalLength(for: petal.percent)
        let textRadius = Self.holeRadius + length - 26
        return VStack(spacing: 1) {
            Text("\(petal.percent)%")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.text)
            Text(petal.label)
                .font(.system(size: 11))
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
