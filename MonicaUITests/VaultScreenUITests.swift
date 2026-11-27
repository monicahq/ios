import XCTest

/// The placeholder screen of one vault, opened from the list (specs/003-vaults-list, user story 1).
final class VaultScreenUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openWork(server: String = "withVaults") -> XCUIApplication {
        let app = launchApp(server: server)
        app.logIn()
        XCTAssertTrue(app.vaultCard("Work").waitForExistence(timeout: 10))
        app.vaultCard("Work").tap()
        return app
    }

    @MainActor
    func testShowsTheVaultAndGoesBackToTheList() {
        let app = openWork()

        XCTAssertTrue(app.staticTexts["Dunder Mifflin, Scranton branch."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(identifier: "Work").firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts[vaultsTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.vaultCard("Work").exists)
    }

    @MainActor
    func testAVaultDeletedMeanwhileSaysSoAndLeadsBack() {
        let app = openWork(server: "vaultGone")

        XCTAssertTrue(app.staticTexts["This vault no longer exists."].waitForExistence(timeout: 10))
        app.buttons["Back to your vaults"].tap()

        XCTAssertTrue(app.staticTexts[vaultsTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIsReadableWithTheLargestTextSize() {
        let app = launchApp(textSize: "UICTContentSizeCategoryAccessibilityXXXL", server: "withVaults")
        app.logIn()
        app.vaultCard("Work").scrolledTo(in: app).tap()

        let description = app.staticTexts["Dunder Mifflin, Scranton branch."]
        XCTAssertTrue(description.waitForExistence(timeout: 10))
        XCTAssertTrue(description.scrolledTo(in: app).isHittable)
    }

    @MainActor
    func testPassesTheAccessibilityAudit() throws {
        let app = openWork()
        XCTAssertTrue(app.staticTexts["Dunder Mifflin, Scranton branch."].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditInDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = openWork()
        XCTAssertTrue(app.staticTexts["Dunder Mifflin, Scranton branch."].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }

    @MainActor
    func testPassesTheAccessibilityAuditWhenNotFound() throws {
        let app = openWork(server: "vaultGone")
        XCTAssertTrue(app.staticTexts["This vault no longer exists."].waitForExistence(timeout: 10))

        try app.auditAccessibility()
    }
}
