import SwiftUI

struct WatchLogSheet: View {
    let gradeSystem: GradeSystem
    let onLog: (ColorGrade, AttemptResult) -> Void

    @State private var grade: ColorGrade?

    var body: some View {
        if let grade {
            resultList(for: grade)
        } else {
            gradeList
        }
    }

    private var gradeList: some View {
        List(ColorGrade.displayOrder) { option in
            Button {
                grade = option
            } label: {
                HStack(spacing: 7) {
                    WatchGradeDot(grade: option)
                    Text(option.shortLabel(in: gradeSystem))
                }
            }
        }
        .navigationTitle("Grade")
    }

    private func resultList(for grade: ColorGrade) -> some View {
        List(AttemptResult.allCases) { result in
            Button(result.displayName) { onLog(grade, result) }
        }
        .navigationTitle(grade.shortLabel(in: gradeSystem))
    }
}
