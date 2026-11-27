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
    func testTheChosenInstanceIsKeptAfterRelaunching() {
        let preferences = UUID().uuidString
        let app = launchApp(preferences: preferences)
        XCTAssertTrue(app.buttons["Instance settings"].waitForExistence(timeout: 10))
        app.buttons["Instance settings"].tap()
        app.textFields["Address"].replaceText(with: "http://192.168.1.10:8080/monica")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Instance: 192.168.1.10:8080/monica"].waitForExistence(timeout: 5))
        app.terminate()

        let relaunched = launchApp(preferences: preferences)

        XCTAssertTrue(relaunched.buttons["Instance: 192.168.1.10:8080/monica"].waitForExistence(timeout: 10))
    }
}
