import SwiftUI
import SwiftData

/// Every stored project, grouped by lifecycle, with add / edit / pin controls.
struct ProjectsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @State private var editingProject: Project?
    @State private var isAddingProject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if projects.persisted.isEmpty {
                    emptyState
                }
                ForEach(ProjectStatus.allCases) { status in
                    section(for: status)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editingProject) { project in
            ProjectEditorSheet(project: project)
        }
        .sheet(isPresented: $isAddingProject) {
            ProjectEditorSheet(project: nil)
        }
    }

    private var header: some View {
        HStack {
            Text("Projects")
                .scaledFont(size: 18, weight: .bold)
                .foregroundStyle(palette.text)
            Spacer()
            Button {
                isAddingProject = true
            } label: {
                Text("+ Add")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(palette.accentText)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        Text("No projects yet. Add one here, or mark a problem as a project while logging a session.")
            .scaledFont(size: 14)
            .foregroundStyle(palette.textDim)
    }

    @ViewBuilder
    private func section(for status: ProjectStatus) -> some View {
        let matching = projectsSorted(withStatus: status)
        if !matching.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(title: status.displayName)
                ForEach(matching) { project in
                    projectRow(project)
                }
            }
        }
    }

    /// Most recently worked first; never-attempted projects sort by creation.
    private func projectsSorted(withStatus status: ProjectStatus) -> [Project] {
        projects.persisted
            .filter { $0.status == status }
            .sorted { lhs, rhs in
                let lhsDate = ProjectStats(project: lhs).lastAttemptDate ?? lhs.createdDate
                let rhsDate = ProjectStats(project: rhs).lastAttemptDate ?? rhs.createdDate
                return lhsDate > rhsDate
            }
    }

    private func projectRow(_ project: Project) -> some View {
        Button {
            editingProject = project
        } label: {
            HStack(spacing: 12) {
                HoldIcon(grade: project.colorGrade, size: 40)
                ProjectRowSummary(project: project)
                Spacer()
                trailingControl(project)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .themedCard(cornerRadius: 16, sunken: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trailingControl(_ project: Project) -> some View {
        switch project.status {
        case .sent:
            statusChip(text: "Sent", color: ThemePalette.success)
        case .archived:
            statusChip(text: "Archived", color: palette.textFaint)
        case .active where project.isCurrent:
            statusChip(text: "Current", color: palette.accentText)
        case .active:
            Button {
                ProjectSelection.makeCurrent(project, in: modelContext)
                modelContext.saveReportingFailure(operation: "set current project")
            } label: {
                Text("Set current")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(palette.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.pill)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .clipShape(.capsule)
    }
}

/// Name plus the grade / gym / session-count line under it.
private struct ProjectRowSummary: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(palette.text)
            Text(subtitle)
                .scaledFont(size: 12)
                .foregroundStyle(palette.textFaint)
            if !project.styles.isEmpty {
                Text(project.styles.map(\.displayName).joined(separator: ", "))
                    .scaledFont(size: 12)
                    .foregroundStyle(palette.textFaint)
            }
        }
    }

    private var subtitle: String {
        let sessionCount = ProjectStats(project: project).sessionCount
        let sessionsLabel = sessionCount == 1 ? "1 session" : "\(sessionCount) sessions"
        let gymLabel = project.gym?.name ?? "Unknown gym"
        return "\(project.colorGrade.shortLabel(in: gradeSystem)) · \(gymLabel) · \(sessionsLabel)"
    }
}
