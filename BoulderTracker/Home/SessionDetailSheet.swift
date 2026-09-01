import SwiftUI
import SwiftData

struct SessionDetailSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: Session

    @State private var isEditing = false
    @State private var showingAddProblem = false
    @State private var confirmingDelete = false
    @State private var draftGym: Gym?
    @State private var draftShoe: Shoe?
    @State private var draftDurationMinutes = 0
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query private var allShoes: [Shoe]

    var body: some View {
        // Delete removes the session while the sheet is still up; the final
        // body evaluation after that must not touch persisted properties.
        if session.isInvalidated {
            Color.clear
        } else {
            detailContent
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleRow
                photoHeader
                typeRow
                statsRow
                if isEditing {
                    editForm
                } else {
                    detailRows
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingAddProblem) {
            QuickAddProblemSheet(session: session)
        }
        .confirmationDialog(
            "Delete this session?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive, action: deleteSession)
        } message: {
            Text("Removes the session, its problems, and photos. Cannot be undone.")
        }
    }

    private var titleRow: some View {
        HStack {
            Text(session.startTime, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textDim)
                    .frame(width: 30, height: 30)
                    .background(palette.pill)
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
        }
    }

    private var photoHeader: some View {
        SessionPhotoThumbnail(session: session, size: 150)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(.rect(cornerRadius: 16))
    }

    private var typeRow: some View {
        HStack(spacing: 8) {
            ClimbTypeChip(climbType: session.climbType)
            if let hardest = StatsAggregator.hardestSend(of: [session]) {
                GradeDot(grade: hardest.colorGrade)
            }
            if let feeling = session.feeling {
                Text(feeling.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
        }
    }

    private var statsRow: some View {
        let summary = StatsAggregator.summary(of: [session])
        return HStack(spacing: 8) {
            detailStat(value: "\(summary.problemCount)", label: "Problems")
            detailStat(value: "\(summary.sendCount)", label: "Sends")
            detailStat(
                value: SessionDurationFormat.compactString(from: session.duration),
                label: "Duration"
            )
        }
    }

    private func detailStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(palette.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(palette.surfaceSunken)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            problemsSection
            infoRow(label: "Gym", value: session.gym?.name ?? "Unknown gym")
            if let shoe = session.shoe {
                infoRow(label: "Shoes", value: shoe.name)
            }
            partnersRow
            if let notes = session.notes, !notes.isEmpty {
                infoRow(label: "Notes", value: notes)
            }
            Button {
                startEditing()
            } label: {
                Text("Edit Session")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(palette.pill)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            Button {
                confirmingDelete = true
            } label: {
                Text("Delete Session")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemePalette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func deleteSession() {
        let photoStore = PhotoStore.makeDefault()
        if let filename = session.photoFilename {
            try? photoStore.deletePhoto(named: filename)
        }
        for problem in session.problems {
            if let filename = problem.photoFilename {
                try? photoStore.deletePhoto(named: filename)
            }
        }
        let completion = SessionCompletion(workoutWriter: HealthKitWorkoutWriter())
        let doomedSession = session
        dismiss()
        Task { @MainActor in
            await completion.deleteWorkoutIfPresent(for: doomedSession)
            modelContext.delete(doomedSession)
            modelContext.saveReportingFailure(operation: "session delete")
        }
    }

    private var problemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Problems worked on")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
            ForEach(session.problems) { problem in
                ProblemTile(problem: problem)
            }
            QuickLogRow(session: session)
                .padding(.top, 2)
            Button {
                showingAddProblem = true
            } label: {
                Text("+ Add Problem")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accentText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(palette.pill)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(palette.textFaint)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
        }
    }

    private var partnersRow: some View {
        HStack(spacing: 6) {
            Text("With")
                .font(.system(size: 14))
                .foregroundStyle(palette.textFaint)
            Spacer()
            if session.partners.isEmpty {
                Text("Solo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
            }
            ForEach(session.partners) { partner in
                PartnerChip(name: partner.name)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Photo")
                SessionPhotoPickerRow(session: session)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Gym")
                Picker("Gym", selection: $draftGym) {
                    ForEach(gyms) { gym in
                        Text(gym.name).tag(Optional(gym))
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(palette.pill)
                .clipShape(.rect(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Shoes")
                Picker("Shoes", selection: $draftShoe) {
                    Text("None").tag(Shoe?.none)
                    ForEach(selectableShoes) { shoe in
                        Text(shoe.name).tag(Optional(shoe))
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(palette.pill)
                .clipShape(.rect(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Duration")
                Stepper(
                    "\(SessionDurationFormat.compactString(from: TimeInterval(draftDurationMinutes * 60)))",
                    value: $draftDurationMinutes, in: 5...600, step: 5
                )
                .font(.system(size: 14))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(palette.pill)
                .clipShape(.rect(cornerRadius: 12))
            }
            Button(action: saveEdits) {
                AccentButtonLabel(title: "Save Changes")
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    /// Retired shoes stay pickable only while this session already wears them.
    private var selectableShoes: [Shoe] {
        allShoes
            .filter { !$0.isRetired || $0 == session.shoe }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func startEditing() {
        draftGym = session.gym
        draftShoe = session.shoe
        draftDurationMinutes = max(5, Int(session.duration) / 60)
        isEditing = true
    }

    private func saveEdits() {
        session.gym = draftGym
        session.shoe = draftShoe
        session.endTime = session.startTime.addingTimeInterval(TimeInterval(draftDurationMinutes * 60))
        modelContext.saveReportingFailure(operation: "session edit")
        isEditing = false
    }
}

struct PartnerChip: View {
    @Environment(\.palette) private var palette
    let name: String

    private static let chipColors: [Color] = [
        Color(hex: 0xE7B23C), Color(hex: 0x7C97F0), Color(hex: 0x3FCB9B), Color(hex: 0xE5473B),
    ]

    private var chipColor: Color {
        let paletteIndex = abs(name.hashValue) % Self.chipColors.count
        return Self.chipColors[paletteIndex]
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(name.prefix(1).uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ThemePalette.onAccent)
                .frame(width: 17, height: 17)
                .background(chipColor)
                .clipShape(.circle)
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(palette.textDim)
        }
        .padding(.trailing, 10)
        .padding(.leading, 3)
        .padding(.vertical, 3)
        .overlay {
            Capsule().strokeBorder(palette.border.opacity(0.14), lineWidth: 1)
        }
    }
}
