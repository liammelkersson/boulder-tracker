import SwiftUI

enum AppTab: Hashable {
    case home, calendar, stats, roadmap, profile
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "figure.climbing", value: .home) {
                Text("Home")
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                Text("Calendar")
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                Text("Stats")
            }
            Tab("Roadmap", systemImage: "map", value: .roadmap) {
                Text("Roadmap")
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                Text("Profile")
            }
        }
    }
}
