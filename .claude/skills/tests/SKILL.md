---
name: tests
description: Conventions for writing unit tests (Swift Testing) in this iOS app, which has no UI tests. Use when the user wants to create or modify tests, including test structure, naming conventions, fakes and concurrency.
---

# Tests

- You MUST read and follow `docs/testing.md` and principles III and IV of
  `.specify/memory/constitution.md`.
- Tests live in `MonicaTests`, in the same folder structure as `Monica/`. A suite is named after
  the type it tests: `ContactsViewModelTests`.
- You MUST NOT add XCUITest UI tests or a UI test target: they were removed because they are too
  slow. Cover a screen through its view model: every state it draws is a `UiState` a test asserts,
  and every journey is a test chaining the view models and repositories of its steps.
- Unit tests use Swift Testing. Test names describe the behaviour as a raw identifier:
  ``@Test func `shows an error when the repository fails`() async``.
- One behaviour per test, structured as arrange / act / assert, separated by a blank line.
- You MUST use fakes (hand-written in-memory implementations of the repository or data source
  protocol) instead of mocking frameworks. Fakes live in the test target, next to the tests.
- Concurrency: write `async` tests and `await` the view model's methods. Mark suites that test
  `@MainActor` types with `@MainActor`. Inject clocks; never use `sleep` or real delays.
- A view model test covers every `UiState` it can produce and every event it handles.
- Read strings in tests from the String Catalog rather than duplicating text only when the test
  can reach it; otherwise assert the English text, which is the source language.
- You MUST NOT test generated code, SwiftUI or UIKit behaviour, or trivial value types with no
  logic of their own.
- A bug fix starts with a test that fails without the fix.
