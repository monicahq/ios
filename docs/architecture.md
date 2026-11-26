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
- Use an Apple framework (SwiftData, BackgroundTasks, ...) or a Swift package only when a feature
  needs it, and justify a package in the feature's `plan.md`.
