import SwiftUI

/// The route-style chips, shared by the problem form and the project editor so
/// both offer the same set and the same toggle behaviour.
struct StyleChipsPicker: View {
    @Binding var selection: Set<RouteStyle>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(RouteStyle.allCases) { style in
                SelectablePill(
                    title: style.displayName,
                    isSelected: selection.contains(style)
                ) {
                    toggleStyle(style)
                }
            }
        }
    }

    private func toggleStyle(_ style: RouteStyle) {
        if selection.contains(style) {
            selection.remove(style)
        } else {
            selection.insert(style)
        }
    }
}
