import SwiftUI

/// All projects — marked problems plus recurring unsent ones.
struct ProjectsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @AppStorage(AppPreferences.currentProjectNameKey) private var currentProjectName = ""
    let sessions: [Session]

    private var projects: [ProjectGroup] {
        ProjectAggregator.groups(in: sessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Projects")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.text)
                if projects.isEmpty {
                    Text("No projects yet. Mark a problem as a project when adding it, or long-press a problem tile during a session.")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textDim)
                        .padding(.top, 8)
                }
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func projectRow(_ project: ProjectGroup) -> some View {
        let isCurrent = !project.wasSent && project.name == currentProjectName
        return HStack(spacing: 12) {
            HoldIcon(grade: project.grade, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(projectSubtitle(project))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
            Spacer()
            trailingControl(project, isCurrent: isCurrent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .themedCard(cornerRadius: 16, sunken: true)
    }

    private func projectSubtitle(_ project: ProjectGroup) -> String {
        let sessionsLabel = project.sessionCount == 1 ? "1 session" : "\(project.sessionCount) sessions"
        return "\(project.grade.shortLabel(in: gradeSystem)) · \(project.gymName ?? "Unknown gym") · \(sessionsLabel)"
    }

    @ViewBuilder
    private func trailingControl(_ project: ProjectGroup, isCurrent: Bool) -> some View {
        if project.wasSent {
            statusChip(text: "Sent", color: Color(hex: 0x14A876))
        } else if isCurrent {
            statusChip(text: "Current", color: palette.accentText)
        } else {
            Button {
                currentProjectName = project.name
            } label: {
                Text("Set current")
                    .font(.system(size: 12, weight: .semibold))
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .clipShape(.capsule)
    }
}
