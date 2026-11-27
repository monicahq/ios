import XCTest

/// The sheet of the welcome screen where a person chooses their Monica instance.
final class InstanceSheetUITests: XCTestCase {
    private let sheetTitle = "Instance URL"
    private let invalidMessage = "Enter an address like https://monica.example.com"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens the app and the sheet through the settings button.
    @MainActor
    private func openSheet(language: String? = nil, textSize: String? = nil) -> XCUIApplication {
        let app = launchApp(language: language, textSize: textSize)
        let settings = app.buttons[language == "fr" ? "Paramètres de l'instance" : "Instance settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func waitForSheetToClose(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts[sheetTitle].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testSettingsButtonOpensTheSheetWithTheCurrentAddress() {
        let app = openSheet()

        XCTAssertTrue(app.staticTexts[sheetTitle].exists)
        let explanation = "The address of the Monica server the app connects to. "
            + "Keep the default to use the hosted service, or enter the address of your own instance."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", explanation)).firstMatch.exists)
        XCTAssertEqual(app.textFields["Address"].value as? String, "https://app.monicahq.com")
        XCTAssertTrue(app.buttons["Reset to default"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Save"].exists)
    }

    @MainActor
    func testInstanceLineOpensTheSheet() {
        let app = launchApp()
        let line = app.buttons["Instance: app.monicahq.com"]
        XCTAssertTrue(line.waitForExistence(timeout: 10))

        line.scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts[sheetTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavingAnAddressShowsItOnTheWelcomeScreen() {
        let app = openSheet()

        app.textFields["Address"].replaceText(with: "monica.example.com")
        app.buttons["Save"].tap()

        waitForSheetToClose(app)
        XCTAssertTrue(app.buttons["Instance: monica.example.com"].exists)
    }

    @MainActor
    func testSavingWithTheKeyboardShowsTheAddress() {
        let app = openSheet()

        app.textFields["Address"].replaceText(with: "https://monica.example.com\n")

        waitForSheetToClose(app)
        XCTAssertTrue(app.buttons["Instance: monica.example.com"].exists)
    }

    @MainActor
    func testCancelKeepsTheAddress() {
        let app = openSheet()

        app.textFields["Address"].replaceText(with: "monica.example.com")
        app.buttons["Cancel"].tap()

        waitForSheetToClose(app)
        XCTAssertTrue(app.buttons["Instance: app.monicahq.com"].exists)
    }

    @MainActor
    func testSwipingTheSheetDownKeepsTheAddress() {
        let app = openSheet()

        app.textFields["Address"].replaceText(with: "monica.example.com")
        // Pulled down by its grabber: a swipe on the content scrolls it.
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
        app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: bottom)

        waitForSheetToClose(app)
        XCTAssertTrue(app.buttons["Instance: app.monicahq.com"].exists)
    }

    @MainActor
    func testResetPutsTheDefaultAddressBackWithoutSaving() {
        let app = openSheet()
        app.textFields["Address"].replaceText(with: "monica.example.com")
        app.buttons["Save"].tap()
        waitForSheetToClose(app)
        app.buttons["Instance settings"].tap()

        app.buttons["Reset to default"].tap()

        XCTAssertEqual(app.textFields["Address"].value as? String, "https://app.monicahq.com")
        app.buttons["Cancel"].tap()
        waitForSheetToClose(app)
        XCTAssertTrue(app.buttons["Instance: monica.example.com"].exists)
    }

    @MainActor
    func testAnInvalidAddressIsRefusedWithAMessage() {
        let app = openSheet()

        app.textFields["Address"].replaceText(with: "not an address")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[invalidMessage].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[sheetTitle].exists)
    }

    @MainActor
    func testShowsInFrench() {
        let app = openSheet(language: "fr")

        XCTAssertTrue(app.staticTexts["URL de l'instance"].exists)
        XCTAssertTrue(app.textFields["Adresse"].exists)
        XCTAssertTrue(app.buttons["Rétablir par défaut"].exists)
        XCTAssertTrue(app.buttons["Annuler"].exists)
        XCTAssertTrue(app.buttons["Sauvegarder"].exists)
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = openSheet(textSize: "UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertTrue(app.textFields["Address"].scrolledTo(in: app).isHittable)
        for label in ["Reset to default", "Cancel", "Save"] {
            XCTAssertTrue(app.buttons[label].scrolledTo(in: app).isHittable, label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAuditInLightAppearance() throws {
        let app = openSheet()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = openSheet()

        try app.auditAccessibility()
    }

    @MainActor
    private func showError(_ app: XCUIApplication) {
        app.textFields["Address"].replaceText(with: "not an address")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[invalidMessage].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAnError() throws {
        let app = openSheet()
        showError(app)

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithAnErrorInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = openSheet()
        showError(app)

        try app.auditAccessibility()
    }

    @MainActor
    func testControlsAreAtLeast44Points() {
        let app = openSheet()

        for label in ["Reset to default", "Cancel", "Save"] {
            let frame = app.buttons[label].frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, label)
            XCTAssertGreaterThanOrEqual(frame.height, 44, label)
        }
    }

    @MainActor
    func testTappingTheEdgeOfTheAddressBoxFocusesTheField() {
        let app = openSheet()

        // 8 pt above the text: inside the field's box, outside the text itself.
        app.textFields["Address"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -8)).tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }
}
