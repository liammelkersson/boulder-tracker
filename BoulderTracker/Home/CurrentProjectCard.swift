import SwiftUI
import SwiftData

struct CurrentProjectCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Query private var projects: [Project]

    @State private var showingProjects = false

    private var project: Project? {
        ProjectSelection.current(from: projects)
    }

    var body: some View {
        Button {
            showingProjects = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current Project")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(palette.textFaint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(palette.textFaint)
                }
                if let project {
                    HStack(spacing: 12) {
                        HoldIcon(grade: project.colorGrade, size: 44)
                        projectDescription(project)
                    }
                } else {
                    Text("No active project — tap to add one")
                        .scaledFont(size: 13)
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
            ProjectsSheet()
        }
    }

    private func projectDescription(_ project: Project) -> some View {
        let sessionCount = ProjectStats(project: project).sessionCount
        let sessionsLabel = sessionCount == 1
            ? "1 session on this problem"
            : "\(sessionCount) sessions on this problem"
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(project.colorGrade.detailLabel(in: gradeSystem)) · \u{201C}\(project.name)\u{201D}")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(palette.text)
            Text("\(project.gym?.name ?? "Unknown gym") · \(sessionsLabel)")
                .scaledFont(size: 13)
                .foregroundStyle(palette.textDim)
        }
    }
}
