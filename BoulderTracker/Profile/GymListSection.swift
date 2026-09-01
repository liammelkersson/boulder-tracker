import SwiftUI
import SwiftData

struct GymListSection: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @State private var editingGym: Gym?
    @State private var isAddingGym = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Gyms")
            VStack(spacing: 0) {
                ForEach(gyms) { gym in
                    gymRow(gym)
                }
                addRow
            }
            .themedCard()
        }
        .sheet(item: $editingGym) { gym in
            GymEditorSheet(gym: gym)
        }
        .sheet(isPresented: $isAddingGym) {
            GymEditorSheet(gym: nil)
        }
    }

    private func gymRow(_ gym: Gym) -> some View {
        HStack(spacing: 10) {
            Text(gym.name)
                .scaledFont(size: 15)
                .foregroundStyle(palette.text)
            Spacer()
            if gym.isDefault {
                Text("Default")
                    .scaledFont(size: 12)
                    .foregroundStyle(palette.textFaint)
            }
            Button {
                editingGym = gym
            } label: {
                Text("Edit")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(palette.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
        }
    }

    private var addRow: some View {
        Button {
            isAddingGym = true
        } label: {
            Text("+ Add Gym")
                .scaledFont(size: 15)
                .foregroundStyle(palette.accentText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct GymEditorSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Query private var allGyms: [Gym]
    /// `nil` creates a new gym.
    let gym: Gym?

    @State private var name = ""
    @State private var isDefault = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(gym == nil ? "Add Gym" : "Edit Gym")
                .scaledFont(size: 18, weight: .bold)
                .foregroundStyle(palette.text)
            ThemedTextField(placeholder: "Gym name", text: $name)
            Toggle("Default gym", isOn: $isDefault)
                .scaledFont(size: 15)
                .foregroundStyle(palette.text)
                .tint(ThemePalette.accent)
            Button {
                saveGym()
            } label: {
                AccentButtonLabel(title: "Save")
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty)
            if gym != nil {
                Button {
                    confirmingDelete = true
                } label: {
                    Text("Delete Gym")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(ThemePalette.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete this gym?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Gym", role: .destructive, action: deleteGym)
        } message: {
            Text("Sessions keep their history but lose the gym link.")
        }
        .onAppear {
            name = gym?.name ?? ""
            isDefault = gym?.isDefault ?? false
        }
    }

    private func deleteGym() {
        guard let gym else { return }
        modelContext.delete(gym)
        modelContext.saveReportingFailure(operation: "gym delete")
        syncCoordinator.publishCatalog()
        dismiss()
    }

    private func saveGym() {
        let target = gym ?? {
            let created = Gym(name: name)
            modelContext.insert(created)
            return created
        }()
        target.name = name
        if isDefault {
            for other in allGyms where other !== target {
                other.isDefault = false
            }
        }
        target.isDefault = isDefault
        modelContext.saveReportingFailure(operation: "gym save")
        syncCoordinator.publishCatalog()
        dismiss()
    }
}
