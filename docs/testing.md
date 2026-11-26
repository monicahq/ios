# Testing

Every change ships with tests. Two kinds are mandatory (see the constitution, principles III and IV).

| Kind | Target | Runs on | Covers | Command |
|------|--------|---------|--------|---------|
| Unit | `MonicaTests` | Simulator (hosted in the app) | View models, repositories, mappers, any non-UI logic | `xcodebuild test ... -only-testing:MonicaTests` |
| UI | `MonicaUITests` | Simulator | Every screen's states and interactions, user journeys | `xcodebuild test ... -only-testing:MonicaUITests` |

## Unit tests

- Written with **Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`).
- One test suite per production type, in the same folder structure as `Monica/`.
- Use **fakes** (simple in-memory implementations of a protocol), not mocking frameworks.
- Test `async` code with `async` tests; inject clocks rather than sleeping.
- Test every `UiState` a view model can produce and every event it handles.
- Fixing a bug? Write the failing test first.

```swift
@MainActor
struct ContactsViewModelTests {
    @Test func `shows the contacts the repository returns`() async {
        let viewModel = ContactsViewModel(repository: FakeContactsRepository(contacts: [.ada]))

        await viewModel.load()

        #expect(viewModel.state == .success([.ada]))
    }
}
```

## UI tests

- Written with **XCTest UI testing** (`XCUIApplication`), one `XCTestCase` per screen.
- Launch the app on the screen and in the state to test, assert what is shown, perform the
  interactions, check the result.
- Find elements by what people see or hear: `app.buttons["Log in"]`, `app.staticTexts[...]`.
  Use `accessibilityIdentifier` only as a last resort.
- Each user journey from a spec gets at least one end-to-end test.
- Each screen has a test running the automated accessibility audit
  (`performAccessibilityAudit()`), see [accessibility.md](accessibility.md).

```swift
final class ContactsScreenUITests: XCTestCase {
    @MainActor
    func testShowsContactNames() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Ada"].waitForExistence(timeout: 5))
    }
}
```

## Coverage

`scripts/check-coverage.sh` reads the unit tests' result bundle and fails when the line coverage of
non-UI code is under 80%. `MonicaApp.swift`, `*Screen.swift` and `*View.swift` files and `Theme/`
are excluded: they are covered by the UI tests. So keep logic out of screen files: a pure function
a screen needs (like `Welcome/Highlight.swift`) goes in its own file, with its own unit test.

## Languages

`LocalizationParityTests` fails when a string of the catalog is missing, or loses a placeholder, in
one of the supported languages. UI tests show a screen in another language without changing the
simulator's by launching the app with `-AppleLanguages (fr) -AppleLocale fr` (see `launchApp` in
`MonicaUITests/Launch.swift`).

## Running locally

```sh
DEST='platform=iOS Simulator,name=iPhone 17'
rm -rf build/unit-tests.xcresult   # xcodebuild refuses to overwrite a result bundle
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" -only-testing:MonicaTests \
  -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult   # coverage gate
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" -only-testing:MonicaUITests
```

Pass `-resultBundlePath build/tests.xcresult` and open the bundle in Xcode for the full report.
CI runs both suites on every pull request.
