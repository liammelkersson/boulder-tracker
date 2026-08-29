import SwiftUI

struct WatchStartView: View {
    let gyms: [GymSnapshot]
    let onStart: (String?, ClimbType) -> Void

    @State private var climbType: ClimbType = .bouldering

    var body: some View {
        List {
            Section("Type") {
                Picker("Type", selection: $climbType) {
                    ForEach(ClimbType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            Section("Gym") {
                ForEach(gyms, id: \.name) { gym in
                    Button(gym.name) { onStart(gym.name, climbType) }
                }
                Button("No gym") { onStart(nil, climbType) }
            }
        }
        .navigationTitle("Start")
    }
}
