import SwiftUI

struct ThemedCard: ViewModifier {
    @Environment(\.palette) private var palette
    var cornerRadius: CGFloat = 16
    var sunken = false

    func body(content: Content) -> some View {
        content
            .background(sunken ? palette.surfaceSunken : palette.surface)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(palette.border.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func themedCard(cornerRadius: CGFloat = 16, sunken: Bool = false) -> some View {
        modifier(ThemedCard(cornerRadius: cornerRadius, sunken: sunken))
    }
}
