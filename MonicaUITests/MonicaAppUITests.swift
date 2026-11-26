import XCTest

final class MonicaAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testShowsWelcomeMessage() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Monica"].waitForExistence(timeout: 5))
    }
}
