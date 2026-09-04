import Foundation
import SwiftData

// Defaults on every attribute keep the model CloudKit-compatible; see the
// note at the top of `Session`.
@Model
final class Project {
    var name: String = ""
    var colorGrade: ColorGrade = ColorGrade.unknown
    var styles: [RouteStyle] = []
    var status: ProjectStatus = ProjectStatus.active
    var notes: String?
    var createdDate: Date = Date.now
    /// The one project pinned to the Home card. `ProjectSelection` is the
    /// only writer, so exactly one row carries it.
    var isCurrent: Bool = false
    var isSampleData: Bool = false
    var gym: Gym?
    /// Explicit inverse: CloudKit-backed stores require one on every
    /// relationship. Deleting a project nulls the link and leaves every
    /// logged attempt on its session.
    @Relationship(deleteRule: .nullify, inverse: \SessionProblem.project)
    var problems: [SessionProblem]? = []

    init(name: String, colorGrade: ColorGrade = .unknown, styles: [RouteStyle] = [],
         gym: Gym? = nil, status: ProjectStatus = .active, createdDate: Date = .now) {
        self.name = name
        self.colorGrade = colorGrade
        self.styles = styles
        self.gym = gym
        self.status = status
        self.createdDate = createdDate
    }

    /// A logged send completes the project. Sent and archived rows keep the
    /// status the user chose, so a repeat ascent never resurrects one.
    func markSentIfActive() {
        guard status == .active else { return }
        status = .sent
    }
}
