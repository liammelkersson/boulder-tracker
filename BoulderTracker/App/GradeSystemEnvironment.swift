import SwiftUI

private struct GradeSystemKey: EnvironmentKey {
    static let defaultValue = GradeSystem.default
}

extension EnvironmentValues {
    var gradeSystem: GradeSystem {
        get { self[GradeSystemKey.self] }
        set { self[GradeSystemKey.self] = newValue }
    }
}
