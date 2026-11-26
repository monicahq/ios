import XCTest

/// How a UI test opens the app: in a given language and text size, without changing the
/// simulator's settings.
@MainActor
func launchApp(language: String? = nil, textSize: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    if let language {
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
    }
    if let textSize {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
    }
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
}
