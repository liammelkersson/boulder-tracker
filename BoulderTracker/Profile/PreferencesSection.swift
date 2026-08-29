import SwiftUI

struct PreferencesSection: View {
    @Environment(\.palette) private var palette
    @AppStorage(AppPreferences.darkModeKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.healthKitSyncKey) private var healthKitSyncEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Preferences")
            VStack(spacing: 0) {
                preferenceRow(title: "Dark mode", isOn: $darkModeEnabled, isLast: false)
                preferenceRow(title: "HealthKit sync", isOn: $healthKitSyncEnabled, isLast: true)
            }
            .themedCard()
        }
    }

    private func preferenceRow(title: String, isOn: Binding<Bool>, isLast: Bool) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 15))
            .foregroundStyle(palette.text)
            .tint(ThemePalette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
                }
            }
    }
}
