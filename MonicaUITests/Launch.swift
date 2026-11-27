import XCTest

/// How a UI test opens the app: in a given language and text size, without changing the
/// simulator's settings. Each launch gets a fresh preferences store (and Keychain) unless the test
/// passes the store of an earlier launch, to check what the app kept.
///
/// The app never reaches the network in UI tests: every instance is a fake Monica playing
/// `server` (see `FakeMonica.forUITests()`: compatible, unreachable, notMonica, monicaTooOld,
/// appTooOld, registrationClosed, renewalRefused, shortLived, notAllowed, offlineAfterSignIn), and
/// the browser sheet answers `browser` (allow, deny or cancel).
@MainActor
func launchApp(
    language: String? = nil,
    textSize: String? = nil,
    preferences: String = UUID().uuidString,
    server: String = "compatible",
    browser: String = "allow"
) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["MONICA_UI_TEST_SERVER"] = server
    app.launchEnvironment["MONICA_UI_TEST_BROWSER"] = browser
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

/// The home's heading once the fake Monica signed the person in.
let homeGreeting = "Hello, Michael Scott"

@MainActor
extension XCUIApplication {
    /// Taps Log in on the welcome screen and waits for the home.
    func logIn(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(buttons["Log in"].waitForExistence(timeout: 10), file: file, line: line)
        buttons["Log in"].scrolledTo(in: self).tap()
        XCTAssertTrue(staticTexts[homeGreeting].waitForExistence(timeout: 10), file: file, line: line)
    }
}
