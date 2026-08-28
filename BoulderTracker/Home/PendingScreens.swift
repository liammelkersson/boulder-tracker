import SwiftUI
import SwiftData

// Placeholders replaced by Tasks 10-12. Delete each when the real view lands.
struct LiveSessionView: View {
    let session: Session
    var body: some View { Text("Session in progress") }
}

struct RetroSessionForm: View {
    var body: some View { Text("Retro form") }
}

struct SessionDetailView: View {
    let sessionID: PersistentIdentifier
    var body: some View { Text("Session detail") }
}
