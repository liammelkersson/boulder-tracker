import SwiftUI
import SwiftData

struct ShoeListSection: View {
    @Environment(\.palette) private var palette
    @Query private var shoes: [Shoe]
    @State private var editingShoe: Shoe?
    @State private var isAddingShoe = false

    /// Natural order so "Drago 2" sorts before "Drago 10".
    private var sortedShoes: [Shoe] {
        shoes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Shoes")
            VStack(spacing: 0) {
                ForEach(sortedShoes) { shoe in
                    shoeRow(shoe)
                }
                addRow
            }
            .themedCard()
        }
        .sheet(item: $editingShoe) { shoe in
            ShoeEditorSheet(shoe: shoe)
        }
        .sheet(isPresented: $isAddingShoe) {
            ShoeEditorSheet(shoe: nil)
        }
    }

    private func shoeRow(_ shoe: Shoe) -> some View {
        HStack(spacing: 10) {
            Text(shoe.name)
                .font(.system(size: 15))
                .foregroundStyle(shoe.isRetired ? palette.textFaint : palette.text)
            Spacer()
            if shoe.isRetired {
                Text("Retired")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
            Button {
                editingShoe = shoe
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
            isAddingShoe = true
        } label: {
            Text("+ Add Shoes")
                .font(.system(size: 15))
                .foregroundStyle(palette.accentText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct ShoeEditorSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// `nil` creates a new pair.
    let shoe: Shoe?

    @State private var name = ""
    @State private var isRetired = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(shoe == nil ? "Add Shoes" : "Edit Shoes")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            ThemedTextField(placeholder: "e.g. La Sportiva Solution", text: $name)
            Toggle("Retired", isOn: $isRetired)
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
                .tint(ThemePalette.accent)
            Button {
                saveShoe()
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
            name = shoe?.name ?? ""
            isRetired = shoe?.isRetired ?? false
        }
    }

    private func saveShoe() {
        let target = shoe ?? {
            let created = Shoe(name: name)
            modelContext.insert(created)
            return created
        }()
        target.name = name
        target.isRetired = isRetired
        modelContext.saveReportingFailure(operation: "shoe save")
        dismiss()
    }
}
