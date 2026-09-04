import SwiftUI
import SwiftData

struct RootTabView: View {
    @AppStorage(AppPreferences.darkModeKey) private var darkModeEnabled = true
    @AppStorage(AppPreferences.gradeSystemKey) private var gradeSystem = GradeSystem.default
    @Query private var sessions: [Session]
    @State private var selectedTab: AppTab = .climb
    @State private var showingGymPicker = false

    private var palette: ThemePalette { darkModeEnabled ? .dark : .light }

    private var hasLiveSession: Bool {
        sessions.persisted.contains { $0.isLive }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.label, systemImage: tab.symbolName, value: tab) {
                    screen(for: tab)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.palette, palette)
        .environment(\.gradeSystem, gradeSystem)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .tint(palette.accentText)
        .onChange(of: selectedTab) { previousTab, newTab in
            guard newTab.isAction else { return }
            selectedTab = previousTab.isAction ? .climb : previousTab
            startOrResumeSession()
        }
        .sheet(isPresented: $showingGymPicker) { GymPickerSheet() }
    }

    /// The live session lives on the Climb tab, so an in-progress session just
    /// switches there instead of asking for a gym again.
    private func startOrResumeSession() {
        if hasLiveSession {
            selectedTab = .climb
        } else {
            showingGymPicker = true
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        ZStack {
            palette.background.ignoresSafeArea()
            WallTexture().ignoresSafeArea()
            switch tab {
            case .climb: HomeView()
            case .activities: ActivitiesView()
            // Never shown: selecting it bounces back to the previous tab.
            case .startSession: Color.clear
            case .profile: ProfileView()
            }
        }
    }
}
