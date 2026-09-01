import SwiftUI
import SwiftData

struct PartnerListSection: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Partner.name) private var partners: [Partner]
    @State private var editingPartner: Partner?
    @State private var isAddingPartner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Partners")
            VStack(spacing: 0) {
                ForEach(partners) { partner in
                    partnerRow(partner)
                }
                addRow
            }
            .themedCard()
        }
        .sheet(item: $editingPartner) { partner in
            PartnerEditorSheet(partner: partner)
        }
        .sheet(isPresented: $isAddingPartner) {
            PartnerEditorSheet(partner: nil)
        }
    }

    private func partnerRow(_ partner: Partner) -> some View {
        HStack {
            Text(partner.name)
                .scaledFont(size: 15)
                .foregroundStyle(palette.text)
            Spacer()
            Button {
                editingPartner = partner
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
            isAddingPartner = true
        } label: {
            Text("+ Add Partner")
                .scaledFont(size: 15)
                .foregroundStyle(palette.accentText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct PartnerEditorSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// `nil` creates a new partner.
    let partner: Partner?

    @State private var name = ""
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(partner == nil ? "Add Partner" : "Edit Partner")
                .scaledFont(size: 18, weight: .bold)
                .foregroundStyle(palette.text)
            ThemedTextField(placeholder: "Partner name", text: $name)
            Button {
                savePartner()
            } label: {
                AccentButtonLabel(title: "Save")
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty)
            if partner != nil {
                Button {
                    confirmingDelete = true
                } label: {
                    Text("Delete Partner")
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
            "Delete this partner?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Partner", role: .destructive, action: deletePartner)
        } message: {
            Text("Sessions keep their history but lose the partner link.")
        }
        .onAppear { name = partner?.name ?? "" }
    }

    private func deletePartner() {
        guard let partner else { return }
        modelContext.delete(partner)
        modelContext.saveReportingFailure(operation: "partner delete")
        dismiss()
    }

    private func savePartner() {
        if let partner {
            partner.name = name
        } else {
            modelContext.insert(Partner(name: name))
        }
        modelContext.saveReportingFailure(operation: "partner save")
        dismiss()
    }
}
