import SwiftUI

/// One style in the coverage card: filled once the period has touched it,
/// muted while it is still untried.
struct StyleCoverageChip: View {
    @Environment(\.palette) private var palette
    let style: RouteStyle
    let isTried: Bool

    private static let textSize: CGFloat = 12
    private static let leadingPadding: CGFloat = 10
    private static let verticalPadding: CGFloat = 5

    var body: some View {
        Text(style.displayName)
            .scaledFont(size: Self.textSize, weight: isTried ? .semibold : .regular)
            .foregroundStyle(isTried ? ThemePalette.onAccent : palette.textFaint)
            .padding(.horizontal, Self.leadingPadding)
            .padding(.vertical, Self.verticalPadding)
            .background(isTried ? ThemePalette.accent : palette.pill)
            .clipShape(.capsule)
    }
}
