# Testing

Every change ships with unit tests (see the constitution, principles III and IV). There is **no UI
test target**: XCUITest suites were too slow for what they caught. The app is tested where its logic
lives instead, and the logic MUST live where it can be tested:

| What | Tested by |
|------|-----------|
| View models: every `UiState`, every event | Unit tests in `MonicaTests` |
| Repositories, mappers, API errors, session | Unit tests against `FakeMonica` |
| User journeys (sign in, list vaults, create one, log out...) | Unit tests chaining the view models and repositories of each step |
| How a screen draws a state | SwiftUI previews (light and dark) and a check by hand on a simulator |
| Accessibility | `accessibility-reviewer` agent, Accessibility Inspector audit, VoiceOver by hand ([accessibility.md](accessibility.md)) |

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

## Screens

A screen is a stateless function of its `UiState` (see [architecture.md](architecture.md)). It holds
no decision: what to show, which message, what a tap does all come from the view model, which is
unit tested. A pure function a screen needs (like `Welcome/Highlight.swift`) goes in its own file,
with its own unit test. Each screen has `#Preview`s of its states, in light and dark appearance, to
see them without running the app.

## Coverage

`scripts/check-coverage.sh` reads the unit tests' result bundle and fails when the line coverage of
non-UI code is under 80%. `MonicaApp.swift`, `*Screen.swift` and `*View.swift` files and `Theme/`
are excluded: they hold no logic and are checked through previews and by hand. So keep logic out
of screen files: a pure function
a screen needs (like `Welcome/Highlight.swift`) goes in its own file, with its own unit test.

## Preferences

`InstanceRepository` and the view models using it are tested with a real `UserDefaults` in a
store of its own (`temporaryDefaults()` in `MonicaTests/Instance/InstanceRepositoryTests.swift`),
rather than a fake behind a protocol that would exist only for the tests.

## The offline copy

The same way, tests use a real `OfflineCopy` on a temporary folder of its own (`Harness` makes one
per test, and `relaunched(copy:)` reuses the folder, as the app does after a relaunch). What must be
proven is that files really are kept, read back and deleted, which a fake could not show. Data
Protection itself cannot be observed in the simulator and is checked by hand on a device
(`specs/004-offline-reading/quickstart.md`).

Every screen that reads offline tests, in its view model and repository tests (constitution,
principle VIII): the copy shown when the instance cannot be reached, the "not up to date" state
(`staleSince`), the copy replaced by the instance's answer, and that its data is gone once the
session ended.

## A fake Monica

The app never reaches the network in tests. `Monica/Debug/FakeMonica.swift` (Debug builds only)
plays a Monica instance in memory through a `URLProtocol`: status, OAuth metadata, token,
revocation and `/api/v1/me`.

- Unit tests create a `FakeMonica()` per test, on a host of its own so tests running at the same
  time never share one, change its `settings` (unreachable, refused renewal, another issuer...) or
  answer a request themselves with `settings.override`, and read the `requests` it received.
  `MonicaTests/Support/Fakes.swift` wires it to the app's types with an in-memory Keychain
  (`FakeSecretStore`) and a clock moved by hand (`FakeClock`), in `Harness`.
- The fake also holds the account's vaults (`settings.vaults`, empty like a new account) and
  answers the vault endpoints: the list (paged), one vault, and creating one, with a plan ceiling
  (`vaultLimit`), vaults deleted meanwhile (`goneVaultIDs`), a list that goes offline after a number
  of answers (`vaultListFailsAfter`) or answers late (`vaultListDelay`).
- The app itself never uses the fake. Screens are checked by hand against a real instance, for
  example a Monica running on your machine (see the README), before a pull request (see the
  feature's `quickstart.md`), and in their `#Preview`s for every state.

## Languages

`LocalizationParityTests` fails when a string of the catalog is missing, or loses a placeholder, in
one of the supported languages. To see a screen in another language, launch the app with
`-AppleLanguages '(fr)' -AppleLocale fr_FR`.

## Running locally

```sh
DEST='platform=iOS Simulator,name=iPhone 17'
rm -rf build/unit-tests.xcresult   # xcodebuild refuses to overwrite a result bundle
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" -only-testing:MonicaTests \
  -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult   # coverage gate
```

Pass `-resultBundlePath build/tests.xcresult` and open the bundle in Xcode for the full report.
CI runs them, with the coverage gate, on every pull request.
