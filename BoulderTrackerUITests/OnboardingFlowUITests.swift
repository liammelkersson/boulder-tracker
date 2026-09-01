import XCTest

final class OnboardingFlowUITests: XCTestCase {
    private let seededGymName = "Klättervigören Jönköping"
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    func testFirstLaunchWizardReachesTheApp() {
        let app = launchWithResetOnboarding()

        let getStarted = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: timeout))
        getStarted.tap()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        XCTAssertFalse(next.isEnabled, "Continue stays disabled until a name is entered")

        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: timeout))
        nameField.tap()
        nameField.typeText("Liam")
        XCTAssertTrue(next.isEnabled)

        next.tap()
        XCTAssertTrue(app.buttons["onboarding.photo"].waitForExistence(timeout: timeout))

        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: timeout))
        next.tap()

        // Leaving the photo unset keeps the step valid.
        XCTAssertTrue(app.buttons["onboarding.photo"].waitForExistence(timeout: timeout))
        next.tap()

        let seededGym = app.buttons["onboarding.gym.\(seededGymName)"]
        XCTAssertTrue(seededGym.waitForExistence(timeout: timeout))
        XCTAssertFalse(next.isEnabled, "Continue stays disabled until a gym is chosen")
        seededGym.tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()

        let vScale = app.buttons["onboarding.grade.vScale"]
        XCTAssertTrue(vScale.waitForExistence(timeout: timeout))
        vScale.tap()
        next.tap()

        let skipShoes = app.buttons["onboarding.skip"]
        XCTAssertTrue(skipShoes.waitForExistence(timeout: timeout))
        skipShoes.tap()

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: timeout))
        finish.tap()

        XCTAssertTrue(app.buttons["Climb"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Profile"].exists)
        XCTAssertFalse(app.buttons["onboarding.finish"].exists)
    }

    private func launchWithResetOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetOnboarding", "YES"]
        app.launch()
        return app
    }
}
