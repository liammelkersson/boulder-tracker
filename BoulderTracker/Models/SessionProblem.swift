import Foundation
import SwiftData

@Model
final class SessionProblem {
    var name: String
    var colorGrade: ColorGrade
    var styles: [RouteStyle]
    var flashCount: Int
    var sendCount: Int
    var fallCount: Int
    var notes: String?
    var photoFilename: String?
    var isProject: Bool = false
    var session: Session?

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
    }

    func logCount(for result: AttemptResult) -> Int {
        switch result {
        case .flash: flashCount
        case .send: sendCount
        case .fall: fallCount
        }
    }
}
