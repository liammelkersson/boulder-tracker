import SwiftUI

/// Wrapping multi-select chips over any tag set — route styles, fundamentals —
/// so every tag field on a form offers the same toggle behaviour.
struct SelectableChipsPicker<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Set<Option>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                SelectablePill(
                    title: title(option),
                    isSelected: selection.contains(option)
                ) {
                    toggleSelection(option)
                }
            }
        }
    }

    private func toggleSelection(_ option: Option) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}
