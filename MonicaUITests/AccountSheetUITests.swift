import XCTest

/// The placeholder home of a signed-in person.
final class HomeScreenUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func signedIn(
        server: String = "compatible",
        language: String? = nil,
        preferences: String = UUID().uuidString
    ) -> XCUIApplication {
        let app = launchApp(language: language, preferences: preferences, server: server)
        app.logIn()
        return app
    }

    @MainActor
    func testShowsWhoIsSignedInAndWhere() {
        let app = signedIn()

        XCTAssertTrue(app.staticTexts[homeGreeting].exists)
        XCTAssertTrue(app.buttons["Connected to app.monicahq.com"].exists)
        XCTAssertTrue(app.buttons["Log out"].exists)
    }

    @MainActor
    func testShowsInFrench() {
        let app = launchApp(language: "fr")
        XCTAssertTrue(app.buttons["Connexion"].waitForExistence(timeout: 10))
        app.buttons["Connexion"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts["Bonjour, Michael Scott"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Connecté à app.monicahq.com"].exists)
        XCTAssertTrue(app.buttons["Déconnexion"].exists)
    }

    @MainActor
    func testLogOutAsksFirstThenShowsTheWelcomeScreen() {
        let app = signedIn()

        app.buttons["Log out"].tap()
        XCTAssertTrue(app.alerts["Log out?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Log out"].tap()

        XCTAssertTrue(app.staticTexts["Welcome to Monica"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testCancellingLogOutStaysSignedIn() {
        let app = signedIn()

        app.buttons["Log out"].tap()
        XCTAssertTrue(app.alerts["Log out?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts[homeGreeting].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwitchingInstanceAsksFirstThenAsksToLogInThere() {
        let app = signedIn()

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
        let app = signedIn(server: "notAllowed")

        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[homeGreeting].exists)
    }

    @MainActor
    func testOfflineIsSaidWhileStayingSignedIn() {
        let app = signedIn(server: "offlineAfterSignIn")

        XCTAssertTrue(app.staticTexts["Can't reach this instance. Check the address and your connection, then try again."]
            .waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[homeGreeting].exists)
    }

    @MainActor
    func testControlsAreAtLeast44Points() {
        let app = signedIn()

        for button in [app.buttons["Log out"], app.buttons["Connected to app.monicahq.com"]] {
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, button.label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditInLightAppearance() throws {
        let app = signedIn()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = signedIn()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAMessage() throws {
        let app = signedIn(server: "notAllowed")
        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = launchApp(textSize: "UICTContentSizeCategoryAccessibilityXXXL", server: "notAllowed")
        app.logIn()

        XCTAssertTrue(app.staticTexts["You're not allowed to do this."].waitForExistence(timeout: 10))
        for element in [
            app.staticTexts[homeGreeting],
            app.buttons["Connected to app.monicahq.com"],
            app.staticTexts["You're not allowed to do this."],
            app.buttons["Log out"],
        ] {
            XCTAssertTrue(element.scrolledTo(in: app).isHittable, element.label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithTheInstanceSheetOpen() throws {
        let app = signedIn()
        app.buttons["Connected to app.monicahq.com"].tap()
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: 5))

        try app.auditAccessibility()
    }
}
