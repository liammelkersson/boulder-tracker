import SwiftUI

struct AccentButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ThemePalette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ThemePalette.accent)
            .clipShape(.rect(cornerRadius: 18))
    }
}

struct SecondaryButtonLabel: View {
    @Environment(\.palette) private var palette
    let title: String
    var titleColor: Color?

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(titleColor ?? palette.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .themedCard(cornerRadius: 18)
    }
}
