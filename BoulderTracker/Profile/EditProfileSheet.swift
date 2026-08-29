import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.profileNameKey)
    private var profileName = AppPreferences.defaultProfileName
    @AppStorage(AppPreferences.climbingSinceYearKey)
    private var climbingSinceYear = AppPreferences.defaultClimbingSinceYear
    @AppStorage(AppPreferences.avatarFilenameKey) private var avatarFilename = ""

    @State private var draftName = ""
    @State private var draftYear = ""
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var draftAvatarData: Data?
    private let photoStore = PhotoStore.makeDefault()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            avatarPicker
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Name")
                ThemedTextField(placeholder: "Your name", text: $draftName)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(title: "Climbing since")
                ThemedTextField(placeholder: "e.g. 2023", text: $draftYear)
                    .keyboardType(.numberPad)
            }
            Button {
                saveProfile()
            } label: {
                AccentButtonLabel(title: "Save")
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            draftName = profileName
            draftYear = climbingSinceYear
        }
        .onChange(of: selectedAvatarItem) { _, newItem in
            Task { draftAvatarData = try? await newItem?.loadTransferable(type: Data.self) }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            HStack(spacing: 12) {
                avatarPreview
                Text(hasAvatar ? "Tap to change photo" : "Add a profile photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textDim)
            }
        }
        .buttonStyle(.plain)
    }

    private var hasAvatar: Bool {
        draftAvatarData != nil || !avatarFilename.isEmpty
    }

    private var avatarPreview: some View {
        ZStack {
            Circle().fill(palette.pill)
            if let image = previewImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(.circle)
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.textFaint)
            }
        }
        .frame(width: 64, height: 64)
    }

    private func previewImage() -> UIImage? {
        if let draftAvatarData { return UIImage(data: draftAvatarData) }
        guard !avatarFilename.isEmpty,
              let data = photoStore.loadPhoto(named: avatarFilename) else { return nil }
        return UIImage(data: data)
    }

    private func saveProfile() {
        if !draftName.isEmpty { profileName = draftName }
        if !draftYear.isEmpty { climbingSinceYear = draftYear }
        if let draftAvatarData {
            if !avatarFilename.isEmpty {
                try? photoStore.deletePhoto(named: avatarFilename)
            }
            avatarFilename = (try? photoStore.savePhoto(draftAvatarData)) ?? ""
        }
        dismiss()
    }
}
