import Foundation

/// The rule behind quick logging: one unnamed problem per grade per session
/// accumulates every quick log for that grade. The in-app pills and the Lock
/// Screen buttons both go through here, so they can never disagree about which
/// problem a send lands on.
enum QuickLogEntry {
    static func problem(for grade: ColorGrade, in session: Session) -> SessionProblem {
        if let existing = session.problems.first(where: {
            $0.name.isEmpty && $0.colorGrade == grade
        }) {
            return existing
        }
        let problem = SessionProblem(name: "", colorGrade: grade, styles: [])
        session.problems.append(problem)
        return problem
    }
}
