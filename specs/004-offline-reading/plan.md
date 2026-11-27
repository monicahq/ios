# Implementation Plan: Offline Reading

**Branch**: `2026-11-27-offline-reading` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-offline-reading/spec.md`

## Summary

Keep what the instance answers in a SwiftData store on the phone, show it at once, and keep showing
it, marked "not up to date", when the instance cannot be reached. The store is protected by Data
Protection and excluded from backups. `SessionManager`, which every session end already goes
through (`endLocally`), erases the whole store before publishing `.signedOut`, and sweeps it at start
(signed out, other owner, unreadable, 30 days without contact, clock moved back). Every record
carries five sync fields from version 1 and refreshes never touch a record with a change waiting, so
offline adding and editing can come later without changing any record's identity. Vaults (the list
and one vault) are the first resource; [contracts/offline-copy.md](contracts/offline-copy.md) is how
every later one joins. Same feature as monicahq/android#8.

## Technical Context

**Language/Version**: Swift 6 language mode, Xcode (latest stable), iOS 18 minimum

**Primary Dependencies**: SwiftUI, Observation, Foundation; **new**: SwiftData (system framework,
no package)

**Storage**: SwiftData store `Application Support/OfflineCopy/OfflineCopy.store`
(Data Protection `completeUntilFirstUserAuthentication`, folder `isExcludedFromBackup`); the session
stays in the Keychain and gains `copyOwner: UUID`

**Testing**: Swift Testing in `MonicaTests`, `FakeMonica`, `FakeClock`, `Harness`; a real
`OfflineCopy` on a temporary folder (no fake); coverage gate 80%

**Target Platform**: iPhone, iOS 18+

**Project Type**: mobile-app (single `Monica` target, XcodeGen)

**Performance Goals**: list visible from the copy within 1 s of opening (SC-001); store opened and
read on the main actor in a few milliseconds for 100 vaults

**Constraints**: constitution VIII (protection at rest, isolation, erasure before `.signedOut`, no
backup, 30 days); nothing written that the instance did not answer; no copy content in logs

**Scale/Scope**: 3 models, 1 resource (vaults), 2 view models and 2 screens changed, 1 shared view,
1 string; mechanism reused by every later resource

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| Product context: API only, server is the truth | The copy only holds API answers; no endpoint added; writes stay online. Offline writing's API needs are recorded for the Monica repository first. | ✅ |
| I. Simplicity | No package, no protocol: `OfflineCopy` is one concrete class, tested on a temporary folder. Five sync fields and one pure rule exist ahead of use, asked by the person (spec FR-018–FR-020); the queue is described, not built. | ✅ |
| II. Apple practices | SwiftData (preferred storage), `mainContext` from `@MainActor` repositories, dependencies through initializers, view models keep one `state`, no `!`. | ✅ |
| III. Unit tested | `OfflineCopy`, `reconcile`, `staleNoticeText`, `SessionManager` erasure and sweep, repository and view model copy cases. | ✅ |
| IV. Thin UI, no UI tests | `StaleNoticeView` is drawing only; its text and every state are decided in tested code; previews in light and dark. | ✅ |
| V. Native only | SwiftData, Data Protection. | ✅ |
| VI. Multilingual | One string, EN + FR, relative time by `RelativeDateTimeFormatter`. | ✅ |
| VII. Accessible | Words plus a hidden icon, secondary colour, wraps, announced on change; reviewer agent, Inspector audit, VoiceOver by hand. | ✅ |
| VIII. Readable offline | This feature implements it: [contracts/offline-copy.md](contracts/offline-copy.md) maps every rule. | ✅ |
| Tech standards | No `project.yml` change needed (system framework); SwiftFormat, SwiftLint strict. | ✅ |

**Post-design re-check**: same result. The design adds one data folder (`Data/Offline/`) and one UI
folder (`Offline/`), changes `SessionManager` in four places (`init`, `complete`, `authorized`,
`endLocally`) and the vault repository and view models without changing their screens' structure.

## Project Structure

### Documentation (this feature)

```text
specs/004-offline-reading/
├── spec.md
├── plan.md                  # this file
├── research.md              # R1–R11
├── data-model.md            # models, sync fields, refresh rule, reserved queue, lifetime
├── quickstart.md            # automated, by hand, on a device
├── contracts/
│   └── offline-copy.md      # guarantees and the recipe for every later resource
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
Monica/
├── MonicaApp.swift                    # builds OfflineCopy, gives it to SessionManager and VaultRepository
├── Auth/
│   ├── Session.swift                  # + copyOwner: UUID
│   └── SessionManager.swift           # sweep in init; open in complete; erase in endLocally; contact in authorized
├── Data/
│   ├── Offline/                       # NEW
│   │   ├── OfflineCopy.swift          # folder, protection, backup flag, open / erase / sweep / contact
│   │   ├── OfflineSchema.swift        # OfflineSchemaV1 (CopyInfo, Freshness, CachedVault), migration plan
│   │   ├── SyncState.swift
│   │   ├── Reconcile.swift            # the refresh rule (pure)
│   │   └── Cached.swift               # Cached<Value>: value + updatedAt
│   └── Vaults/
│       ├── Vault.swift                # + updatedAt, decoded from updated_at
│       └── VaultRepository.swift      # cachedVaults(), cachedVault(id:); writes after success; 404 deletes
├── Offline/                           # NEW
│   ├── StaleNotice.swift              # staleNoticeText(since:now:locale:) (pure)
│   └── StaleNoticeView.swift          # the shared line
├── Vaults/
│   ├── VaultsUiState.swift            # + staleSince: Date?
│   ├── VaultsViewModel.swift          # copy at once; staleSince on failure
│   ├── VaultsScreen.swift             # StaleNoticeView under the title
│   ├── VaultUiState.swift             # loaded(Vault, staleSince: Date?)
│   ├── VaultViewModel.swift           # copy at once; staleSince; 404 as today
│   └── VaultScreen.swift              # StaleNoticeView
└── Resources/Localizable.xcstrings    # + "Not up to date. Last updated %@." (EN, FR)

MonicaTests/
├── Support/Fakes.swift                # Harness builds OfflineCopy in a temporary folder; relaunched() reuses it
├── Data/Offline/OfflineCopyTests.swift, ReconcileTests.swift
├── Auth/SessionManagerOfflineTests.swift
├── Data/Vaults/VaultRepositoryTests.swift      # + copy cases
├── Vaults/VaultsViewModelTests.swift, VaultViewModelTests.swift   # + copy cases
└── Offline/StaleNoticeTests.swift
```

**Structure Decision**: the copy belongs to the session, not to vaults, so its code lives in a
feature-neutral `Data/Offline/` folder that every later repository uses, and the shared line in
`Offline/`. `Auth/` depends on `Data/Offline/` (the session opens and erases the copy);
`Data/Offline/` depends on nothing of `Auth/`. `StaleNoticeView.swift` is excluded from coverage by
its name; its logic is in `StaleNotice.swift`.

## Implementation notes

- **Order in `endLocally(_:)`**: bump `generation`, cancel renewal, invalidate the client, delete the
  Keychain session, `offlineCopy.erase()`, then `state = .signedOut(reason)`.
- **`init`**: compute `state` from the Keychain as today, then `erase()` if signed out, or
  `open(owner: session.copyOwner, now: now())` if signed in, before the first screen reads anything.
- **`complete`**: `open(owner: session.copyOwner, now: now())` just before `state = .signedIn`.
- **`erase()`**: set the container to nil first (SwiftData must not hold the files), then
  `FileManager.removeItem` on the folder; ignore "no such file".
- **Folder creation**: `createDirectory` with `[.protectionKey: .completeUntilFirstUserAuthentication]`,
  then `isExcludedFromBackup = true` through `URLResourceValues`, every time the store is (re)created.
- **Unreadable store**: `ModelContainer(for:migrationPlan:configurations:)` throwing → erase and create
  again once; a second failure leaves `context` nil (online only, nothing shown as broken).
- **Decoding `updated_at`**: Unix seconds, optional; `Date(timeIntervalSince1970:)`.
- **`VaultsViewModel.load()`**: if no content yet and a copy exists → `.loaded(copy.value)` with no
  spinner, remember its date; on failure with content → `staleSince = copy date` (first load) or
  `refreshFailed = true` and `staleSince` (later reloads); on success → `staleSince = nil`.
- **Docs**: `docs/architecture.md` gets an "Offline copy" section (the contract in short, folder
  tree); `docs/testing.md` explains the temporary-folder `OfflineCopy`; `docs/FEATURES.md` entry;
  `CLAUDE.md` summary gets principle 8 (constitution 2.1.0).

## Complexity Tracking

No violation to justify.
