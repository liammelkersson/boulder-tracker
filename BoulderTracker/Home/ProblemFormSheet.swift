import SwiftUI
import PhotosUI

/// The problem entry form, shared by the live-session sheet and the past
/// session form. It owns no store access: it hands back a finished draft and
/// the caller decides where the problem lands.
struct ProblemFormSheet: View {
    @Environment(\.palette) private var palette
    let title: String
    let actionTitle: String
    let onSubmit: (ProblemDraft) -> Void

    @State private var draft = ProblemDraft()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundStyle(palette.text)
                field(label: "Name") {
                    ThemedTextField(placeholder: "e.g. Elektra", text: $draft.name)
                }
                field(label: "Grade") { GradePicker(selection: $draft.colorGrade) }
                field(label: "Style") { styleChips }
                field(label: "Notes") {
                    ThemedNotesField(placeholder: "Optional notes", text: $draft.notes)
                }
                Toggle("Mark as project", isOn: $draft.isProject)
                    .scaledFont(size: 15)
                    .foregroundStyle(palette.text)
                    .tint(ThemePalette.accent)
                    .disabled(draft.name.isEmpty)
                field(label: "Photo") { photoPickerRow }
                Button {
                    onSubmit(draft)
                } label: {
                    AccentButtonLabel(title: actionTitle)
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
            Task { draft.photoData = try? await newItem?.loadTransferable(type: Data.self) }
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
                    isSelected: draft.styles.contains(style)
                ) {
                    toggleStyle(style)
                }
            }
        }
    }

    private func toggleStyle(_ style: RouteStyle) {
        if draft.styles.contains(style) {
            draft.styles.remove(style)
        } else {
            draft.styles.insert(style)
        }
    }

    private var photoPickerRow: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            HStack(spacing: 12) {
                photoThumbnail
                Text(draft.photoData == nil
                     ? "Tap to add a photo"
                     : "Photo added — tap to change")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(draft.photoData == nil ? palette.textDim : palette.text)
            }
        }
        .buttonStyle(.plain)
    }

    private var photoThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.pill)
            if let photoData = draft.photoData, let image = UIImage(data: photoData) {
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
                    draft.photoData == nil ? palette.border.opacity(0.25) : ThemePalette.accent,
                    style: StrokeStyle(lineWidth: 2, dash: draft.photoData == nil ? [5] : [])
                )
        }
    }
}
