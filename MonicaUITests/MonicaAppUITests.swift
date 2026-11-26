import XCTest

/// End to end: the app as people open it.
final class MonicaAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOpensOnTheWelcomeScreenWithTheDefaultInstance() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Welcome to Monica"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Instance: app.monicahq.com"].scrolledTo(in: app).isHittable)
    }

    @MainActor
    func testTappingLogInDoesNothingYet() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Welcome to Monica"].waitForExistence(timeout: 10))

        app.buttons["Log in"].scrolledTo(in: app).tap()

        XCTAssertTrue(app.staticTexts["Welcome to Monica"].exists)
    }
}
