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
    private func open(language: String? = nil, textSize: String? = nil) -> XCUIApplication {
        let app = launchApp(language: language, textSize: textSize)
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
    func testTappingTheControlsDoesNothingYet() {
        let app = open()

        app.buttons["Instance settings"].tap()
        app.buttons["Sign up"].scrolledTo(in: app).tap()
        app.buttons["Log in"].scrolledTo(in: app).tap()
        app.buttons[instanceLine].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertEqual(app.windows.count, 1)
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

        try app.performAccessibilityAudit()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        try inDarkAppearance {
            let app = open()

            try app.performAccessibilityAudit()
        }
    }
}
