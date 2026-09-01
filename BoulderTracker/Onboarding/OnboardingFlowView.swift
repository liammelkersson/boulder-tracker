import SwiftData
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gym.name) private var gyms: [Gym]

    private let saver: any OnboardingSaving

    @State private var step = OnboardingStep.welcome
    @State private var draft = OnboardingDraft()
    @State private var isSaving = false
    @State private var saveError: String?

    init(saver: any OnboardingSaving = OnboardingSaver.live) {
        self.saver = saver
    }

    var body: some View {
        ZStack {
            if step == .welcome {
                OnboardingWelcomeView { move(to: .name) }
                    .transition(stepTransition)
            } else {
                setupShell
                    .transition(stepTransition)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.42), value: step)
        .environment(\.palette, .light)
        .preferredColorScheme(.light)
    }

    private var setupShell: some View {
        ZStack {
            ThemePalette.light.background.ignoresSafeArea()
            WallTexture().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if step != .ready { footer }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            EmptyView()
        case .name:
            OnboardingNameStep(name: $draft.name) {
                if draft.validationError(for: .name) == nil { moveForward() }
            }
        case .profile:
            OnboardingProfileStep(
                avatarData: $draft.avatarData,
                climbingSinceYear: $draft.climbingSinceYear
            )
        case .gym:
            OnboardingGymStep(draft: $draft, gyms: gyms)
        case .gradeSystem:
            OnboardingGradeSystemStep(selection: $draft.gradeSystem)
        case .shoes:
            OnboardingShoesStep(shoeName: $draft.shoeName)
        case .ready:
            OnboardingReadyView(
                name: draft.trimmedName,
                gymName: resolvedGymName,
                shoeName: draft.trimmedShoeName,
                isSaving: isSaving,
                errorMessage: saveError,
                onFinish: finishSetup
            )
        }
    }

    private var header: some View {
        HStack {
            Button { moveBackward() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("onboarding.back")

            Spacer()
            progress
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(1..<OnboardingStep.allCases.count, id: \.self) { index in
                Capsule()
                    .fill(index <= step.rawValue ? ThemePalette.onAccent : Color.black.opacity(0.12))
                    .frame(width: index == step.rawValue ? 22 : 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue) of \(OnboardingStep.allCases.count - 1)")
        .accessibilityIdentifier("onboarding.progress")
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if step == .shoes {
                Button("Skip") { moveForward() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ThemePalette.light.textDim)
                    .accessibilityIdentifier("onboarding.skip")
            }
            Spacer()
            Button { moveForward() } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(ThemePalette.onAccent, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(draft.validationError(for: step) != nil)
            .opacity(draft.validationError(for: step) == nil ? 1 : 0.3)
            .accessibilityLabel("Continue")
            .accessibilityIdentifier("onboarding.next")
        }
        .frame(minHeight: 78)
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func moveForward() {
        guard draft.validationError(for: step) == nil else { return }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        move(to: next)
    }

    private func moveBackward() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        move(to: previous)
    }

    private func move(to newStep: OnboardingStep) {
        saveError = nil
        step = newStep
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    private var resolvedGymName: String {
        switch draft.gymChoice {
        case let .existing(identifier):
            return gyms.first(where: { $0.persistentModelID == identifier })?.name ?? "Selected gym"
        case .custom:
            return draft.trimmedCustomGymName
        case nil:
            return ""
        }
    }

    private func finishSetup() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        Task { @MainActor in
            await Task.yield()
            do {
                try saver.save(draft, gyms: gyms, context: modelContext)
            } catch {
                saveError = "Couldn’t finish setup. Please try again."
            }
            isSaving = false
        }
    }
}
