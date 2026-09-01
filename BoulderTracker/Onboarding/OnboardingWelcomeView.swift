import SwiftUI

struct OnboardingWelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onStart: () -> Void

    @State private var revealed = false

    var body: some View {
        ZStack {
            OnboardingWallView(revealed: revealed, reduceMotion: reduceMotion)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Text("BOULDER")
                    Text("TRACKER")
                }
                .font(.system(size: 54, weight: .black, design: .rounded))
                .tracking(-2.2)
                .foregroundStyle(Color(hex: 0x121212))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text("Track every send.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.58))
                    .padding(.top, 16)

                Spacer()

                Button(action: onStart) {
                    HStack {
                        Text("Get started")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 64)
                    .background(Color(hex: 0x121212), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 9)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.getStarted")
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 22)
        }
        .onAppear { revealed = true }
    }
}
