import PhotosUI
import SwiftUI

struct OnboardingNameStep: View {
    @Binding var name: String
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "YOUR PROFILE",
            title: "What should we call you?",
            subtitle: "This is how your sessions and milestones will be labelled."
        ) {
            TextField("Your name", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focused)
                .onSubmit(onSubmit)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .frame(minHeight: 76)
                .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.black.opacity(focused ? 0.42 : 0.08), lineWidth: focused ? 2 : 1)
                }
                .accessibilityIdentifier("onboarding.name")
        }
        .onAppear { focused = true }
    }
}

struct OnboardingProfileStep: View {
    @Binding var avatarData: Data?
    @Binding var climbingSinceYear: String

    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var yearFocused: Bool

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "A LITTLE CONTEXT",
            title: "Make it yours",
            subtitle: "Photo is optional. Your climbing year helps put progress in perspective."
        ) {
            VStack(spacing: 22) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatar
                }
                .buttonStyle(.plain)
                .accessibilityLabel(avatarData == nil ? "Add profile photo" : "Change profile photo")
                .accessibilityIdentifier("onboarding.photo")

                if avatarData != nil {
                    Button("Remove photo") { avatarData = nil }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemePalette.light.textDim)
                }

                VStack(spacing: 8) {
                    Text("CLIMBING SINCE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(ThemePalette.light.textDim)

                    TextField("Year", text: $climbingSinceYear)
                        .keyboardType(.numberPad)
                        .focused($yearFocused)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 150, height: 62)
                        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 20))
                        .onChange(of: climbingSinceYear) { _, value in
                            let digits = value.filter(\.isNumber)
                            climbingSinceYear = String(digits.prefix(4))
                        }
                        .accessibilityIdentifier("onboarding.year")
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.66))
                .frame(width: 132, height: 132)
                .shadow(color: .black.opacity(0.1), radius: 16, y: 8)

            if let avatarData, let image = UIImage(data: avatarData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 132, height: 132)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(ThemePalette.light.textDim)
            }
        }
    }
}

struct OnboardingStepLayout<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(eyebrow)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(ThemePalette.light.accentText)

                Text(title)
                    .font(.system(size: 35, weight: .black, design: .rounded))
                    .foregroundStyle(ThemePalette.light.text)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(ThemePalette.light.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)

                content
                    .padding(.top, 26)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.top, 52)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
