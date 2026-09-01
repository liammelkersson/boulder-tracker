import SwiftUI
import SwiftData

struct SessionSummaryScreen: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Query(sort: \Session.startTime) private var allSessions: [Session]
    @Query private var unlockedAchievements: [Achievement]
    @Query(sort: \Partner.name) private var knownPartners: [Partner]
    @Query private var allShoes: [Shoe]
    @AppStorage(AppPreferences.healthKitSyncKey) private var healthKitSyncEnabled = true
    let session: Session
    let onFinished: () -> Void

    @State private var partnerNames = ""
    @State private var selectedShoe: Shoe?
    @State private var feeling: SessionFeeling = .good
    @State private var notes = ""
    @State private var unlockedTitles: [String]?
    @State private var isSaving = false

    var body: some View {
        // Discard deletes the session; the final body evaluation after that
        // must not touch persisted properties.
        if session.isInvalidated {
            Color.clear
        } else {
            summaryContent
        }
    }

    private var summaryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                statsGrid
                problemList
                partnerField
                shoeField
                feelingRow
                notesField
                photoField
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            partnerNames = session.partners.map(\.name).joined(separator: ", ")
            selectedShoe = session.shoe
        }
        .alert("Achievements unlocked", isPresented: achievementAlertBinding) {
            Button("Nice") { onFinished() }
        } message: {
            Text((unlockedTitles ?? []).joined(separator: "\n"))
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SectionHeading(title: "Session Complete")
                .kerning(1)
            Text("Nice work")
                .scaledFont(size: 24, weight: .bold)
                .foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
    }

    private var statsGrid: some View {
        let summary = StatsAggregator.summary(of: [session])
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(
                valueText: SessionDurationFormat.timerString(from: session.duration),
                label: "Duration"
            )
            StatTile(valueText: "\(summary.problemCount)", label: "Problems")
            StatTile(valueText: "\(summary.sendCount)", label: "Sends")
            StatTile(
                valueText: summary.flashRate.formatted(.percent.precision(.fractionLength(0))),
                label: "Flash rate"
            )
            if let avgHeartRate = session.avgHeartRate {
                StatTile(valueText: "\(Int(avgHeartRate.rounded()))", label: "Avg BPM")
            }
            if let maxHeartRate = session.maxHeartRate {
                StatTile(valueText: "\(Int(maxHeartRate.rounded()))", label: "Max BPM")
            }
        }
    }

    @ViewBuilder
    private var problemList: some View {
        if !session.problems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Problems")
                ForEach(session.problems) { problem in
                    HStack(spacing: 10) {
                        GradeDot(grade: problem.colorGrade)
                        Text(problem.displayName)
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundStyle(palette.text)
                        Spacer()
                        Text("\(problem.flashCount)F · \(problem.sendCount)S · \(problem.fallCount)X")
                            .scaledFont(size: 12)
                            .foregroundStyle(palette.textFaint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .themedCard(cornerRadius: 14)
                }
            }
        }
    }

    private var partnerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Who else was there?")
            ThemedTextField(placeholder: "e.g. Effe", text: $partnerNames)
        }
    }

    @ViewBuilder
    private var shoeField: some View {
        let shoes = allShoes.pickableInNaturalOrder
        if !shoes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Shoes")
                FlowLayout(spacing: 8) {
                    ForEach(shoes) { shoe in
                        SelectablePill(title: shoe.name, isSelected: selectedShoe == shoe) {
                            selectedShoe = selectedShoe == shoe ? nil : shoe
                        }
                    }
                }
            }
        }
    }

    private var feelingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "How did it feel?")
            HStack(spacing: 8) {
                ForEach(SessionFeeling.allCases) { option in
                    feelingPill(option)
                }
            }
        }
    }

    private func feelingPill(_ option: SessionFeeling) -> some View {
        let isSelected = feeling == option
        return Button {
            feeling = option
        } label: {
            Text(option.displayName)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(isSelected ? palette.onAccentText : palette.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? palette.accentText : palette.pill)
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Notes")
            ThemedTextField(placeholder: "Optional notes about the session", text: $notes)
        }
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Photo")
            SessionPhotoPickerRow(session: session)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: saveSession) {
                AccentButtonLabel(title: "Save Session")
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            Button(action: discardSession) {
                SecondaryButtonLabel(title: "Discard")
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
    }

    private var achievementAlertBinding: Binding<Bool> {
        Binding(
            get: { unlockedTitles != nil },
            set: { isPresented in if !isPresented { unlockedTitles = nil } }
        )
    }

    private func saveSession() {
        isSaving = true
        session.feeling = feeling
        if !notes.isEmpty { session.notes = notes }
        session.partners = resolvedPartners()
        session.shoe = selectedShoe
        Task { await completeSession() }
    }

    @MainActor
    private func completeSession() async {
        let writer: WorkoutWriting? = healthKitSyncEnabled ? HealthKitWorkoutWriter() : nil
        let completion = SessionCompletion(workoutWriter: writer)
        let outcome = await completion.finish(
            session, endTime: session.endTime ?? .now,
            allSessions: allSessions.persisted,
            unlockedIDs: Set(unlockedAchievements.map(\.achievementID))
        )
        for achievement in outcome.newAchievements {
            modelContext.insert(Achievement(achievementID: achievement.id))
        }
        modelContext.saveReportingFailure(operation: "session completion")
        if outcome.newAchievements.isEmpty {
            onFinished()
        } else {
            unlockedTitles = outcome.newAchievements.map(\.title)
        }
    }

    private func resolvedPartners() -> [Partner] {
        let names = partnerNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return names.map { name in
            if let existing = knownPartners.first(where: { $0.name.lowercased() == name.lowercased() }) {
                return existing
            }
            let partner = Partner(name: name)
            modelContext.insert(partner)
            return partner
        }
    }

    private func discardSession() {
        syncCoordinator.announceDeletion(of: session)
        modelContext.delete(session)
        modelContext.saveReportingFailure(operation: "session discard")
        onFinished()
    }
}
