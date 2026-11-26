import XCTest

/// How a UI test opens the app: in a given language and text size, without changing the
/// simulator's settings. Each launch gets a fresh preferences store unless the test passes the
/// store of an earlier launch, to check what the app kept.
@MainActor
func launchApp(
    language: String? = nil,
    textSize: String? = nil,
    preferences: String = UUID().uuidString
) -> XCUIApplication {
    let app = XCUIApplication()
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
