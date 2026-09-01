import SwiftUI
import SwiftData

struct ProblemTile: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    let problem: SessionProblem

    @State private var confirmingDelete = false

    var body: some View {
        // Delete Problem removes this row's model; the final body evaluation
        // after that must not touch persisted properties.
        if problem.isInvalidated {
            Color.clear
        } else {
            tileContent
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                HoldIcon(grade: problem.colorGrade, size: 34)
                problemInfo
            }
            notesFootnote
            resultButtons
                .padding(.top, 10)
        }
        .padding(14)
        .themedCard(sunken: true)
        .contextMenu {
            Button {
                problem.isProject.toggle()
                modelContext.saveReportingFailure(operation: "project mark toggle")
            } label: {
                Label(
                    problem.isProject ? "Remove project mark" : "Mark as project",
                    systemImage: problem.isProject ? "flag.slash" : "flag"
                )
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete Problem", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete this problem?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Problem", role: .destructive, action: deleteProblem)
        } message: {
            Text("Removes the problem, its logs, and its photo. Cannot be undone.")
        }
    }

    private func deleteProblem() {
        if let filename = problem.photoFilename {
            try? PhotoStore.makeDefault().deletePhoto(named: filename)
        }
        modelContext.delete(problem)
        modelContext.saveReportingFailure(operation: "problem delete")
    }

    private var problemInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(problem.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                if problem.isProject {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.accentText)
                }
            }
            Text(gradeAndGymLabel)
                .font(.system(size: 13))
                .foregroundStyle(palette.textFaint)
            if !problem.styles.isEmpty {
                Text(problem.styles.map(\.displayName).joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, 2)
            }
        }
    }

    private var gradeAndGymLabel: String {
        let grade = problem.colorGrade
        var label = grade.detailLabel(in: gradeSystem)
        if let gymName = problem.session?.gym?.name {
            label += " · \(gymName)"
        }
        return label
    }

    @ViewBuilder
    private var notesFootnote: some View {
        if let notes = problem.notes, !notes.isEmpty {
            Text(notes)
                .font(.system(size: 12))
                .foregroundStyle(palette.textDim)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle().fill(palette.border.opacity(0.06)).frame(height: 0.5)
                }
        }
    }

    /// Mockup button order: Flash, Fall, Send.
    private static let buttonOrder: [AttemptResult] = [.flash, .fall, .send]

    private var resultButtons: some View {
        HStack(spacing: 8) {
            ForEach(Self.buttonOrder) { result in
                resultButton(result)
            }
        }
    }

    private func resultButton(_ result: AttemptResult) -> some View {
        Button {
            problem.recordResult(result)
            if let session = problem.session {
                syncCoordinator.announceAttempt(on: problem, in: session, result: result)
            }
            modelContext.saveReportingFailure(operation: "attempt log")
        } label: {
            HStack(spacing: 6) {
                Text(result.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(titleColor(for: result))
                Text("\(problem.logCount(for: result))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(palette.pill)
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                if result == .flash && problem.totalLogs == 0 {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: 0x14A876), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func titleColor(for result: AttemptResult) -> Color {
        switch result {
        case .flash: Color(hex: 0x14A876)
        case .send: ThemePalette.accent
        case .fall: palette.textDim
        }
    }
}
