import SwiftUI

struct RootTabView: View {
    @AppStorage(AppPreferences.darkModeKey) private var darkModeEnabled = true
    @State private var selectedTab: AppTab = .climb

    private var palette: ThemePalette { darkModeEnabled ? .dark : .light }

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
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .tint(palette.accentText)
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        ZStack {
            palette.background.ignoresSafeArea()
            WallTexture().ignoresSafeArea()
            switch tab {
            case .climb: HomeView()
            case .activities: ActivitiesView()
            case .stats: StatsView()
            case .profile: ProfileView()
            }
        }
    }
}
