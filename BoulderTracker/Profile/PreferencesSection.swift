import SwiftUI

struct PreferencesSection: View {
    @Environment(\.palette) private var palette
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @AppStorage(AppPreferences.darkModeKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.healthKitSyncKey) private var healthKitSyncEnabled = true
    @AppStorage(AppPreferences.gradeSystemKey) private var gradeSystem = GradeSystem.default

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Preferences")
            VStack(spacing: 0) {
                preferenceRow(title: "Dark mode", isOn: $darkModeEnabled)
                preferenceRow(title: "HealthKit sync", isOn: $healthKitSyncEnabled)
                gradeSystemRow
            }
            .themedCard()
        }
        // The watch only asks for the catalog at cold start; push changes.
        .onChange(of: gradeSystem) { syncCoordinator.publishCatalog() }
        .onChange(of: healthKitSyncEnabled) { syncCoordinator.publishCatalog() }
    }

    private var gradeSystemRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Grade system")
                .scaledFont(size: 15)
                .foregroundStyle(palette.text)
            Picker("Grade system", selection: $gradeSystem) {
                ForEach(GradeSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(ThemePalette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// The grade-system row always closes the card, so every toggle row
    /// draws a trailing divider.
    private func preferenceRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .scaledFont(size: 15)
            .foregroundStyle(palette.text)
            .tint(ThemePalette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
            }
    }
}
