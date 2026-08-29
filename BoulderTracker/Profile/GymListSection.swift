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
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
            Spacer()
            if gym.isDefault {
                Text("Default")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
            Button {
                editingGym = gym
            } label: {
                Text("Edit")
                    .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 15))
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
    @Query private var allGyms: [Gym]
    /// `nil` creates a new gym.
    let gym: Gym?

    @State private var name = ""
    @State private var isDefault = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(gym == nil ? "Add Gym" : "Edit Gym")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            ThemedTextField(placeholder: "Gym name", text: $name)
            Toggle("Default gym", isOn: $isDefault)
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
                .tint(ThemePalette.accent)
            Button {
                saveGym()
            } label: {
                AccentButtonLabel(title: "Save")
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            name = gym?.name ?? ""
            isDefault = gym?.isDefault ?? false
        }
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
        try? modelContext.save()
        dismiss()
    }
}
