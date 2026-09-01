import SwiftUI
import SwiftData

/// Log a past session that wasn't tracked live.
struct RetroSessionForm: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query(sort: \Partner.name) private var allPartners: [Partner]
    @Query private var allShoes: [Shoe]

    private static let defaultDurationMinutes = 90

    @State private var startDate = Date.now
    @State private var durationMinutes = defaultDurationMinutes
    @State private var selectedGym: Gym?
    @State private var selectedClimbType: ClimbType = .bouldering
    @State private var selectedPartnerIDs: Set<PersistentIdentifier> = []
    @State private var feeling: SessionFeeling = .good
    @State private var selectedShoe: Shoe?
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add Past Session")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.text)
                dateAndDuration
                gymField
                typeField
                partnerField
                shoeField
                notesField
                Button(action: saveSession) {
                    AccentButtonLabel(title: "Save Session")
                }
                .buttonStyle(.plain)
                .disabled(selectedGym == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { selectedGym = gyms.first { $0.isDefault } ?? gyms.first }
    }

    private var dateAndDuration: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "When")
            DatePicker("Start", selection: $startDate, in: ...Date.now)
                .font(.system(size: 14))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(palette.pill)
                .clipShape(.rect(cornerRadius: 12))
            Stepper(
                "Duration: \(SessionDurationFormat.compactString(from: TimeInterval(durationMinutes * 60)))",
                value: $durationMinutes, in: 5...600, step: 5
            )
            .font(.system(size: 14))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.pill)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var gymField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Gym")
            FlowLayout(spacing: 8) {
                ForEach(gyms) { gym in
                    SelectablePill(title: gym.name, isSelected: selectedGym == gym) {
                        selectedGym = gym
                    }
                }
            }
        }
    }

    private var typeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Type")
            FlowLayout(spacing: 8) {
                ForEach(ClimbType.allCases) { climbType in
                    SelectablePill(
                        title: climbType.displayName,
                        isSelected: selectedClimbType == climbType
                    ) {
                        selectedClimbType = climbType
                    }
                }
            }
        }
    }

    private var partnerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Partners")
            if allPartners.isEmpty {
                Text("No partners yet — add them in Profile")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textFaint)
            }
            FlowLayout(spacing: 8) {
                ForEach(allPartners) { partner in
                    SelectablePill(
                        title: partner.name,
                        isSelected: selectedPartnerIDs.contains(partner.persistentModelID)
                    ) {
                        togglePartner(partner)
                    }
                }
            }
        }
    }

    /// Natural order so "Drago 2" sorts before "Drago 10".
    private var activeShoes: [Shoe] {
        allShoes
            .filter { !$0.isRetired }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var shoeField: some View {
        let activeShoes = self.activeShoes
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Shoes")
            if activeShoes.isEmpty {
                Text("No shoes yet — add them in Profile")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textFaint)
            }
            FlowLayout(spacing: 8) {
                ForEach(activeShoes) { shoe in
                    SelectablePill(title: shoe.name, isSelected: selectedShoe == shoe) {
                        selectedShoe = selectedShoe == shoe ? nil : shoe
                    }
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Notes")
            ThemedTextField(placeholder: "Optional notes", text: $notes)
        }
    }

    private func togglePartner(_ partner: Partner) {
        if selectedPartnerIDs.contains(partner.persistentModelID) {
            selectedPartnerIDs.remove(partner.persistentModelID)
        } else {
            selectedPartnerIDs.insert(partner.persistentModelID)
        }
    }

    private func saveSession() {
        let partners = allPartners.filter { selectedPartnerIDs.contains($0.persistentModelID) }
        let session = Session(
            startTime: startDate, gym: selectedGym, partners: partners,
            climbType: selectedClimbType
        )
        session.endTime = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        session.feeling = feeling
        session.shoe = selectedShoe
        if !notes.isEmpty { session.notes = notes }
        modelContext.insert(session)
        try? modelContext.save()
        dismiss()
    }
}
