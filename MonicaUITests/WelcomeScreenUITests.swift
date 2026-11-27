import XCTest

final class WelcomeScreenUITests: XCTestCase {
    private let title = "Welcome to Monica"
    private let introduction = "Monica helps you remember and organise your relationships and life context."
    private let illustration = "A panda sitting in the grass, waving"
    private let instanceLine = "Instance: app.monicahq.com"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func open(
        language: String? = nil,
        textSize: String? = nil,
        server: String = "compatible",
        browser: String = "allow"
    ) -> XCUIApplication {
        let app = launchApp(language: language, textSize: textSize, server: server, browser: browser)
        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func inDarkAppearance(_ test: () throws -> Void) rethrows {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        try test()
    }

    @MainActor
    func testShowsEveryElementOfTheDesign() {
        let app = open()

        XCTAssertTrue(app.buttons["Instance settings"].exists)
        XCTAssertTrue(app.staticTexts["Monica"].exists)
        XCTAssertTrue(app.images[illustration].exists)
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.staticTexts[introduction].exists)
        XCTAssertTrue(app.buttons["Sign up"].exists)
        XCTAssertTrue(app.buttons["Log in"].exists)
        XCTAssertTrue(app.buttons[instanceLine].exists)
    }

    @MainActor
    func testShowsTheElementsInTheOrderOfTheDesign() {
        let app = open()

        let elements = [
            app.buttons["Instance settings"],
            app.staticTexts["Monica"],
            app.images[illustration],
            app.staticTexts[title],
            app.staticTexts[introduction],
            app.buttons["Sign up"],
            app.buttons["Log in"],
            app.buttons[instanceLine],
        ]
        let tops = elements.map(\.frame.minY)

        XCTAssertEqual(tops, tops.sorted())
    }

    @MainActor
    func testShowsInFrench() {
        let app = open(language: "fr")

        XCTAssertTrue(app.buttons["Paramètres de l'instance"].exists)
        XCTAssertTrue(app.staticTexts["Monica"].exists)
        XCTAssertTrue(app.images["Un panda assis dans l'herbe qui fait coucou"].exists)
        XCTAssertTrue(app.staticTexts["Bienvenue dans Monica"].exists)
        XCTAssertTrue(
            app.staticTexts["Monica vous aide à vous souvenir et à organiser vos relations et votre contexte de vie."].exists
        )
        XCTAssertTrue(app.buttons["Inscription"].exists)
        XCTAssertTrue(app.buttons["Connexion"].exists)
        XCTAssertTrue(app.buttons["Instance\u{00A0}: app.monicahq.com"].exists)
    }

    @MainActor
    func testShowsInEnglishWhenTheLanguageIsNotSupported() {
        let app = open(language: "de")

        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.buttons["Sign up"].exists)
    }

    @MainActor
    func testShowsInDarkAppearance() {
        inDarkAppearance {
            let app = open()

            XCTAssertTrue(app.staticTexts[title].exists)
            XCTAssertTrue(app.buttons["Sign up"].exists)
        }
    }

    @MainActor
    func testHidesTheLogoFromScreenReaders() {
        let app = open()

        // Icons inside a button are part of the button, which VoiceOver reads as one element.
        let standaloneImages = app.images.count - app.buttons.descendants(matching: .image).count

        XCTAssertFalse(app.images["Logo"].exists)
        XCTAssertEqual(standaloneImages, 1)
        XCTAssertTrue(app.images[illustration].exists)
    }

    @MainActor
    func testControlsAreAtLeast44Points() {
        let app = open()

        for label in ["Instance settings", "Sign up", "Log in", instanceLine] {
            let frame = app.buttons[label].frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, label)
            XCTAssertGreaterThanOrEqual(frame.height, 44, label)
        }
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = open(textSize: "UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertTrue(app.staticTexts[title].exists)
        for label in ["Sign up", "Log in", instanceLine] {
            XCTAssertTrue(app.buttons[label].scrolledTo(in: app).isHittable, label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditInLightAppearance() throws {
        let app = open()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        try inDarkAppearance {
            let app = open()

            try app.auditAccessibility()
        }
    }

    // MARK: Logging in and signing up

    @MainActor
    private func tap(_ label: String, in app: XCUIApplication) {
        app.buttons[label].scrolledTo(in: app).tap()
    }

    @MainActor
    private func expectMessage(_ message: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(app.staticTexts[title].exists, file: file, line: line)
    }

    @MainActor
    func testLogInShowsTheProgressThenTheHome() {
        let app = open(browser: "slow")

        tap("Log in", in: app)

        // Read together with the progress indicator, so the label holds more than the text.
        let progress = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Connecting to app.monicahq.com…")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[homeGreeting].waitForExistence(timeout: 10))
    }

    @MainActor
    func testClosingTheBrowserSaysSignInWasCancelled() {
        let app = open(browser: "cancel")

        tap("Log in", in: app)

        expectMessage("Sign-in was cancelled. Log in again when you're ready.", in: app)
        XCTAssertTrue(app.buttons["Log in"].isEnabled)
    }

    @MainActor
    func testDenyingAccessSaysSo() {
        let app = open(browser: "deny")

        tap("Log in", in: app)

        expectMessage("You did not allow access. Log in again to allow it.", in: app)
    }

    @MainActor
    func testAnUnreachableInstanceIsSaidBeforeOpeningAnything() {
        let app = open(server: "unreachable")

        tap("Log in", in: app)

        expectMessage("Can't reach this instance. Check the address and your connection, then try again.", in: app)
    }

    @MainActor
    func testSignUpOnAClosedInstanceSaysSo() {
        let app = open(server: "registrationClosed")

        tap("Sign up", in: app)

        expectMessage("This instance doesn't accept new accounts. Ask its administrator.", in: app)
    }

    @MainActor
    func testClosingTheBrowserAfterSignUpExplainsTheEmail() {
        let app = open(browser: "cancel")

        tap("Sign up", in: app)

        expectMessage(
            "Not finished yet? Open the link in the email Monica sent you to confirm your address: "
                + "it brings you back here, signed in.",
            in: app
        )
    }

    @MainActor
    func testShowsTheErrorInFrench() {
        let app = open(language: "fr", browser: "cancel")

        tap("Connexion", in: app)

        XCTAssertTrue(app.staticTexts["La connexion a été annulée. Reconnectez-vous quand vous voulez."].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAnError() throws {
        let app = open(browser: "cancel")
        tap("Log in", in: app)
        expectMessage("Sign-in was cancelled. Log in again when you're ready.", in: app)

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAnErrorInDarkAppearance() throws {
        try inDarkAppearance {
            let app = open(browser: "deny")
            tap("Log in", in: app)
            expectMessage("You did not allow access. Log in again to allow it.", in: app)

            try app.auditAccessibility()
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhileSigningIn() throws {
        let app = open(browser: "slow")
        tap("Log in", in: app)
        let progress = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Connecting to app.monicahq.com…")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))

        // Everything but contrast: while signing in, the buttons are dimmed because they cannot be
        // used, which WCAG exempts, and the audit reports them without naming the element. The
        // same screen's contrast is audited when nothing is disabled.
        try app.auditAccessibility(for: XCUIAccessibilityAuditType.all.subtracting(.contrast))
    }

    @MainActor
    func testTheLongestMessageIsReachableWithTheLargestTextSize() {
        let app = open(textSize: "UICTContentSizeCategoryAccessibilityXXXL", browser: "cancel")
        tap("Sign up", in: app)

        let message = app.staticTexts[
            "Not finished yet? Open the link in the email Monica sent you to confirm your address: "
                + "it brings you back here, signed in."
        ]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(message.scrolledTo(in: app).isHittable)
        XCTAssertTrue(app.buttons["Log in"].scrolledTo(in: app).isHittable)
    }
}
