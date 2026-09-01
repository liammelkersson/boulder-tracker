import OSLog
import SwiftUI
import SwiftData

/// Fills every stats chart with flagged demo sessions; turning it off removes them.
struct SampleDataToggleRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingSampleData = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Show sample data", isOn: sampleDataBinding)
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
                .tint(ThemePalette.accent)
            Text("Adds demo sessions so you can preview the charts. Turning this off removes them again.")
                .font(.system(size: 12))
                .foregroundStyle(palette.textFaint)
        }
        .padding(16)
        .themedCard(cornerRadius: 20)
        .onAppear {
            isShowingSampleData = SampleDataGenerator.sampleDataExists(in: modelContext)
        }
    }

    private var sampleDataBinding: Binding<Bool> {
        Binding(
            get: { isShowingSampleData },
            set: { wantsSampleData in
                if wantsSampleData {
                    insertSampleData()
                } else {
                    removeSampleData()
                }
            }
        )
    }

    private func insertSampleData() {
        do {
            try SampleDataGenerator.insertSampleData(into: modelContext, referenceDate: .now)
        } catch {
            Logger.persistence.error("Sample data insert failed: \(error)")
        }
        isShowingSampleData = SampleDataGenerator.sampleDataExists(in: modelContext)
    }

    private func removeSampleData() {
        do {
            try SampleDataGenerator.removeSampleData(from: modelContext)
        } catch {
            Logger.persistence.error("Sample data removal failed: \(error)")
        }
        isShowingSampleData = SampleDataGenerator.sampleDataExists(in: modelContext)
    }
}
