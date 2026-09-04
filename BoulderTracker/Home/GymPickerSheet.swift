import SwiftUI
import SwiftData

struct GymPickerSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(SessionActivityPresenter.self) private var activityPresenter
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query private var allShoes: [Shoe]
    @State private var selectedClimbType: ClimbType = .bouldering
    @State private var selectedShoe: Shoe?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Where are you climbing?")
                .scaledFont(size: 18, weight: .bold)
                .foregroundStyle(palette.text)
            Text("We'll suggest problems you've logged there before.")
                .scaledFont(size: 13)
                .foregroundStyle(palette.textFaint)
                .padding(.top, 4)
            climbTypeRow
                .padding(.top, 16)
            shoeRow
                .padding(.top, 10)
            gymList
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var climbTypeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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

    @ViewBuilder
    private var shoeRow: some View {
        let shoes = allShoes.pickableInNaturalOrder
        if !shoes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shoes) { shoe in
                        SelectablePill(title: shoe.name, isSelected: selectedShoe == shoe) {
                            selectedShoe = selectedShoe == shoe ? nil : shoe
                        }
                    }
                }
            }
        }
    }

    private var gymList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(gyms) { gym in
                    Button {
                        startSession(at: gym)
                    } label: {
                        Text(gym.name)
                            .scaledFont(size: 15, weight: .medium)
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(palette.pill)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startSession(at gym: Gym) {
        let session = Session(startTime: .now, gym: gym, partners: [], climbType: selectedClimbType)
        session.shoe = selectedShoe
        modelContext.insert(session)
        modelContext.saveReportingFailure(operation: "session start")
        syncCoordinator.announceStart(of: session)
        activityPresenter.start(for: session)
        dismiss()
    }
}

struct SelectablePill: View {
    @Environment(\.palette) private var palette
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(isSelected ? ThemePalette.onAccent : palette.textDim)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? ThemePalette.accent : palette.pill)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
