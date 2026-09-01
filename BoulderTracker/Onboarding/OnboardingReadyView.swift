import SwiftUI

struct OnboardingReadyView: View {
    let name: String
    let gymName: String
    let shoeName: String
    let isSaving: Bool
    let errorMessage: String?
    let onFinish: () -> Void

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "ALL SET",
            title: "Ready to climb, \(name)?",
            subtitle: "Your setup is ready. Time to log the next send."
        ) {
            VStack(spacing: 12) {
                summaryRow(icon: "mappin.and.ellipse", label: "Default gym", value: gymName)
                if !shoeName.isEmpty {
                    summaryRow(icon: "shoe", label: "Shoes", value: shoeName)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ThemePalette.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                Button(action: onFinish) {
                    HStack(spacing: 10) {
                        if isSaving { ProgressView().tint(.black) }
                        Text(isSaving ? "Finishing setup…" : errorMessage == nil ? "Start climbing" : "Retry")
                        if !isSaving { Image(systemName: "arrow.up.right") }
                    }
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(ThemePalette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(ThemePalette.accent, in: Capsule())
                    .shadow(color: ThemePalette.accent.opacity(0.35), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .padding(.top, 16)
                .accessibilityIdentifier("onboarding.finish")
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.05), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(ThemePalette.light.textDim)
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemePalette.light.text)
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20))
    }
}
