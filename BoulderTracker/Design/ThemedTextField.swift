import SwiftUI

struct ThemedTextField: View {
    @Environment(\.palette) private var palette
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(palette.textFaint))
            .scaledFont(size: 14)
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.pill)
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(palette.border.opacity(0.08), lineWidth: 1)
            }
    }
}
