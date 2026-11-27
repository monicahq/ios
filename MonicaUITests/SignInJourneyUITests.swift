import XCTest

/// One journey per user story of `specs/002-login-registration`, end to end against a fake Monica.
final class SignInJourneyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// US1: log in on the official instance, and stay signed in after a relaunch.
    @MainActor
    func testLogInAndStaySignedIn() {
        let preferences = UUID().uuidString
        let app = launchApp(preferences: preferences)

        app.logIn()
        app.terminate()
        let relaunched = launchApp(preferences: preferences)

        XCTAssertTrue(relaunched.staticTexts[vaultsTitle].waitForExistence(timeout: 10))
    }

    /// US2: choose a self-hosted instance served under a path, then log in to it.
    @MainActor
    func testLogInToASelfHostedInstance() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Instance settings"].waitForExistence(timeout: 10))
        app.buttons["Instance settings"].tap()
        app.textFields["Address"].replaceText(with: "example.com/monica")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Instance: example.com/monica"].waitForExistence(timeout: 10))

        app.logIn()
        app.openAccount()

        XCTAssertTrue(app.buttons["Connected to example.com/monica"].exists)
    }

    /// US3: sign up, and come back signed in.
    @MainActor
    func testSignUp() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Sign up"].waitForExistence(timeout: 10))

        app.buttons["Sign up"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts[vaultsTitle].waitForExistence(timeout: 10))
    }

    /// US4: access expires right away and is renewed without the person noticing.
    @MainActor
    func testStaySignedInWhenAccessExpires() {
        let app = launchApp(server: "shortLived")

        app.logIn()

        // The list loads the vaults on appear, which renews the expired access.
        XCTAssertFalse(app.staticTexts["Your session was ended. Log in again."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[vaultsTitle].exists)
    }

    /// US5: log out, and stay logged out after a relaunch.
    @MainActor
    func testLogOutAndStayLoggedOut() {
        let preferences = UUID().uuidString
        let app = launchApp(preferences: preferences)
        app.logIn()

        app.logOut()
        app.terminate()
        let relaunched = launchApp(preferences: preferences)

        XCTAssertTrue(relaunched.staticTexts["Welcome to Monica"].waitForExistence(timeout: 10))
    }
}
