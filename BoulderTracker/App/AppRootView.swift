import SwiftUI

struct AppRootView: View {
    @AppStorage(AppPreferences.onboardingCompleteKey) private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            RootTabView()
        } else {
            OnboardingFlowView()
        }
    }
}
