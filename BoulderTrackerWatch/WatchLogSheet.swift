import SwiftUI

struct WatchLogSheet: View {
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
                Text(option.displayName)
            }
        }
        .navigationTitle("Grade")
    }

    private func resultList(for grade: ColorGrade) -> some View {
        List(AttemptResult.allCases) { result in
            Button(result.displayName) { onLog(grade, result) }
        }
        .navigationTitle(grade.displayName)
    }
}
