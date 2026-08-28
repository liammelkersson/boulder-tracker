import SwiftUI
import SwiftData

struct StartSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query(sort: \Partner.name) private var allPartners: [Partner]
    @State private var selectedGym: Gym?
    @State private var selectedPartners: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            Form {
                Picker("Gym", selection: $selectedGym) {
                    ForEach(gyms) { gym in
                        Text(gym.name).tag(Optional(gym))
                    }
                }
                Section("Partners") {
                    ForEach(allPartners) { partner in
                        Toggle(partner.name, isOn: partnerBinding(for: partner))
                    }
                }
            }
            .navigationTitle("Start Session")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: startSession)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { selectedGym = gyms.first { $0.isDefault } ?? gyms.first }
        }
    }

    private func partnerBinding(for partner: Partner) -> Binding<Bool> {
        Binding(
            get: { selectedPartners.contains(partner.persistentModelID) },
            set: { isSelected in
                if isSelected {
                    selectedPartners.insert(partner.persistentModelID)
                } else {
                    selectedPartners.remove(partner.persistentModelID)
                }
            }
        )
    }

    private func startSession() {
        let partners = allPartners.filter { selectedPartners.contains($0.persistentModelID) }
        let session = Session(startTime: .now, gym: selectedGym, partners: partners)
        modelContext.insert(session)
        dismiss()
    }
}
