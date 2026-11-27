import XCTest

/// The list of vaults a signed-in person lands on (specs/003-vaults-list, user stories 1, 2 and 5).
final class VaultsScreenUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func signedIn(
        server: String = "withVaults",
        language: String? = nil,
        textSize: String? = nil,
        reduceTransparency: Bool = false
    ) -> XCUIApplication {
        let app = launchApp(language: language, textSize: textSize, server: server, reduceTransparency: reduceTransparency)
        app.logIn()
        return app
    }

    // MARK: The list (US1)

    @MainActor
    func testShowsEveryVaultInOrderWithItsContactsAndTheDefault() {
        let app = signedIn()

        let personal = app.buttons["Personal, 25 contacts, Default"]
        let family = app.buttons["Family, 1 contact"]
        let work = app.buttons["Work, No contacts"]
        XCTAssertTrue(personal.waitForExistence(timeout: 10))
        XCTAssertTrue(family.exists)
        XCTAssertTrue(work.exists)
        XCTAssertLessThan(personal.frame.minY, family.frame.minY)
        XCTAssertLessThan(family.frame.minY, work.frame.minY)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Default").count, 1)
        XCTAssertTrue(app.buttons["Your account"].exists)
        XCTAssertTrue(app.buttons["New vault"].exists)
    }

    @MainActor
    func testStaysOnTheListAfterARelaunch() {
        let preferences = UUID().uuidString
        let app = launchApp(preferences: preferences, server: "withVaults")
        app.logIn()
        app.terminate()

        let relaunched = launchApp(preferences: preferences, server: "withVaults")

        XCTAssertTrue(relaunched.vaultCard("Personal").waitForExistence(timeout: 10))
    }

    @MainActor
    func testShowsThatItIsLoading() {
        let app = launchApp(server: "slowVaults")
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 10))
        app.buttons["Log in"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts["Loading your vaults"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No vault yet"].exists)
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))
    }

    @MainActor
    func testAFailedLoadSaysWhyAndCanBeTriedAgain() {
        let app = signedIn(server: "vaultsUnreachable")

        XCTAssertTrue(app.staticTexts["Can't reach this instance. Check the address and your connection, then try again."]
            .waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Try again"].exists)
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPullingDownReloadsAndAFailureKeepsTheList() {
        let app = signedIn(server: "vaultsOfflineAfterFirst")
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))

        XCTAssertTrue(app.staticTexts["Your vaults could not be updated."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.vaultCard("Personal").exists)
        app.buttons["Dismiss"].tap()
        XCTAssertFalse(app.staticTexts["Your vaults could not be updated."].waitForExistence(timeout: 2))
    }

    @MainActor
    func testEveryVaultIsReachableWithManyVaults() {
        let app = signedIn(server: "manyVaults")
        XCTAssertTrue(app.vaultCard("Vault 1").waitForExistence(timeout: 10))

        let last = app.vaultCard("Vault 150")
        var swipes = 0
        while !last.isHittable, swipes < 60 {
            app.swipeUp(velocity: .fast)
            swipes += 1
        }

        XCTAssertTrue(last.isHittable)
        // At the very end of the list, the floating button never covers the last card.
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        XCTAssertLessThanOrEqual(last.frame.maxY, app.buttons["New vault"].frame.minY + 1)
    }

    @MainActor
    func testCardsAndControlsAreAtLeast44Points() {
        let app = signedIn()
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        for element in [app.vaultCard("Personal"), app.buttons["Your account"], app.buttons["New vault"]] {
            XCTAssertGreaterThanOrEqual(element.frame.height, 44, element.label)
            XCTAssertGreaterThanOrEqual(element.frame.width, 44, element.label)
        }
    }

    @MainActor
    func testShowsInFrench() {
        let app = launchApp(language: "fr", server: "withVaults")
        XCTAssertTrue(app.buttons["Connexion"].waitForExistence(timeout: 10))
        app.buttons["Connexion"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts["Tous vos coffres"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Personal, 25 contacts, Par défaut"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Work, Aucun contact"].exists)
        XCTAssertTrue(app.buttons["Votre compte"].exists)
        XCTAssertTrue(app.buttons["Nouveau coffre"].exists)
    }

    @MainActor
    func testEverythingIsReachableWithTheLargestTextSize() {
        let app = signedIn(textSize: "UICTContentSizeCategoryAccessibilityXXXL")

        for element in [app.vaultCard("Personal"), app.vaultCard("Family"), app.vaultCard("Work")] {
            XCTAssertTrue(element.waitForExistence(timeout: 10))
            XCTAssertTrue(element.scrolledTo(in: app).isHittable, element.label)
        }
    }

    // MARK: The empty state (US2)

    @MainActor
    func testAnAccountWithoutVaultsExplainsAndOffersToCreateOne() {
        let app = signedIn(server: "compatible")

        XCTAssertTrue(app.staticTexts["No vault yet"].waitForExistence(timeout: 10))
        // Queries by identifier stop at 128 characters: the explanation is found by its start.
        let explanation = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@",
            "A vault holds the people you want to remember"
        ))
        XCTAssertTrue(explanation.firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(identifier: "New vault").count, 1)
    }

    @MainActor
    func testTheEmptyStateIsReadableWithTheLargestTextSize() {
        let app = signedIn(server: "compatible", textSize: "UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertTrue(app.staticTexts["No vault yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["New vault"].scrolledTo(in: app).isHittable)
    }

    // MARK: Accessibility audit (US5)

    @MainActor
    func testPassesTheAccessibilityAuditWithVaults() throws {
        let app = signedIn()
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithVaultsInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = signedIn()
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithReduceTransparency() throws {
        let app = signedIn(reduceTransparency: true)
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithReduceTransparencyInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = signedIn(reduceTransparency: true)
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhenEmpty() throws {
        let app = signedIn(server: "compatible")
        XCTAssertTrue(app.staticTexts["No vault yet"].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhenEmptyInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = signedIn(server: "compatible")
        XCTAssertTrue(app.staticTexts["No vault yet"].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhenTheLoadFailed() throws {
        let app = signedIn(server: "vaultsUnreachable")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhenTheLoadFailedInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = signedIn(server: "vaultsUnreachable")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWithTheRefreshMessage() throws {
        let app = signedIn(server: "vaultsOfflineAfterFirst")
        XCTAssertTrue(app.vaultCard("Personal").waitForExistence(timeout: 10))
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertTrue(app.staticTexts["Your vaults could not be updated."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Try again"].exists)

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhileLoading() throws {
        let app = launchApp(server: "slowVaults")
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 10))
        app.buttons["Log in"].scrolledTo(in: app).tap()
        XCTAssertTrue(app.staticTexts["Loading your vaults"].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }
}
