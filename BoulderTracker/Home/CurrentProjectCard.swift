import SwiftUI

struct CurrentProjectCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @AppStorage(AppPreferences.currentProjectNameKey) private var currentProjectName = ""
    let sessions: [Session]

    @State private var showingProjects = false

    private var project: ProjectGroup? {
        ProjectAggregator.currentProject(
            in: sessions.persisted,
            preferredName: currentProjectName.isEmpty ? nil : currentProjectName
        )
    }

    var body: some View {
        Button {
            showingProjects = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current Project")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textFaint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textFaint)
                }
                if let project {
                    HStack(spacing: 12) {
                        HoldIcon(grade: project.grade, size: 44)
                        projectDescription(project)
                    }
                } else {
                    Text("No active project — long-press a problem to mark one")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .themedCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProjects) {
            ProjectsSheet(sessions: sessions)
        }
    }

    private func projectDescription(_ project: ProjectGroup) -> some View {
        let sessionsLabel = project.sessionCount == 1
            ? "1 session on this problem"
            : "\(project.sessionCount) sessions on this problem"
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(project.grade.detailLabel(in: gradeSystem)) · \u{201C}\(project.name)\u{201D}")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("\(project.gymName ?? "Unknown gym") · \(sessionsLabel)")
                .font(.system(size: 13))
                .foregroundStyle(palette.textDim)
        }
    }
}
