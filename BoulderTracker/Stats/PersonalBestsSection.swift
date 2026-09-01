import SwiftUI

struct PersonalBestsSection: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let sessions: [Session]

    private var bests: [(label: String, value: String, grade: ColorGrade?)] {
        let sessions = self.sessions.persisted
        var entries: [(String, String, ColorGrade?)] = []
        if let flash = StatsAggregator.hardestFlash(of: sessions) {
            entries.append(("Hardest flash", gradeLabel(flash.colorGrade), flash.colorGrade))
        }
        if let send = StatsAggregator.hardestSend(of: sessions) {
            entries.append(("Hardest send", gradeLabel(send.colorGrade), send.colorGrade))
        }
        let streak = StatsAggregator.weeklyStreak(
            of: sessions, calendar: .current, referenceDate: .now
        )
        if streak > 0 {
            entries.append(("Longest streak", streak == 1 ? "1 week" : "\(streak) weeks", nil))
        }
        return entries
    }

    private func gradeLabel(_ grade: ColorGrade) -> String {
        grade.detailLabel(in: gradeSystem)
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
                            if let grade = best.grade {
                                GradeDot(grade: grade, size: 10)
                            }
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
