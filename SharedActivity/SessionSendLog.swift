import Foundation

/// How `LogSendIntent` reaches the store.
///
/// The intent is compiled into the widget extension as well as the app, and
/// the extension has no SwiftData container — so the intent cannot name a
/// store-backed type. It resolves this protocol instead, and only the app ever
/// registers a conformer.
@MainActor
protocol SessionSendLogging: AnyObject {
    func logSend(grade: ColorGrade)
}

/// A global, deliberately: App Intents are handed no environment and no
/// initializer arguments, so there is nowhere else for the app to put the
/// writer. In the extension it simply stays nil, which is correct — the intent
/// performs in the app's process.
@MainActor
enum SessionSendLog {
    static weak var writer: (any SessionSendLogging)?
}
