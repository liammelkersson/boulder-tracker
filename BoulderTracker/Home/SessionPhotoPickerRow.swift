import SwiftUI
import SwiftData
import PhotosUI

/// Attach one photo to a session (shown on rows and in the detail sheet).
struct SessionPhotoPickerRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    let session: Session

    @State private var selectedItem: PhotosPickerItem?
    private let photoStore = PhotoStore.makeDefault()

    private var hasPhoto: Bool { session.photoFilename != nil }

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 12) {
                SessionPhotoThumbnail(session: session, size: 56)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                hasPhoto ? ThemePalette.accent : palette.border.opacity(0.25),
                                style: StrokeStyle(lineWidth: 2, dash: hasPhoto ? [] : [5])
                            )
                    }
                Text(hasPhoto ? "Photo added — tap to change" : "Add a session photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(hasPhoto ? palette.text : palette.textDim)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            Task { await savePickedPhoto(newItem) }
        }
    }

    @MainActor
    private func savePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let oldFilename = session.photoFilename {
            try? photoStore.deletePhoto(named: oldFilename)
        }
        session.photoFilename = try? photoStore.savePhoto(data)
        modelContext.saveReportingFailure(operation: "session photo update")
    }
}
