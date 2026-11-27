import XCTest

/// Creating a vault, from the empty state or the list (specs/003-vaults-list, user story 3).
final class NewVaultScreenUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func formOpen(server: String = "withVaults", language: String? = nil) -> XCUIApplication {
        let app = launchApp(language: language, server: server)
        if language == "fr" {
            XCTAssertTrue(app.buttons["Connexion"].waitForExistence(timeout: 10))
            app.buttons["Connexion"].scrolledTo(in: app).tap()
            XCTAssertTrue(app.staticTexts["Tous vos coffres"].waitForExistence(timeout: 10))
        } else {
            app.logIn()
        }
        let button = app.buttons[language == "fr" ? "Nouveau coffre" : "New vault"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func type(_ text: String, in field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    @MainActor
    func testCreatesTheFirstVaultFromTheEmptyStateAsTheDefault() {
        let app = formOpen(server: "compatible")
        XCTAssertFalse(app.switches["Make this the default vault"].exists)

        type("Personal", in: app.textFields["Name"])
        app.buttons["Create vault"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.buttons["Personal, No contacts, Default"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No vault yet"].exists)
    }

    @MainActor
    func testCreatesAVaultAtTheEndAndCanMakeItTheDefault() {
        let app = formOpen()

        type("Book club", in: app.textFields["Name"])
        type("Readers", in: app.textFields["Description (optional)"])
        app.buttons["Teal"].scrolledTo(in: app).tap()
        XCTAssertTrue(app.buttons["Teal"].isSelected)
        app.switches["Make this the default vault"].scrolledTo(in: app).switches.firstMatch.tap()
        app.buttons["Create vault"].scrolledTo(in: app).tap()

        let created = app.buttons["Book club, No contacts, Default"]
        XCTAssertTrue(created.waitForExistence(timeout: 10))
        XCTAssertTrue(app.vaultCard("Personal").exists)
        XCTAssertFalse(app.buttons["Personal, 25 contacts, Default"].exists)
        XCTAssertGreaterThan(created.frame.minY, app.vaultCard("Work").frame.minY)
    }

    @MainActor
    func testABlankNameCannotBeCreated() {
        let app = formOpen()

        XCTAssertFalse(app.buttons["Create vault"].isEnabled)
        type("   ", in: app.textFields["Name"])

        XCTAssertFalse(app.buttons["Create vault"].isEnabled)
    }

    @MainActor
    func testColoursAreReadByNameWithTheSelectedOne() {
        let app = formOpen()

        for name in ["Blue", "Green", "Ochre", "Rust", "Violet", "Teal", "Rose", "Graphite"] {
            XCTAssertTrue(app.buttons[name].exists, name)
        }
        XCTAssertTrue(app.buttons["Blue"].isSelected)
        XCTAssertFalse(app.buttons["Rose"].isSelected)
    }

    @MainActor
    func testTheInstanceRefusalIsShownAndEverythingTypedStays() {
        let app = formOpen(server: "vaultLimit")
        type("Work", in: app.textFields["Name"])
        app.buttons["Rust"].tap()

        app.buttons["Create vault"].scrolledTo(in: app).tap()

        let message = "The free plan holds 1 vault, and this account already has it. Full access lifts the ceiling."
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["Name"].value as? String, "Work")
        XCTAssertTrue(app.buttons["Rust"].isSelected)
    }

    @MainActor
    func testCancellingWithSomethingTypedAsksFirst() {
        let app = formOpen()
        type("Book club", in: app.textFields["Name"])

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts["Discard this vault?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(app.textFields["Name"].value as? String, "Book club")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Discard"].waitForExistence(timeout: 5))
        app.alerts.buttons["Discard"].tap()
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 5))
        XCTAssertFalse(app.vaultCard("Book club").exists)
    }

    @MainActor
    func testSwipingDownWithSomethingTypedDoesNotClose() {
        let app = formOpen()
        type("Book club", in: app.textFields["Name"])

        app.staticTexts["Colour"].swipeDown(velocity: .fast)

        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCancellingAnUntouchedFormCloses() {
        let app = formOpen()

        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Discard this vault?"].exists)
    }

    @MainActor
    func testShowsInFrench() {
        let app = formOpen(language: "fr")

        XCTAssertTrue(app.textFields["Nom"].exists)
        XCTAssertTrue(app.buttons["Créer le coffre"].exists)
        XCTAssertTrue(app.buttons["Bleu canard"].exists)
        XCTAssertTrue(app.switches["Faire de ce coffre le coffre par défaut"].exists)
    }

    @MainActor
    func testControlsAreAtLeast44Points() {
        let app = formOpen()

        for element in [app.buttons["Cancel"], app.buttons["Blue"], app.buttons["Graphite"], app.buttons["Create vault"]] {
            XCTAssertGreaterThanOrEqual(element.frame.height, 44, element.label)
            XCTAssertGreaterThanOrEqual(element.frame.width, 44, element.label)
        }
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = launchApp(textSize: "UICTContentSizeCategoryAccessibilityXXXL", server: "withVaults")
        app.logIn()
        app.buttons["New vault"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))

        for element in [
            app.textFields["Name"], app.textFields["Description (optional)"], app.buttons["Graphite"],
            app.switches["Make this the default vault"], app.buttons["Create vault"],
        ] {
            XCTAssertTrue(element.scrolledTo(in: app).isHittable, element.label)
        }
    }

    @MainActor
    func testPassesTheAccessibilityAudit() throws {
        let app = formOpen()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = formOpen()

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithARefusal() throws {
        let app = formOpen(server: "vaultLimit")
        type("Work", in: app.textFields["Name"])
        app.buttons["Create vault"].scrolledTo(in: app).tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "The free plan")).firstMatch
            .waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }
}
