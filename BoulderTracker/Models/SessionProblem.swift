import Foundation
import SwiftData

// Defaults on every attribute keep the model CloudKit-compatible.
@Model
final class SessionProblem {
    var name: String = ""
    var colorGrade: ColorGrade = ColorGrade.unknown
    var styles: [RouteStyle] = []
    var flashCount: Int = 0
    var sendCount: Int = 0
    var fallCount: Int = 0
    var notes: String?
    var photoFilename: String?
    /// Legacy flag, read only by `ProjectBackfill`. Kept in the schema until
    /// every device has migrated to `project`; deleting an attribute while
    /// older peers still sync the old CloudKit schema drops their writes.
    var isProject: Bool = false
    /// Stable identity across devices; see the note on `Session.syncID`.
    var syncID: UUID?
    var session: Session?
    var project: Project?

    init(name: String, colorGrade: ColorGrade, styles: [RouteStyle],
         flashCount: Int = 0, sendCount: Int = 0, fallCount: Int = 0,
         isProject: Bool = false) {
        self.name = name
        self.colorGrade = colorGrade
        self.styles = styles
        self.flashCount = flashCount
        self.sendCount = sendCount
        self.fallCount = fallCount
        self.isProject = isProject
        self.syncID = UUID()
    }

    /// Quick-logged problems have no name; show a generic label.
    var displayName: String { name.isEmpty ? "Quick log" : name }

    var wasSent: Bool { flashCount + sendCount > 0 }

    var wasFlashed: Bool { flashCount > 0 }

    var totalLogs: Int { flashCount + sendCount + fallCount }

    func recordResult(_ result: AttemptResult) {
        switch result {
        case .flash: flashCount += 1
        case .send: sendCount += 1
        case .fall: fallCount += 1
        }
        if result.countsAsSend { project?.markSentIfActive() }
    }

    func logCount(for result: AttemptResult) -> Int {
        switch result {
        case .flash: flashCount
        case .send: sendCount
        case .fall: fallCount
        }
    }
}
