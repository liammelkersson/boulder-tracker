import SwiftUI

/// The fundamentals chips on the problem form. Tagging is optional: a quick log
/// never passes through here, so an untagged problem stays untagged.
struct SkillChipsPicker: View {
    @Binding var selection: Set<MovementSkill>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(MovementSkill.allCases) { skill in
                SelectablePill(
                    title: skill.displayName,
                    isSelected: selection.contains(skill)
                ) {
                    toggleSkill(skill)
                }
            }
        }
    }

    private func toggleSkill(_ skill: MovementSkill) {
        if selection.contains(skill) {
            selection.remove(skill)
        } else {
            selection.insert(skill)
        }
    }
}
