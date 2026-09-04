import SwiftUI
import SwiftData

/// Writes finished sessions to a JSON file and hands it to the share sheet.
struct SessionExportRow: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var exportFile: ExportFile?

    var body: some View {
        Button(action: exportSessions) {
            HStack {
                Text("Export data")
                    .scaledFont(size: 15)
                    .foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(palette.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .themedCard()
        }
        .buttonStyle(.plain)
        .sheet(item: $exportFile) { file in ShareSheetView(url: file.url) }
    }

    private func exportSessions() {
        let finished = sessions.persisted.withoutSampleData.filter { !$0.isLive }
        guard let url = try? SessionDataExport.writeJSONFile(for: finished) else { return }
        exportFile = ExportFile(url: url)
    }
}

/// Identifies the written file for `.sheet(item:)`; used only by this flow.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
