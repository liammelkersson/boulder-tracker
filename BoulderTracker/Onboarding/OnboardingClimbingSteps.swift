import SwiftData
import SwiftUI

struct OnboardingGymStep: View {
    @Binding var draft: OnboardingDraft
    let gyms: [Gym]

    @FocusState private var customFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "HOME BASE",
            title: "Where do you climb?",
            subtitle: "We’ll preselect this gym whenever you start a session."
        ) {
            VStack(spacing: 10) {
                ForEach(gyms) { gym in
                    gymButton(gym)
                }

                Button {
                    draft.gymChoice = .custom
                    customFocused = true
                } label: {
                    selectionRow(
                        title: "Add another gym",
                        detail: "Enter a custom name",
                        systemImage: "plus",
                        selected: draft.gymChoice == .custom
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.customGymChoice")

                if draft.gymChoice == .custom {
                    TextField("Gym name", text: $draft.customGymName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($customFocused)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .frame(height: 62)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.black.opacity(customFocused ? 0.4 : 0.08), lineWidth: customFocused ? 2 : 1)
                        }
                        .accessibilityIdentifier("onboarding.customGym")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func gymButton(_ gym: Gym) -> some View {
        let selected = draft.gymChoice == .existing(gym.persistentModelID)
        return Button {
            draft.gymChoice = .existing(gym.persistentModelID)
        } label: {
            selectionRow(
                title: gym.name,
                detail: gym.isDefault ? "Current default" : "Saved gym",
                systemImage: "mappin.and.ellipse",
                selected: selected
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.gym.\(gym.name)")
    }

    private func selectionRow(
        title: String,
        detail: String,
        systemImage: String,
        selected: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 42, height: 42)
                .background(selected ? ThemePalette.accent : .black.opacity(0.05), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ThemePalette.light.textDim)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selected ? ThemePalette.light.accentText : .black.opacity(0.16))
        }
        .foregroundStyle(ThemePalette.light.text)
        .padding(14)
        .background(.white.opacity(selected ? 0.82 : 0.5), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(selected ? ThemePalette.light.accentText.opacity(0.5) : .black.opacity(0.05), lineWidth: 1.5)
        }
    }
}

struct OnboardingGradeSystemStep: View {
    @Binding var selection: GradeSystem

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "YOUR LANGUAGE",
            title: "Choose your grades",
            subtitle: "Your climbs stay the same. You can switch display systems any time."
        ) {
            VStack(spacing: 12) {
                ForEach(GradeSystem.allCases) { system in
                    Button { selection = system } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(system.displayName)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                Text(example(for: system))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(ThemePalette.light.textDim)
                            }
                            Spacer()
                            Image(systemName: selection == system ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(selection == system ? ThemePalette.light.accentText : .black.opacity(0.16))
                        }
                        .foregroundStyle(ThemePalette.light.text)
                        .padding(20)
                        .background(.white.opacity(selection == system ? 0.84 : 0.52), in: RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(selection == system ? ThemePalette.light.accentText.opacity(0.5) : .black.opacity(0.05), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.grade.\(system.rawValue)")
                }
            }
        }
    }

    private func example(for system: GradeSystem) -> String {
        switch system {
        case .french: "Examples: 5+, 6B, 7A"
        case .vScale: "Examples: V3, V5, V7"
        }
    }
}

struct OnboardingShoesStep: View {
    @Binding var shoeName: String
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "OPTIONAL",
            title: "What are you climbing in?",
            subtitle: "Add your current shoes to track what you wore each session."
        ) {
            VStack(spacing: 18) {
                Image("ShoeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .padding(18)
                    .background(.white.opacity(0.58), in: Circle())

                TextField("e.g. Scarpa Drago", text: $shoeName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focused)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 68)
                    .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.black.opacity(focused ? 0.4 : 0.08), lineWidth: focused ? 2 : 1)
                    }
                    .accessibilityIdentifier("onboarding.shoe")
            }
        }
    }
}
