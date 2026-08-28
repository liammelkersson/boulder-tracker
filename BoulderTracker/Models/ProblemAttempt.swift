import Foundation
import SwiftData

@Model
final class ProblemAttempt {
    var colorGrade: ColorGrade
    var styles: [RouteStyle]
    var attemptCount: Int
    var result: AttemptResult
    var photoFilename: String?
    var notes: String?
    var session: Session?

    init(colorGrade: ColorGrade, styles: [RouteStyle], attemptCount: Int, result: AttemptResult) {
        self.colorGrade = colorGrade
        self.styles = styles
        self.attemptCount = attemptCount
        self.result = result
    }
}
