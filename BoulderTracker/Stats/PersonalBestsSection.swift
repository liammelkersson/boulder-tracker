import SwiftUI

struct PersonalBestsSection: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private var bests: [(label: String, value: String)] {
        var entries: [(String, String)] = []
        if let flash = StatsAggregator.hardestFlash(of: sessions) {
            entries.append(("Hardest flash", gradeLabel(flash.colorGrade)))
        }
        if let send = StatsAggregator.hardestSend(of: sessions) {
            entries.append(("Hardest send", gradeLabel(send.colorGrade)))
        }
        let streak = StatsAggregator.weeklyStreak(
            of: sessions, calendar: .current, referenceDate: .now
        )
        if streak > 0 {
            entries.append(("Longest streak", streak == 1 ? "1 week" : "\(streak) weeks"))
        }
        return entries
    }

    private func gradeLabel(_ grade: ColorGrade) -> String {
        "\(grade.displayName) · \(grade.frenchRange)"
    }

    var body: some View {
        let bests = self.bests
        if !bests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(title: "Personal bests")
                VStack(spacing: 0) {
                    ForEach(bests, id: \.label) { best in
                        HStack {
                            Text(best.label)
                                .font(.system(size: 14))
                                .foregroundStyle(palette.textDim)
                            Spacer()
                            Text(best.value)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.text)
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
                        }
                    }
                }
            }
        }
    }
}
