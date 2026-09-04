import SwiftUI
import SwiftData

struct ProjectEditorSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var gyms: [Gym]
    /// `nil` creates a new project.
    let project: Project?

    @State private var name = ""
    @State private var selectedGrade: ColorGrade = .green
    @State private var selectedStyles: Set<RouteStyle> = []
    @State private var selectedGym: Gym?
    @State private var status: ProjectStatus = .active
    @State private var notes = ""
    @State private var confirmingDelete = false

    /// Natural order so "Wall 2" sorts before "Wall 10".
    private var sortedGyms: [Gym] {
        gyms.persisted.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(project == nil ? "Add Project" : "Edit Project")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundStyle(palette.text)
                field(label: "Name") {
                    ThemedTextField(placeholder: "e.g. Elektra", text: $name)
                }
                field(label: "Grade") { GradePicker(selection: $selectedGrade) }
                field(label: "Style") { StyleChipsPicker(selection: $selectedStyles) }
                field(label: "Gym") { gymPills }
                field(label: "Status") { statusPills }
                field(label: "Notes") {
                    ThemedNotesField(placeholder: "Beta, conditions, plans", text: $notes)
                }
                Button(action: saveProject) {
                    AccentButtonLabel(title: "Save")
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                if project != nil {
                    deleteButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete this project?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive, action: deleteProject)
        } message: {
            Text("Sessions keep every logged attempt; only the project is removed.")
        }
        .onAppear(perform: loadProject)
    }

    private func field(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: label)
            content()
        }
    }

    private var gymPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(sortedGyms) { gym in
                SelectablePill(title: gym.name, isSelected: selectedGym == gym) {
                    selectedGym = selectedGym == gym ? nil : gym
                }
            }
        }
    }

    private var statusPills: some View {
        HStack(spacing: 8) {
            ForEach(ProjectStatus.allCases) { option in
                SelectablePill(title: option.displayName, isSelected: status == option) {
                    status = option
                }
            }
        }
    }

    private var deleteButton: some View {
        Button {
            confirmingDelete = true
        } label: {
            Text("Delete Project")
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(ThemePalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func loadProject() {
        guard let project, !project.isInvalidated else { return }
        name = project.name
        selectedGrade = project.colorGrade
        selectedStyles = Set(project.styles)
        selectedGym = project.gym
        status = project.status
        notes = project.notes ?? ""
    }

    private func saveProject() {
        let target = project ?? {
            let created = Project(name: name)
            modelContext.insert(created)
            return created
        }()
        target.name = name
        target.colorGrade = selectedGrade
        target.styles = Array(selectedStyles)
        target.gym = selectedGym
        target.status = status
        target.notes = notes.isEmpty ? nil : notes
        if status != .active { target.isCurrent = false }
        modelContext.saveReportingFailure(operation: "project save")
        dismiss()
    }

    private func deleteProject() {
        guard let project else { return }
        modelContext.delete(project)
        modelContext.saveReportingFailure(operation: "project delete")
        dismiss()
    }
}
