import SwiftUI

struct SectionHeading: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(palette.textFaint)
    }
}
