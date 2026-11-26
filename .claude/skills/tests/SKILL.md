---
name: tests
description: Conventions for writing unit tests (Swift Testing) and UI tests (XCUITest) in this iOS app. Use when the user wants to create or modify tests, including test structure, naming conventions, fakes, concurrency and UI tests.
---

# Tests

- You MUST read and follow `docs/testing.md` and principles III and IV of
  `.specify/memory/constitution.md`.
- Unit tests live in `MonicaTests`, UI tests in `MonicaUITests`, in the same folder structure as
  `Monica/`. A suite is named after the type or screen it tests: `ContactsViewModelTests`,
  `ContactsScreenUITests`.
- Unit tests use Swift Testing. Test names describe the behaviour as a raw identifier:
  ``@Test func `shows an error when the repository fails`() async``. UI tests use XCTest, where
  names must start with `test` in camelCase: `testShowsErrorMessageWhenLoadingFails`.
- One behaviour per test, structured as arrange / act / assert, separated by a blank line.
- You MUST use fakes (hand-written in-memory implementations of the repository or data source
  protocol) instead of mocking frameworks. Fakes live in the test target, next to the tests.
- Concurrency: write `async` tests and `await` the view model's methods. Mark suites that test
  `@MainActor` types with `@MainActor`. Inject clocks; never use `sleep` or real delays.
- A view model test covers every `UiState` it can produce and every event it handles.
- UI tests launch the app with `XCUIApplication`, configured through `launchArguments` (language,
  text size) when a test needs it. Find elements by label and role (`app.buttons["Log in"]`);
  `accessibilityIdentifier` only as a last resort. Assert what a person sees and what happens
  after a tap, never colours, sizes, padding or other styling.
- Read strings in tests from the String Catalog rather than duplicating text only when the test
  can reach it; otherwise assert the English text, which is the source language.
- You MUST NOT test generated code, SwiftUI or UIKit behaviour, or trivial value types with no
  logic of their own.
- A bug fix starts with a test that fails without the fix.
