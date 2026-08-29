import SwiftUI

struct StatTile: View {
    @Environment(\.palette) private var palette
    let valueText: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valueText)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .themedCard()
    }
}
