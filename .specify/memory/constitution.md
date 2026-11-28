# Monica iOS Constitution

## Product Context

- This app is the **iOS version of the Monica web application**
  ([monicahq/monica](https://github.com/monicahq/monica)). The goal is to offer, over time, every
  feature of the web app, plus what only makes sense on a phone (notifications, sharing, the
  device's contacts, widgets, offline reading, camera).
- The Monica server is the source of truth for data and business rules. The app talks to it
  **only through its public JSON API** (`/api/v1`, signed in with the OAuth access tokens Monica
  issues to its mobile apps, OpenAPI document at
  `/docs/api/v1/openapi`). It MUST NOT re-implement rules the server already enforces.
- The app uses the **same concepts and the same words** as the web app (account, vault, contact,
  reminder, template, ...). A screen that exists on the web behaves the same way on iOS unless
  the spec states a mobile-specific reason to differ.
- When a feature needs data or an action the API does not expose yet, the API is extended in the
  Monica repository first. The app MUST NOT work around a missing endpoint (scraping, private
  routes, duplicated logic).
- Every spec starts by reading how the web app does it: its screens, its API endpoints
  (`routes/api.php`, `resources/docs/api` in the Monica repository) and its wording.
- The Android app ([monicahq/android](https://github.com/monicahq/android)) is a separate project
  with the same goals. When it already ships a feature, its spec is a useful starting point, but
  each app follows its own platform's conventions.

## Core Principles

### I. Simplicity First

- Code MUST be the simplest thing that correctly solves today's requirement (KISS, YAGNI).
- An abstraction (protocol, base class, generic helper, module, use case) MUST NOT be introduced
  until it has at least two real consumers or is required to make code testable.
- A new Swift package, framework or target MUST be justified in the feature's `plan.md`
  (Complexity Tracking) by naming the concrete problem it solves and the simpler alternative that
  was rejected.
- Prefer deleting code over adding configuration. Readable code beats clever code.

Rationale: a small, obvious codebase is cheaper to test, review, and hand over to contributors.

### II. Official Apple Best Practices

Apple's documentation for SwiftUI, Observation and Swift concurrency, and the
[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines), are
the reference. When in doubt, do what they recommend.

- **UI layer**: SwiftUI. Screens follow Unidirectional Data Flow: an `@Observable`, `@MainActor`
  view model exposes a single immutable `state` value (the screen's `UiState`) and receives events
  through plain methods.
- Each screen is split into a stateful entry view (owns the view model) and a **stateless**
  screen view that takes the state plus closures. State is hoisted; views hold no business logic.
- **Data layer**: repositories are the single source of truth for each data type and expose
  `async` functions or `AsyncSequence`s. A domain layer (use cases) is added only when logic is
  shared by several view models (see Principle I).
- **Concurrency**: Swift concurrency only (`async`/`await`, tasks, actors), with Swift 6 complete
  concurrency checking. Dependencies (clients, clocks, repositories) are passed through
  initializers, never reached through singletons, so tests can replace them. No blocking work on
  the main actor.
- **Swift**: idiomatic Swift (value types, enums with associated values, optionals). Force
  unwrapping (`!`), `try!` and implicitly unwrapped optionals MUST NOT be used in production code.
- **Resources**: all user-facing text lives in the String Catalog (see Principle VI).
  Accessibility rules are in Principle VII.

Rationale: following the platform's documented patterns makes the code predictable for any
iOS developer and keeps it compatible with Xcode tooling.

### III. Unit Tested by Default (NON-NEGOTIABLE)

- Every view model, repository, mapper, and piece of non-UI logic MUST have unit tests in
  `MonicaTests`, written in the same change as the code they cover.
- View model tests MUST cover every `UiState` the view model can produce (loading, success, empty,
  error) and every event it handles.
- Tests use Swift Testing (`@Test`, `#expect`) and fakes (hand-written in-memory implementations)
  over mocking frameworks. Asynchronous code is tested with `async` tests, never real delays.
- A bug fix MUST start with a failing test that reproduces the bug.
- Non-UI code MUST keep at least 80% line coverage.

Rationale: unit tests are fast and cheap; they are what lets us change code with confidence.

### IV. Thin, Stateless UI (No UI Tests)

- The project has **no UI test target**: XCUITest suites are too slow for the value they bring.
  Confidence in a screen comes from unit tests of what drives it.
- So screens MUST stay thin: a stateless screen view draws its `UiState` and forwards events. Every
  decision (what to show, when, which message, what a tap does) lives in the view model or in a
  pure function of its own file, and is unit tested there.
- Every screen state a spec defines MUST be reachable from a view model test that asserts the
  `UiState` producing it, and every user journey MUST be covered by view model and repository tests
  chaining its steps against the fake instance.
- Every screen MUST have SwiftUI previews of its states (light and dark), and is checked by hand on
  a simulator before a pull request (see Principle VII).

Rationale: unit tests run in seconds and test the logic people depend on; slow, flaky UI
automation was costing more than it caught.

### V. Native iOS Only

- The app is 100% native: Swift, SwiftUI, Apple frameworks and iOS SDK APIs.
- Kotlin Multiplatform, Compose Multiplatform, Flutter, React Native, and WebView-based UIs MUST
  NOT be used. The Android app is a separate, independent project.
- Platform features (notifications, sharing, contacts, widgets, Shortcuts) SHOULD use the native
  Apple APIs directly.

Rationale: a native app gives the best user experience and lets us adopt new iOS features the day
they ship.

### VI. Multilingual From the Start

- Every user-facing text, including accessibility labels and hints, lives in the String Catalog
  (`Monica/Resources/Localizable.xcstrings`), with an entry for every supported language. No text
  is written directly in code.
- English is the source language and the fallback for every unsupported language. French is
  provided from the first screen. The long-term goal is parity with the languages of the web app.
- A change that adds or modifies a string MUST update every supported language in the same pull
  request. iOS does not fall back to English for a key missing in one language, so every key is
  present in every language, even a text that is the same everywhere.
- Wording reuses the web app's English text and its existing translations (`lang/*.json` in the
  Monica repository) whenever the same text exists there.
- The app declares its languages to iOS, so the per-app language setting offers them. Plurals use
  the String Catalog's plural variations, and dates and numbers are formatted for the person's
  locale with Foundation's formatters, never by hand.

Rationale: retrofitting translations is far more expensive than starting with them, and Monica's
users already read the web app in their own language.

### VII. Accessible to Everybody (NON-NEGOTIABLE)

WCAG 2.2 AA, applied to mobile, is a delivery condition for every screen, not a pass at the end of a
project. Every screen a change touches MUST:

- be fully usable with VoiceOver: every control has a label, a role (trait) and a value or state,
  headings carry the header trait, decorative images are hidden and meaningful ones described, and
  the reading order follows the visual order;
- be usable with Switch Control, Voice Control and Full Keyboard Access: every action is reachable
  and the focus is always visible;
- never carry information by colour alone;
- meet contrast of 4.5:1 for text and 3:1 for controls and focus indicators, in light and dark;
- stay readable at the largest Dynamic Type size, including the accessibility sizes: text wraps,
  nothing is cut or overlapping, content scrolls instead of shrinking;
- give every tappable element a target of at least 44 by 44 pt;
- respect Reduce Motion;
- offer an alternative to any gesture-only action (swipe, long press, drag).

A change to a screen MUST be reviewed by the `accessibility-reviewer` agent, checked with the
Accessibility Inspector's audit on a simulator, and the pull request MUST state how it was checked
with VoiceOver. See `docs/accessibility.md`.

Rationale: Monica holds what people know about the people they love. Nobody should be locked out
of their own memories because of how they use their phone.

### VIII. Readable Offline

Applies to every feature specified after `specs/004-offline-reading`, which builds the mechanism
and brings the vault screens in line. Same rules as the Android app's Principle VIII.

- Every screen that shows data read from the instance MUST stay readable without a connection: it
  shows the last copy the instance answered and says, in words, that it is not up to date and since
  when. With no copy yet, it shows the connection error as before.
- Online, a screen MUST show its copy at once, then replace it with the instance's answer. The
  server stays the source of truth; the copy only holds what the instance already answered.
- The copy is read only. Every action that changes data MUST reach the instance first; offline, it
  keeps what the person typed and says the instance cannot be reached. Writing offline and sending
  later is out of scope until the constitution says otherwise, but the copy MUST be built so that
  it can be added without redoing it: every record has an identity of its own on the phone, a sync
  state (matches the instance, or a change waiting) and the instance's last modification time, and
  an update from the instance never overwrites or removes a record with a change waiting.
- The copy MUST be encrypted with a key that never leaves the iPhone and is never synced or
  backed up, isolated per instance and account, excluded from iCloud and computer backups and
  from transfers to a new iPhone, and kept out of logs and crash reports.
- The copy MUST be erased whenever a session ends (log-out, instance switch, session ended by the
  instance, renewal refused, session expired) before the welcome screen shows, and after 30 days
  without a successful contact with the instance (or when the phone's clock is earlier than that
  contact). Erasure is done in one place and covers every kind of data kept: no feature erases its
  own copy.
- Exceptions, which a spec MUST name explicitly when it uses them: searches answered by the server,
  billing, instance administration, and any action that writes.
- Unit tests cover, for each such screen, the copy shown offline, the "not up to date" state, the
  update when the instance answers, and the erasure of its data when the session ends.

Rationale: a phone is often without a network, and Monica is where people look up what they know
about someone right before they see them. Keeping that data on the phone is acceptable only if it
never outlives the session that loaded it.

## Technology Standards

- **Language & build**: Swift 6 language mode, Xcode. The Xcode project is generated by XcodeGen
  from `project.yml` and never committed; `project.yml` is the only place targets, settings and
  package versions are declared. Command-line tools are pinned in `mise.toml`.
- **Platform**: iOS 18 minimum, iPhone, built with the latest stable Xcode.
- **Preferred Apple frameworks** (used only when a feature needs them): `NavigationStack` with
  typed destinations, `URLSession` for the network, SwiftData for local storage, `UserDefaults`
  for preferences, Keychain for secrets, BackgroundTasks for background work. Third-party Swift
  packages come through Swift Package Manager only.
- **Formatting**: SwiftFormat (`swiftformat .`). SwiftLint (`swiftlint --strict`) MUST pass with
  no warning. The compiler treats warnings as errors.
- **Security**: no secrets, API tokens, certificates or provisioning profiles in the repository.
  User credentials are stored only in the Keychain.

## Development Workflow & Quality Gates

- Every feature follows Spec Kit: `/speckit-specify` → (`/speckit-clarify`) → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`. Specs live in `specs/`.
- `tasks.md` MUST list unit test tasks for every user story; a story is not done until its tests
  pass.
- Work happens on branches and lands on `main` only through pull requests. Nothing is ever
  committed or pushed directly to `main`, without exception.
- CI (`.github/workflows/ci.yml`) MUST be green before merging: SwiftFormat check, SwiftLint,
  unit tests with the coverage gate, and debug and release builds.
- Coverage gate: `scripts/check-coverage.sh`, run by the CI "Unit tests" job on the unit tests'
  result bundle, fails the build when non-UI line coverage drops below 80%. `MonicaApp.swift`,
  `*Screen.swift` and `*View.swift` files and `Theme/` are excluded: they hold no logic (see
  Principle IV) and are checked through previews and by hand.
- Documentation is part of done: public types and non-obvious functions have documentation
  comments (`///`) explaining *why*, and `README.md` / `docs/` are updated when a feature changes
  how the app is built, configured, or used.

## Governance

- This constitution overrides any other convention in the repository. `CLAUDE.md` holds day-to-day
  runtime guidance for agents and MUST stay consistent with it.
- Every pull request review checks compliance with the Core Principles. Any deviation MUST be
  recorded and justified in the feature's `plan.md` Complexity Tracking table.
- Amendments are made through a pull request that updates this file with `/speckit-constitution`,
  states the reason, and lists any code that must migrate.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle, MINOR for
  adding a principle or materially expanding guidance, PATCH for wording and clarifications.

**Version**: 2.1.0 | **Ratified**: 2026-11-25 | **Last Amended**: 2026-11-27
