import SwiftUI

/// Everything that configures the app: gyms, partners, shoes, preferences,
/// data export, and the onboarding replay. Profile shows who you are; this
/// shows how the app behaves.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.onboardingCompleteKey) private var onboardingComplete = false

    @State private var showingGrades = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            WallTexture().ignoresSafeArea()
            settingsList
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingGrades) { GradesSheet() }
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .scaledFont(size: 24, weight: .bold)
                    .foregroundStyle(palette.text)
                GymListSection()
                PartnerListSection()
                ShoeListSection()
                PreferencesSection()
                gradeReferenceRow
                SessionExportRow()
                replayOnboardingRow
                SampleDataToggleRow()
                versionFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
    }

    private var gradeReferenceRow: some View {
        Button {
            showingGrades = true
        } label: {
            navigationRowLabel(title: "Grade reference", systemName: "link")
        }
        .buttonStyle(.plain)
    }

    /// Replays the first-launch wizard. Dismissing first keeps this sheet from
    /// sitting on top of the wizard the root view swaps in.
    private var replayOnboardingRow: some View {
        Button {
            dismiss()
            onboardingComplete = false
        } label: {
            navigationRowLabel(title: "Replay onboarding", systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.plain)
    }

    private func navigationRowLabel(title: String, systemName: String) -> some View {
        HStack {
            Text(title)
                .scaledFont(size: 15)
                .foregroundStyle(palette.text)
            Spacer()
            Image(systemName: systemName)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(palette.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .themedCard()
    }

    private var versionFooter: some View {
        Text("Boulder Tracker v\(appVersion)")
            .scaledFont(size: 12)
            .foregroundStyle(palette.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
