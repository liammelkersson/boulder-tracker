import SwiftUI

struct StatsView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Stats")
                    .scaledFont(size: 30, weight: .bold)
                    .foregroundStyle(palette.text)
                StatsSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }
}
