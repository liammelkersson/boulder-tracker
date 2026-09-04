import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.palette) private var palette
    @AppStorage(AppPreferences.profileNameKey)
    private var profileName = AppPreferences.defaultProfileName
    @AppStorage(AppPreferences.climbingSinceYearKey)
    private var climbingSinceYear = AppPreferences.defaultClimbingSinceYear
    @AppStorage(AppPreferences.avatarFilenameKey) private var avatarFilename = ""

    private static let photoStore = PhotoStore.makeDefault()

    @State private var showingAchievements = false
    @State private var showingEditProfile = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingAchievements {
                AchievementsGridView { showingAchievements = false }
            } else {
                mainContent
            }
        }
        .sheet(isPresented: $showingEditProfile) { EditProfileSheet() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                profileHeader
                achievementsRow
                StatsSection()
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
            headerActions
        }
    }

    private var headerActions: some View {
        HStack(spacing: 14) {
            Button {
                showingEditProfile = true
            } label: {
                Text("Edit")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(palette.textDim)
            }
            .buttonStyle(.plain)
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(palette.textDim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
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

    private var achievementsRow: some View {
        Button {
            showingAchievements = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "medal")
                    .scaledFont(size: 17, weight: .semibold)
                Text("Achievements")
                    .scaledFont(size: 15, weight: .semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(palette.textFaint)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .themedCard()
        }
        .buttonStyle(.plain)
    }
}
