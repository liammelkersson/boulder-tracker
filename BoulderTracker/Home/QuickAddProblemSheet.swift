import SwiftUI
import SwiftData
import PhotosUI

struct QuickAddProblemSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: Session

    @State private var name = ""
    @State private var selectedGrade: ColorGrade = .green
    @State private var selectedStyles: Set<RouteStyle> = []
    @State private var notes = ""
    @State private var isProject = false
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    private let photoStore = PhotoStore.makeDefault()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("New Problem")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundStyle(palette.text)
                field(label: "Name") {
                    ThemedTextField(placeholder: "e.g. Elektra", text: $name)
                }
                field(label: "Grade") { GradePicker(selection: $selectedGrade) }
                field(label: "Style") { styleChips }
                field(label: "Notes") {
                    ThemedNotesField(placeholder: "Optional notes", text: $notes)
                }
                Toggle("Mark as project", isOn: $isProject)
                    .scaledFont(size: 15)
                    .foregroundStyle(palette.text)
                    .tint(ThemePalette.accent)
                    .disabled(name.isEmpty)
                field(label: "Photo") { photoPickerRow }
                Button(action: saveProblem) {
                    AccentButtonLabel(title: "Add Problem")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { photoData = try? await newItem?.loadTransferable(type: Data.self) }
        }
    }

    private func field(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: label)
                .scaledFont(size: 12, weight: .semibold)
            content()
        }
    }

    private var styleChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(RouteStyle.allCases) { style in
                SelectablePill(
                    title: style.displayName,
                    isSelected: selectedStyles.contains(style)
                ) {
                    toggleStyle(style)
                }
            }
        }
    }

    private func toggleStyle(_ style: RouteStyle) {
        if selectedStyles.contains(style) {
            selectedStyles.remove(style)
        } else {
            selectedStyles.insert(style)
        }
    }

    private var photoPickerRow: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            HStack(spacing: 12) {
                photoThumbnail
                Text(photoData == nil ? "Tap to add a photo" : "Photo added — tap to change")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(photoData == nil ? palette.textDim : palette.text)
            }
        }
        .buttonStyle(.plain)
    }

    private var photoThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.pill)
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 14))
            } else {
                Image(systemName: "camera")
                    .foregroundStyle(palette.textFaint)
            }
        }
        .frame(width: 56, height: 56)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    photoData == nil ? palette.border.opacity(0.25) : ThemePalette.accent,
                    style: StrokeStyle(lineWidth: 2, dash: photoData == nil ? [5] : [])
                )
        }
    }

    private func saveProblem() {
        let problem = SessionProblem(
            name: name, colorGrade: selectedGrade, styles: Array(selectedStyles)
        )
        if !notes.isEmpty { problem.notes = notes }
        if let photoData {
            problem.photoFilename = try? photoStore.savePhoto(photoData)
        }
        session.problems.append(problem)
        if isProject {
            ProjectLinking.linkProject(to: problem, in: modelContext)
        }
        modelContext.saveReportingFailure(operation: "problem add")
        dismiss()
    }
}
