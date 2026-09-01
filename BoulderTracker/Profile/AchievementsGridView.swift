import SwiftUI
import SwiftData

struct AchievementsGridView: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Session.startTime) private var sessions: [Session]
    @Query private var unlockedRecords: [Achievement]
    let onClose: () -> Void

    private static let holdColors: [Color] = [
        Color(hex: 0x14A876), Color(hex: 0x3B63EC), Color(hex: 0xE5473B), Color(hex: 0xE7B23C),
        Color(hex: 0xE8792E), Color(hex: 0x9B5DE0), Color(hex: 0xE85DA0), Color(hex: 0x8FD14F),
    ]
    private static let shapeGrades: [ColorGrade] = [.green, .blue, .red, .black, .white, .yellow]

    private var finishedSessions: [Session] { sessions.persisted.filter { !$0.isLive } }
    private var unlockedIDs: Set<String> { Set(unlockedRecords.map(\.achievementID)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(AchievementEngine.definitions.enumerated()), id: \.element.id) {
                        index, definition in
                        achievementCard(definition, index: index)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(palette.text)
                    .frame(width: 32, height: 32)
                    .background(palette.surface)
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Text("Achievements")
                .scaledFont(size: 20, weight: .bold)
                .foregroundStyle(palette.text)
        }
    }

    private func achievementCard(_ definition: AchievementDefinition, index: Int) -> some View {
        let isUnlocked = unlockedIDs.contains(definition.id)
            || definition.isSatisfied(by: finishedSessions)
        let holdColor = Self.holdColors[index % Self.holdColors.count]
        let shapeGrade = Self.shapeGrades[index % Self.shapeGrades.count]
        return VStack(spacing: 8) {
            achievementHold(
                definition, isUnlocked: isUnlocked, holdColor: holdColor, shapeGrade: shapeGrade
            )
            Text(definition.title)
                .scaledFont(size: 15, weight: .bold)
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            Text(definition.detail)
                .scaledFont(size: 13)
                .foregroundStyle(palette.textFaint)
                .multilineTextAlignment(.center)
            statusChip(definition, isUnlocked: isUnlocked)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 20)
        .background(isUnlocked ? palette.surface : palette.surfaceSunken)
        .clipShape(.rect(cornerRadius: 18))
    }

    private func achievementHold(_ definition: AchievementDefinition, isUnlocked: Bool,
                                 holdColor: Color, shapeGrade: ColorGrade) -> some View {
        HoldIcon(
            grade: shapeGrade, size: 52,
            baseColorOverride: isUnlocked ? holdColor : palette.trackOff
        )
        .opacity(isUnlocked ? 1 : 0.4)
        .overlay(alignment: .bottomTrailing) {
            Text("\(definition.target)")
                .scaledFont(size: 12, weight: .heavy)
                .foregroundStyle(isUnlocked ? holdColor : palette.textFaint)
                .frame(width: 24, height: 24)
                .background(.white)
                .clipShape(.circle)
                .offset(x: 5, y: 5)
        }
    }

    @ViewBuilder
    private func statusChip(_ definition: AchievementDefinition, isUnlocked: Bool) -> some View {
        if isUnlocked {
            Text("Unlocked")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(ThemePalette.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(ThemePalette.success.opacity(0.16))
                .clipShape(.capsule)
        } else {
            let percent = Int((definition.progressFraction(in: finishedSessions) * 100).rounded())
            Text("\(percent)%")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(palette.textFaint)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(palette.pill)
                .clipShape(.capsule)
        }
    }
}
