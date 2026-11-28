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

// Stateful entry point: owns the view model. No logic: the view model's tests cover it.
struct ContactsRoute: View {
    @State var viewModel: ContactsViewModel
    let onContactTap: (Contact.ID) -> Void

    var body: some View {
        ContactsScreen(state: viewModel.state, onContactTap: onContactTap)
            .task { await viewModel.load() }
    }
}

// Stateless screen: pure function of its inputs. This is what previews target.
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
- Instance data kept on the phone goes in the offline copy's SwiftData store, never in
  `UserDefaults`, files or the Keychain.
- Use an Apple framework (SwiftData, BackgroundTasks, ...) or a Swift package only when a feature
  needs it, and justify a package in the feature's `plan.md`.

## Signing in and the session

People sign in on the instance's own web pages (OAuth 2.0 with PKCE), never in the app: see
`specs/002-login-registration`.

- `Auth/SessionManager` (`@MainActor @Observable`) is the only owner of the session. It starts and
  completes sign-in, renews access (one renewal at a time, every caller awaits it), signs out, and
  exposes `state` (signed in or out, and why). No other type reads a token: repositories call
  `authorized(method, path, json:)`, which renews and retries, and get the answer whatever its
  status (`authorizedGet` is the shortcut for callers that only expect success).
- `Auth/MonicaClient` talks to one instance. It is where tokens are kept at home: a bearer token
  goes only to the instance's own origin, redirects are never followed, the session has no
  cookies or cache. A client stops working once its session ends.
- `Instance/InstanceChecker` reads the instance's status and OAuth metadata before an address is
  saved and before each sign-in: every sign-in address comes from the instance.
- Secrets (the session, a sign-in in progress, a logout to tell) live in the Keychain through
  `Auth/SecretStore`, readable on this device only. A fresh install wipes what an earlier install
  left there.
- `RootView` shows the welcome screen or the list of vaults from the session state, and receives the
  return address (`com.monicahq.ios:/oauth/callback`, declared in `Config/Info.plist`) when iOS
  opens the app with it.
- Release builds talk to instances over HTTPS only; Debug builds also accept `http` (see
  `Config/Info-Debug.plist`) for a Monica on the developer's machine.

## Calling the API

Each kind of data has one repository, its single source of truth (`Data/Vaults/VaultRepository`):
it builds the requests, decodes the answers, and turns statuses into `Data/ApiError`
(`failed(AuthError)`, `notFound` for a 404, `invalid(Refusal)` for a 422 with the instance's own
words). View models call only repositories. What the API answers is kept in the offline copy
(below), and nowhere else on the phone. Repositories have no protocol: tests run them against the
fake Monica (see `docs/testing.md`).

## Offline copy

Every screen showing instance data stays readable offline (constitution, principle VIII). The full
rules are in `specs/004-offline-reading/contracts/offline-copy.md`; in short:

- `Data/Offline/OfflineCopy` is one SwiftData store (`Application Support/OfflineCopy/`), protected
  by Data Protection until the first unlock after a restart and excluded from backups. Its models
  are all in `Data/Offline/OfflineSchema.swift` (`OfflineSchemaV1`), so erasing the folder erases
  every kind of data at once.
- `SessionManager` owns its life: it opens the copy for the session (`Session.copyOwner`), erases
  it in `endLocally` before publishing `.signedOut` (every way a session ends goes through there),
  and sweeps it at launch (signed out, another owner, unreadable, 30 days without contact, clock
  moved back; never before the first unlock, when the Keychain cannot be read either). Repositories
  never open nor erase it.
- Repositories write only what the instance answered, right after a successful answer, and offer a
  `cachedX()` read returning `Cached<Value>` (the value and when it was answered).
- Every record carries five sync fields (`localID`, `serverID`, `syncState`, `serverUpdatedAt`,
  `syncedAt`) and every refresh goes through `reconcile`, which never touches a record with a
  change waiting: offline writing can come later without changing a record's identity.
- View models show the copy at once, then the instance's answer; when the instance cannot answer,
  they keep the copy and set `staleSince`, which screens show with `Offline/StaleNoticeView`.

```
Monica/Data/Offline/   OfflineCopy, OfflineSchema, SyncState, Reconcile, Cached
Monica/Offline/        StaleNotice (text), StaleNoticeView (the shared line)
```

## The signed-in app

`Vaults/VaultsRoute` is the signed-in home. It owns the `NavigationStack` (typed destinations such
as `VaultDestination`), the account sheet (`Account/AccountSheetView`, which opens the instance
sheet over it) and the new vault sheet. The list hides the system navigation bar and draws its own
top bar, as the design does; pushed screens use the system bar and its Back button.

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

- Screens of the signed-in app sit on the grouped grey (`Color.groupedPage`) with cards in
  `Color.groupedCard`, and secondary text in `Color.groupedMuted`, which keeps 4.5:1 on that grey
  (`Color.muted` does not).
- A vault's colour is one of eight pairs (initial and tint, `Colors/Vault`), measured at 4.5:1 in
  light and dark; `Theme/VaultColours.swift` maps `VaultColour` to them and to a spoken name.
- Controls floating over content use `Theme/FloatingStyles.swift`: Liquid Glass from iOS 26, the
  standard material or a solid fill before, and solid with Reduce Transparency.
