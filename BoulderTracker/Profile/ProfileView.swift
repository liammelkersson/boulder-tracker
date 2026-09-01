import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.palette) private var palette
    @AppStorage(AppPreferences.profileNameKey)
    private var profileName = AppPreferences.defaultProfileName
    @AppStorage(AppPreferences.climbingSinceYearKey)
    private var climbingSinceYear = AppPreferences.defaultClimbingSinceYear
    @AppStorage(AppPreferences.avatarFilenameKey) private var avatarFilename = ""
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    private static let photoStore = PhotoStore.makeDefault()

    @State private var showingAchievements = false
    @State private var showingGrades = false
    @State private var showingEditProfile = false
    @State private var exportFile: ExportFile?

    var body: some View {
        Group {
            if showingAchievements {
                AchievementsGridView { showingAchievements = false }
            } else {
                mainContent
            }
        }
        .sheet(isPresented: $showingGrades) { GradesSheet() }
        .sheet(isPresented: $showingEditProfile) { EditProfileSheet() }
        .sheet(item: $exportFile) { file in ShareSheetView(url: file.url) }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                profileHeader
                quickActions
                GymListSection()
                PartnerListSection()
                ShoeListSection()
                PreferencesSection()
                versionFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(profileName)
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundStyle(palette.text)
                Text("Climbing since \(climbingSinceYear)")
                    .scaledFont(size: 13)
                    .foregroundStyle(palette.textDim)
            }
            Spacer()
            Button {
                showingEditProfile = true
            } label: {
                HStack(spacing: 2) {
                    Text("Edit")
                    Image(systemName: "chevron.right").scaledFont(size: 11, weight: .semibold)
                }
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(palette.textDim)
            }
            .buttonStyle(.plain)
        }
    }

    private var avatar: some View {
        Group {
            if let image = avatarImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(profileName.prefix(1).uppercased())
                    .scaledFont(size: 26, weight: .bold)
                    .foregroundStyle(ThemePalette.onAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ThemePalette.accent)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(.circle)
    }

    private func avatarImage() -> UIImage? {
        guard !avatarFilename.isEmpty,
              let data = Self.photoStore.loadPhoto(named: avatarFilename) else { return nil }
        return UIImage(data: data)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction(title: "Achievements", systemName: "medal") {
                showingAchievements = true
            }
            quickAction(title: "Export Data", systemName: "square.and.arrow.up") {
                exportSessions()
            }
            quickAction(title: "Grades", systemName: "link") {
                showingGrades = true
            }
        }
    }

    private func quickAction(title: String, systemName: String,
                             onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Image(systemName: systemName)
                    .scaledFont(size: 17, weight: .semibold)
                Text(title)
                    .scaledFont(size: 12, weight: .semibold)
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .themedCard()
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var versionFooter: some View {
        Text("Boulder Tracker v\(appVersion)")
            .scaledFont(size: 12)
            .foregroundStyle(palette.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func exportSessions() {
        let finished = sessions.persisted.filter { !$0.isLive && !$0.isSampleData }
        guard let url = try? SessionDataExport.writeJSONFile(for: finished) else { return }
        exportFile = ExportFile(url: url)
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
