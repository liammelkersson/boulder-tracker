import Foundation

enum AppPreferences {
    static let darkModeKey = "pref.darkMode"
    static let healthKitSyncKey = "pref.healthKitSync"
    static let gradeSystemKey = "pref.gradeSystem"
    static let profileNameKey = "pref.profileName"
    static let climbingSinceYearKey = "pref.climbingSinceYear"
    static let avatarFilenameKey = "pref.avatarFilename"
    static let onboardingCompleteKey = "pref.onboardingComplete"

    /// Set by XCUITest launch arguments to force a first-launch wizard.
    static let uiTestingResetOnboardingKey = "uiTestingResetOnboarding"

    static let defaultProfileName = "Liam"
    static let defaultClimbingSinceYear = "2023"
}
