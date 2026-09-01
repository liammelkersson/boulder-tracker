import Foundation
import SwiftData

@MainActor
protocol OnboardingSaving {
    func save(_ draft: OnboardingDraft, gyms: [Gym], context: ModelContext) throws
}

@MainActor
struct OnboardingSaver: OnboardingSaving {
    private let defaults: UserDefaults
    private let savePhoto: (Data) throws -> String
    private let deletePhoto: (String) throws -> Void

    init(
        defaults: UserDefaults,
        savePhoto: @escaping (Data) throws -> String,
        deletePhoto: @escaping (String) throws -> Void
    ) {
        self.defaults = defaults
        self.savePhoto = savePhoto
        self.deletePhoto = deletePhoto
    }

    static var live: OnboardingSaver {
        let photoStore = PhotoStore.makeDefault()
        return OnboardingSaver(
            defaults: .standard,
            savePhoto: photoStore.savePhoto,
            deletePhoto: photoStore.deletePhoto
        )
    }

    func save(_ draft: OnboardingDraft, gyms: [Gym], context: ModelContext) throws {
        try validate(draft)
        defaults.set(false, forKey: AppPreferences.onboardingCompleteKey)

        var savedAvatarFilename: String?
        do {
            let defaultGym = try resolveGym(from: draft, gyms: gyms, context: context)
            for gym in gyms {
                gym.isDefault = gym === defaultGym
            }
            defaultGym.isDefault = true

            if !draft.trimmedShoeName.isEmpty {
                context.insert(Shoe(name: draft.trimmedShoeName))
            }

            if let avatarData = draft.avatarData {
                savedAvatarFilename = try savePhoto(avatarData)
            }

            try context.save()
        } catch {
            context.rollback()
            if let savedAvatarFilename {
                try? deletePhoto(savedAvatarFilename)
            }
            throw error
        }

        defaults.set(draft.trimmedName, forKey: AppPreferences.profileNameKey)
        defaults.set(draft.climbingSinceYear, forKey: AppPreferences.climbingSinceYearKey)
        defaults.set(draft.gradeSystem.rawValue, forKey: AppPreferences.gradeSystemKey)
        defaults.set(savedAvatarFilename ?? "", forKey: AppPreferences.avatarFilenameKey)
        defaults.set(true, forKey: AppPreferences.onboardingCompleteKey)
    }

    private func validate(_ draft: OnboardingDraft) throws {
        for step in [OnboardingStep.name, .profile, .gym] {
            if let error = draft.validationError(for: step) {
                throw error
            }
        }
    }

    private func resolveGym(
        from draft: OnboardingDraft,
        gyms: [Gym],
        context: ModelContext
    ) throws -> Gym {
        switch draft.gymChoice {
        case let .existing(identifier):
            guard let gym = gyms.first(where: { $0.persistentModelID == identifier }) else {
                throw OnboardingValidationError.missingGym
            }
            return gym
        case .custom:
            guard !draft.trimmedCustomGymName.isEmpty else {
                throw OnboardingValidationError.missingGym
            }
            let gym = Gym(name: draft.trimmedCustomGymName, isDefault: true)
            context.insert(gym)
            return gym
        case nil:
            throw OnboardingValidationError.missingGym
        }
    }
}
