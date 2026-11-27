import XCTest

/// The account sheet, opened from the list of vaults (specs/003-vaults-list, user story 4). It holds
/// what the placeholder home of specs/002-login-registration offered.
final class AccountSheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func accountOpen(server: String = "compatible", textSize: String? = nil) -> XCUIApplication {
        let app = launchApp(textSize: textSize, server: server)
        app.logIn()
        app.openAccount()
        return app
    }

    @MainActor
    func testShowsWhoIsSignedInAndWhere() {
        let app = accountOpen()

        XCTAssertTrue(app.staticTexts["Michael Scott"].exists)
        XCTAssertTrue(app.buttons["Connected to app.monicahq.com"].exists)
        XCTAssertTrue(app.buttons["Log out"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts[vaultsTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    func testShowsInFrench() {
        let app = launchApp(language: "fr")
        XCTAssertTrue(app.buttons["Connexion"].waitForExistence(timeout: 10))
        app.buttons["Connexion"].scrolledTo(in: app).tap()
        XCTAssertTrue(app.buttons["Votre compte"].waitForExistence(timeout: 10))
        app.buttons["Votre compte"].tap()

        XCTAssertTrue(app.buttons["Connecté à app.monicahq.com"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Déconnexion"].exists)
        XCTAssertTrue(app.buttons["Fermer"].exists)
    }

    @MainActor
    func testLogOutAsksFirstThenShowsTheWelcomeScreen() {
        let app = launchApp()
        app.logIn()

        app.logOut()
    }

    @MainActor
    func testCancellingLogOutStaysSignedIn() {
        let app = accountOpen()

        app.buttons["Log out"].tap()
        XCTAssertTrue(app.alerts["Log out?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Log out"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwitchingInstanceAsksFirstThenAsksToLogInThere() {
        let app = accountOpen()

        app.buttons["Connected to app.monicahq.com"].tap()
        app.textFields["Address"].replaceText(with: "monica.example.com")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.alerts["Switch instance?"].waitForExistence(timeout: 10))
        app.alerts.buttons["Switch and log out"].tap()

        XCTAssertTrue(app.staticTexts["Welcome to Monica"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Instance: monica.example.com"].scrolledTo(in: app).exists)
    }

    @MainActor
    func testAnEndedSessionGoesBackToTheWelcomeScreenSayingSo() {
        let app = launchApp(server: "renewalRefused")
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 10))
        app.buttons["Log in"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts["Your session was ended. Log in again."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Welcome to Monica"].exists)
    }

    @MainActor
    func testNotAllowedIsSaidWhileStayingSignedIn() {
        let app = accountOpen(server: "notAllowed")

        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log out"].exists)
    }

    @MainActor
    func testOfflineIsSaidWhileStayingSignedIn() {
        let app = accountOpen(server: "offlineAfterSignIn")

        XCTAssertTrue(app.staticTexts["Can't reach this instance. Check the address and your connection, then try again."]
            .waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log out"].exists)
    }

    @MainActor
    func testControlsAreAtLeast44Points() {
        let app = accountOpen()

        for button in [app.buttons["Log out"], app.buttons["Connected to app.monicahq.com"], app.buttons["Close"]] {
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, button.label)
        }
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = accountOpen(server: "notAllowed", textSize: "UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))
        for element in [
            app.staticTexts["Michael Scott"],
            app.buttons["Connected to app.monicahq.com"],
            app.staticTexts["You're not allowed to do this."],
            app.buttons["Log out"],
        ] {
            XCTAssertTrue(element.scrolledTo(in: app).isHittable, element.label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditInLightAppearance() throws {
        let app = accountOpen()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = accountOpen()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAMessage() throws {
        let app = accountOpen(server: "notAllowed")
        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithTheInstanceSheetOpen() throws {
        let app = accountOpen()
        app.buttons["Connected to app.monicahq.com"].tap()
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: 5))

        try app.auditAccessibility()
    }
}
