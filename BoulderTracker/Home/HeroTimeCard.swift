import SwiftUI

struct HeroTimeCard: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private var summary: StatsSummary { StatsAggregator.summary(of: sessions) }
    private var currentGrade: ColorGrade? { StatsAggregator.hardestSend(of: sessions)?.colorGrade }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Time on the wall · 3 months")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textDim)
                Text(SessionDurationFormat.compactString(from: summary.totalDuration))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(palette.text)
                    .padding(.top, 8)
                currentGradeRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let currentGrade {
                GradeBadge(grade: currentGrade)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(heroGradient)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(palette.border.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var currentGradeRow: some View {
        if let currentGrade {
            HStack(spacing: 4) {
                Text("Currently climbing")
                    .foregroundStyle(palette.textDim)
                Text("\(currentGrade.displayName) · \(currentGrade.frenchRange)")
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
            }
            .font(.system(size: 13))
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.border.opacity(0.1)).frame(height: 1)
            }
        }
    }

    private var heroGradient: LinearGradient {
        let tint = (currentGrade ?? .blue).displayColor
        let baseTop = palette.isDark ? Color(hex: 0x14151C) : Color(hex: 0xF5EEE2)
        let baseBottom = palette.isDark ? Color(hex: 0x0A0B12) : Color(hex: 0xEAE0CE)
        return LinearGradient(
            colors: [baseTop.mix(with: tint, by: 0.32), baseBottom.mix(with: tint, by: 0.16)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
