# Architecture

We follow Apple's documented patterns for SwiftUI, Observation and Swift concurrency, and keep them
as simple as possible. This page shows what that means concretely in this repo.

## Layers

```
UI layer        SwiftUI screen views  ←  view model (@Observable, one `state`)
                         │ events            ▲ state
                         ▼                   │
Data layer                   Repository  →  data sources (URLSession, SwiftData, Keychain)
```

- Data flows **down** as state, events flow **up** as method calls (Unidirectional Data Flow).
- A **domain layer** (use cases) is only added when the same logic is needed by several view models.

## Folder layout

Organise by feature, not by technical type. XcodeGen picks up every file under `Monica/`:

```
Monica/
├── MonicaApp.swift           # @main entry point
├── Theme/                    # colours, fonts, button styles
├── Contacts/                 # one folder per feature
│   ├── ContactsScreen.swift  # stateful entry + stateless screen
│   ├── ContactsViewModel.swift
│   └── ContactsUiState.swift
├── Data/
│   └── Contacts/
│       ├── ContactsRepository.swift
│       └── ...data sources
└── Resources/                # Assets.xcassets, Localizable.xcstrings
```

## A screen, the reference way

```swift
// UI state: one immutable type describing everything the screen shows.
enum ContactsUiState: Equatable {
    case loading
    case success([Contact])
    case error
}

@MainActor @Observable
final class ContactsViewModel {
    private(set) var state: ContactsUiState = .loading
    private let repository: ContactsRepository

    init(repository: ContactsRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            state = .success(try await repository.contacts())
        } catch {
            state = .error
        }
    }
}

// Stateful entry point: owns the view model. Covered by the end-to-end UI tests.
struct ContactsRoute: View {
    @State var viewModel: ContactsViewModel
    let onContactTap: (Contact.ID) -> Void

    var body: some View {
        ContactsScreen(state: viewModel.state, onContactTap: onContactTap)
            .task { await viewModel.load() }
    }
}

// Stateless screen: pure function of its inputs. This is what UI tests and previews target.
struct ContactsScreen: View {
    let state: ContactsUiState
    let onContactTap: (Contact.ID) -> Void

    var body: some View { /* ... */ }
}
```

## Rules of thumb

- No business logic in views; no UIKit or SwiftUI types in view models.
- Repositories expose `async` functions for one-shot actions and `AsyncSequence` for observable data.
- Pass dependencies through initializers; never reach for a singleton (`URLSession.shared`, a
  global store) inside a type.
- All user-visible text in `Resources/Localizable.xcstrings`; give meaningful elements
  accessibility labels.
- A screen with no state yet is only the stateless screen view, shown by `MonicaApp`; the `Route`
  and view model arrive with the first state to hold (as `WelcomeRoute` did with the instance
  sheet).
- Small preferences (the instance address) live in `UserDefaults`, injected into the repository
  that owns them (`InstanceRepository`), never read through `UserDefaults.standard` in a type.
- Use an Apple framework (SwiftData, BackgroundTasks, ...) or a Swift package only when a feature
  needs it, and justify a package in the feature's `plan.md`.

## Signing in and the session

People sign in on the instance's own web pages (OAuth 2.0 with PKCE), never in the app: see
`specs/002-login-registration`.

- `Auth/SessionManager` (`@MainActor @Observable`) is the only owner of the session. It starts and
  completes sign-in, renews access (one renewal at a time, every caller awaits it), signs out, and
  exposes `state` (signed in or out, and why). No other type reads a token; screens call
  `authorizedGet` or a method of the session manager.
- `Auth/MonicaClient` talks to one instance. It is where tokens are kept at home: a bearer token
  goes only to the instance's own origin, redirects are never followed, the session has no
  cookies or cache. A client stops working once its session ends.
- `Instance/InstanceChecker` reads the instance's status and OAuth metadata before an address is
  saved and before each sign-in: every sign-in address comes from the instance.
- Secrets (the session, a sign-in in progress, a logout to tell) live in the Keychain through
  `Auth/SecretStore`, readable on this device only. A fresh install wipes what an earlier install
  left there.
- `RootView` shows the welcome screen or the home from the session state, and receives the
  return address (`com.monicahq.ios:/oauth/callback`, declared in `Config/Info.plist`) when iOS
  opens the app with it.
- Release builds talk to instances over HTTPS only; Debug builds also accept `http` (see
  `Config/Info-Debug.plist`) for a Monica on the developer's machine.

## Languages

- Every text lives in `Monica/Resources/Localizable.xcstrings`, under a key shared with the
  Android app when the text exists there (`welcome_title`), with a value for English (source and
  fallback) and every translation. French is provided.
- iOS lists the languages of the catalog in the app's page of the Settings app, so people can
  choose the app's language without changing the device's.
- A text that includes a value uses one format string (`Instance: %@`), never concatenation, so
  each language can place the value where its grammar wants it.

## Theme

`Theme/` and the colour sets of `Assets.xcassets/Colors` hold the Monica design system
(shadcn-like greys, no accent colour, system font), in light and dark. Xcode generates a symbol for
each colour: use `Color.page`, `Color.ink`, `Color.muted`... and the `PrimaryButtonStyle` and
`OutlinedButtonStyle` in screens, never raw colours. Text uses the system text styles so it follows
Dynamic Type.
