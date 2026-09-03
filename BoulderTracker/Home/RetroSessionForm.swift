import SwiftUI
import SwiftData

/// Log a past session that wasn't tracked live.
struct RetroSessionForm: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
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
    @State private var problemDrafts: [ProblemDraft] = []
    @State private var showingProblemForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add Past Session")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundStyle(palette.text)
                dateAndDuration
                gymField
                typeField
                partnerField
                shoeField
                problemsField
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
        .sheet(isPresented: $showingProblemForm) {
            ProblemFormSheet(title: "Add Problem", actionTitle: "Add Problem",
                             onSubmit: collectProblemDraft)
        }
        .onAppear { selectedGym = gyms.first { $0.isDefault } ?? gyms.first }
    }

    private var dateAndDuration: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "When")
            DatePicker("Start", selection: $startDate, in: ...Date.now)
                .scaledFont(size: 14)
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(palette.pill)
                .clipShape(.rect(cornerRadius: 12))
            Stepper(
                "Duration: \(SessionDurationFormat.compactString(from: TimeInterval(durationMinutes * 60)))",
                value: $durationMinutes, in: 5...600, step: 5
            )
            .scaledFont(size: 14)
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
                    .scaledFont(size: 13)
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

    private var activeShoes: [Shoe] { allShoes.pickableInNaturalOrder }

    private var shoeField: some View {
        let activeShoes = self.activeShoes
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Shoes")
            if activeShoes.isEmpty {
                Text("No shoes yet — add them in Profile")
                    .scaledFont(size: 13)
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

    private var problemsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Problems")
            ForEach(problemDrafts) { draft in
                draftRow(draft)
            }
            Button {
                showingProblemForm = true
            } label: {
                SecondaryButtonLabel(title: "+ Add Problem")
            }
            .buttonStyle(.plain)
        }
    }

    private func draftRow(_ draft: ProblemDraft) -> some View {
        HStack(spacing: 12) {
            HoldIcon(grade: draft.colorGrade, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name.isEmpty ? "Quick log" : draft.name)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(palette.text)
                Text(draft.colorGrade.detailLabel(in: gradeSystem))
                    .scaledFont(size: 12)
                    .foregroundStyle(palette.textFaint)
            }
            Spacer()
            Button {
                removeDraft(draft)
            } label: {
                Image(systemName: "trash")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(ThemePalette.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(draft.name.isEmpty ? "quick log" : draft.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .themedCard(cornerRadius: 16, sunken: true)
    }

    private func collectProblemDraft(_ draft: ProblemDraft) {
        problemDrafts.append(draft)
        showingProblemForm = false
    }

    private func removeDraft(_ draft: ProblemDraft) {
        problemDrafts.removeAll { $0.id == draft.id }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Notes")
            ThemedNotesField(placeholder: "Optional notes", text: $notes)
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
        attachProblems(to: session)
        modelContext.saveReportingFailure(operation: "retro session save")
        dismiss()
    }

    /// Drafts become rows only once the session they belong to exists, so an
    /// abandoned form leaves nothing behind.
    private func attachProblems(to session: Session) {
        let photoStore = PhotoStore.makeDefault()
        for draft in problemDrafts {
            let problem = draft.makeProblem(savePhoto: photoStore.savePhoto)
            session.problems.append(problem)
            if draft.isProject {
                ProjectLinking.linkProject(to: problem, in: modelContext)
            }
        }
    }
}
