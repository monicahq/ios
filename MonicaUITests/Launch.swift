import XCTest

/// How a UI test opens the app: in a given language and text size, without changing the
/// simulator's settings. Each launch gets a fresh preferences store (and Keychain) unless the test
/// passes the store of an earlier launch, to check what the app kept.
///
/// The app never reaches the network in UI tests: every instance is a fake Monica playing
/// `server` (see `FakeMonica.forUITests()`: compatible, unreachable, notMonica, monicaTooOld,
/// appTooOld, registrationClosed, renewalRefused, shortLived, notAllowed, offlineAfterSignIn, and
/// for vaults withVaults, manyVaults, vaultLimit, vaultsUnreachable, vaultsOfflineAfterFirst,
/// vaultGone, slowVaults), and the browser sheet answers `browser` (allow, deny or cancel).
/// `reduceTransparency` draws the floating controls solid, as the system setting does.
@MainActor
func launchApp(
    language: String? = nil,
    textSize: String? = nil,
    preferences: String = UUID().uuidString,
    server: String = "compatible",
    browser: String = "allow",
    reduceTransparency: Bool = false
) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["MONICA_UI_TEST_SERVER"] = server
    app.launchEnvironment["MONICA_UI_TEST_BROWSER"] = browser
    if reduceTransparency {
        app.launchEnvironment["MONICA_UI_TEST_REDUCE_TRANSPARENCY"] = "1"
    }
    if let language {
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
    }
    if let textSize {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
    }
    app.launchEnvironment["MONICA_DEFAULTS_SUITE"] = "MonicaUITests.\(preferences)"
    app.launch()
    return app
}

@MainActor
extension XCUIElement {
    /// Scrolls the app up until the element can be tapped, as a person would.
    func scrolledTo(in app: XCUIApplication, maxSwipes: Int = 8) -> XCUIElement {
        var swipes = 0
        while !isHittable, swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        return self
    }

    /// Replaces the text of a text field, as a person would: cursor at the end, delete, type.
    func replaceText(with text: String) {
        coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = value as? String ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}

@MainActor
extension XCUIApplication {
    /// Runs Apple's accessibility audit and prints every issue with the element it is about, so a
    /// failure on CI says which element to fix. Every issue of the audited `types` fails the test.
    func auditAccessibility(for types: XCUIAccessibilityAuditType = .all) throws {
        try performAccessibilityAudit(for: types) { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)'" } ?? "no element"
            print("Accessibility audit: \(issue.compactDescription) on \(element): \(issue.detailedDescription)")
            return false
        }
    }
}

/// The heading of the list of vaults, where a signed-in person lands.
let vaultsTitle = "All your vaults"

@MainActor
extension XCUIApplication {
    /// Taps Log in on the welcome screen and waits for the list of vaults.
    func logIn(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(buttons["Log in"].waitForExistence(timeout: 10), file: file, line: line)
        buttons["Log in"].scrolledTo(in: self).tap()
        XCTAssertTrue(staticTexts[vaultsTitle].waitForExistence(timeout: 10), file: file, line: line)
    }

    /// Opens the account sheet from the list of vaults.
    func openAccount(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(buttons["Your account"].waitForExistence(timeout: 10), file: file, line: line)
        buttons["Your account"].tap()
        XCTAssertTrue(buttons["Log out"].waitForExistence(timeout: 5), file: file, line: line)
    }

    /// Logs out from the account sheet, confirming, and waits for the welcome screen.
    func logOut(file: StaticString = #filePath, line: UInt = #line) {
        openAccount(file: file, line: line)
        buttons["Log out"].scrolledTo(in: self).tap()
        XCTAssertTrue(alerts["Log out?"].waitForExistence(timeout: 5), file: file, line: line)
        alerts.buttons["Log out"].tap()
        XCTAssertTrue(staticTexts["Welcome to Monica"].waitForExistence(timeout: 10), file: file, line: line)
    }

    /// The card of a vault, found by the start of what VoiceOver reads ("Personal, 25 contacts...").
    func vaultCard(_ name: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }
}
