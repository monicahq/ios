---
description: "Tasks for Offline Reading"
---

# Tasks: Offline Reading

**Input**: Design documents from `specs/004-offline-reading/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/offline-copy.md](contracts/offline-copy.md),
[quickstart.md](quickstart.md)

**Tests**: required by the constitution (Principles III, IV and VIII). Every phase writes its tests
first, sees them fail, then implements. Unit tests only (Swift Testing, `MonicaTests`), against
`FakeMonica` and a real `OfflineCopy` in a temporary folder (research R10).

**Organization**: by user story. User Story 3 (erasure and isolation) comes right after the
foundation, before any screen shows the copy, so that no build of this branch ever shows a copy that
could outlive its session.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md the task belongs to

---

## Phase 1: Setup

**Purpose**: folders and the one new string

- [X] T001 Create the folders `Monica/Data/Offline/`, `Monica/Offline/`, `MonicaTests/Data/Offline/`, `MonicaTests/Offline/` and run `xcodegen generate` (no `project.yml` change: SwiftData is a system framework, plan.md Technical Context)
- [X] T002 [P] Add the key `stale_notice` to `Monica/Resources/Localizable.xcstrings` with English "Not up to date. Last updated %@." and French "Pas à jour. Mis à jour %@.", and a translator comment saying `%@` is a relative time already in the person's language (contracts/offline-copy.md, Strings)

---

## Phase 2: Foundational (the copy and its rule)

**Purpose**: the store, its models and the refresh rule, which every story uses

**⚠️ CRITICAL**: no user story work starts before this phase is done

### Tests first

- [X] T003 [P] Write `MonicaTests/Data/Offline/ReconcileTests.swift`: synced rows present in the answer are updated, new ids inserted, synced rows absent deleted, rows in `.pendingCreate` / `.pendingUpdate` / `.pendingDelete` never updated nor deleted whatever the answer, a pending create (`serverID` nil) is kept, empty answer deletes only synced rows (data-model.md, The refresh rule; spec FR-020)
- [X] T004 [P] Write `MonicaTests/Data/Offline/OfflineCopyTests.swift` on a temporary folder: `open` creates the folder with `isExcludedFromBackup` set and a `CopyInfo` row with the owner and `lastContactAt = now`; `open` again with the same owner keeps the rows; `open` with another owner erases them; a garbage file in place of the store is erased and a fresh store opened; `erase()` removes the folder and leaves `context` nil; `erase()` with no folder does nothing; with `isProtectedDataAvailable` false, `open` neither reads nor erases and `context` is nil (research R2, R4, R5)
- [X] T005 [P] Add a case to `MonicaTests/Auth/AuthBasicsTests.swift`: a `Session` round-trips through `JSONEncoder`/`JSONDecoder` with its `copyOwner`, and its `description` still shows no token (data-model.md, `Session.copyOwner`)

### Implementation

- [X] T006 [P] Create `Monica/Data/Offline/SyncState.swift`: `enum SyncState: String, Codable, Sendable` with `synced`, `pendingCreate`, `pendingUpdate`, `pendingDelete`, documented with the transitions of data-model.md (Sync state)
- [X] T007 Create `Monica/Data/Offline/Reconcile.swift`: the pure `reconcile(existing:incoming:)` of data-model.md (The refresh rule), making T003 pass
- [X] T008 [P] Create `Monica/Data/Offline/Cached.swift`: `struct Cached<Value: Sendable>: Sendable, Equatable where Value: Equatable` with `value` and `updatedAt: Date` (research R8)
- [X] T009 Create `Monica/Data/Offline/OfflineSchema.swift`: `enum OfflineSchemaV1: VersionedSchema` (version 1.0.0) with the `@Model` classes `CopyInfo` (data-model.md `CopyInfo.owner`, `CopyInfo.lastContactAt`), `Freshness` (data-model.md `Freshness.kind` unique, `Freshness.updatedAt`) and `CachedVault` (data-model.md `CachedVault.localID` unique, `CachedVault.serverID` unique optional, `CachedVault.syncState`, `CachedVault.serverUpdatedAt`, `CachedVault.syncedAt`, `CachedVault.position`, `CachedVault.name`, `CachedVault.details`, `CachedVault.colour`, `CachedVault.isDefault`, `CachedVault.contactCount`), typealiases for the current models, and `enum OfflineMigrationPlan: SchemaMigrationPlan` with one schema and no stage
- [X] T010 Create `Monica/Data/Offline/OfflineCopy.swift` per contracts/offline-copy.md: `@MainActor final class`, `init(directory:isProtectedDataAvailable:)`, `open(owner:now:)` (folder created with `.completeUntilFirstUserAuthentication` and `isExcludedFromBackup`, container from `OfflineMigrationPlan`, unreadable → erase and retry once, other owner → erase and recreate), `erase()` (container to nil, then remove the folder), `context`, `save()` swallowing errors; no `print` or log of contents. Makes T004 pass (30-day and contact cases come in T018)
- [X] T011 Add `copyOwner: UUID` to `Monica/Auth/Session.swift`, set to `UUID()` where the session is built in `complete(callback:currentInstance:)` in `Monica/Auth/SessionManager.swift` (renewals copy the session, so they keep it); update every test that builds a `Session` by hand (research R6). Makes T005 pass
- [X] T012 Give `SessionManager.init` an `offlineCopy: OfflineCopy` parameter in `Monica/Auth/SessionManager.swift` (stored, not used yet), build it in `Monica/MonicaApp.swift` on `Application Support/OfflineCopy` with `{ UIApplication.shared.isProtectedDataAvailable }`, and in `MonicaTests/Support/Fakes.swift` make `Harness` create it on a fresh temporary folder (with a settable protected-data flag) and pass the same one to `relaunched()`

**Checkpoint**: the store opens, erases and reconciles in tests; nothing uses it yet

---

## Phase 3: User Story 3 - The copy never outlives the session, never leaves the phone (Priority: P1)

**Goal**: the copy is owned by one session, erased at every session end before the welcome screen,
swept at start, and expires after 30 days without contact

**Independent Test**: for each of the five session ends, the store folder is gone before `state`
becomes `.signedOut`; a relaunch signed out erases a leftover store; 31 days without contact erase
it; another session's store is never opened

### Tests first

- [X] T013 [P] [US3] Write `MonicaTests/Auth/SessionManagerOfflineTests.swift`: sign-in opens the store with the new session's owner and erases a store left by another owner; for `logOut()` (instance reachable and unreachable), `logOut(reason: .instanceChanged)`, a 401 after renewal (`.ended`), a refused renewal (`.ended`) and an expired one (`.expired`), the folder is gone and, checked from `withObservationTracking` on `state`, already gone when `.signedOut` is published (spec FR-009, FR-010)
- [X] T014 [P] [US3] In the same file: a relaunch (`Harness.relaunched()`) signed out erases a store found on disk; a relaunch signed in keeps a store of its own owner; a relaunch whose stored owner differs erases it; a relaunch more than 30 days after the last contact erases it; a relaunch with the clock earlier than the last contact erases it; a relaunch with protected data unavailable erases nothing (spec FR-008, FR-013; research R5)
- [X] T015 [P] [US3] In the same file: an authorized request answered 200, 404 or 500 records the contact, a 401 that ends the session does not, and a second contact within the hour does not write again (research R7)
- [X] T016 [P] [US3] Add to `MonicaTests/Data/Offline/OfflineCopyTests.swift`: `open` erases when `now` is more than 30 days after `CopyInfo.lastContactAt`, or earlier than it; `recordContact(at:)` saves when more than an hour passed since the saved value and skips otherwise (data-model.md `CopyInfo.lastContactAt`)

### Implementation

- [X] T017 [US3] In `Monica/Auth/SessionManager.swift`: at the end of `init`, `offlineCopy.erase()` when signed out, `offlineCopy.open(owner: session.copyOwner, now: now())` when signed in; in `complete(callback:currentInstance:)`, `open` with the new owner just before `state = .signedIn`; in `endLocally(_:)`, `offlineCopy.erase()` after `store.delete(.session)` and before `state = .signedOut(reason)` (plan.md Implementation notes). Makes T013, T014 pass
- [X] T018 [US3] In `Monica/Data/Offline/OfflineCopy.swift`: the 30-day and clock checks in `open(owner:now:)` and `recordContact(at:)` saved at most hourly; in `Monica/Auth/SessionManager.swift`, call `offlineCopy.recordContact(at: now())` in `authorized(_:_:json:)` for every answer that is not a 401. Makes T015, T016 pass

**Checkpoint**: the copy's whole life is safe and tested, while still holding no vault

---

## Phase 4: User Story 1 - See my vaults without a connection (Priority: P1) 🎯 MVP

**Goal**: offline, the vault list shows the copy with "Not up to date. Last updated …"; back online,
it refreshes and the line goes

**Independent Test**: load the list with the fake instance answering, make it unreachable, relaunch:
the same vaults show with `staleSince` set; make it answer again and reload: `staleSince` is nil

### Tests first

- [X] T019 [P] [US1] Add to `MonicaTests/Data/Vaults/VaultRepositoryTests.swift`: `cachedVaults()` is nil before any load; after `vaults()` it returns the same vaults in the same order with the load time; a second answer missing a vault removes it and keeps the order of the new answer; a pending `CachedVault` inserted by hand survives a refresh; `updated_at` is decoded and stored; a failed load leaves the copy unchanged; after a session end `cachedVaults()` is nil (spec FR-001, FR-020; data-model.md `CachedVault.position`, `CachedVault.serverUpdatedAt`)
- [X] T020 [P] [US1] Add to `MonicaTests/Offline/StaleNoticeTests.swift`: `staleNoticeText(since:now:locale:)` gives "Not up to date. Last updated 3 hours ago." in `en` and "Pas à jour. Mis à jour il y a 3 heures." in `fr`, and sensible text for one minute and two days (research R9)
- [X] T021 [P] [US1] Add to `MonicaTests/Vaults/VaultsViewModelTests.swift`: with a copy and the instance unreachable, `load()` ends with `.loaded(copy)` and `staleSince` equal to the copy's date, and no `.failed`; pulling down offline keeps the copy, sets `refreshFailed` and `staleSince`; a successful reload clears `staleSince`; with no copy, offline still gives `.failed` with "Try again" (spec Story 1 scenarios 1–5, FR-003, FR-004, FR-005)

### Implementation

- [X] T022 [P] [US1] In `Monica/Data/Vaults/Vault.swift`: `VaultAttributes.updatedAt: Date?` decoded from `updated_at` (Unix seconds, optional) and `Vault.updatedAt: Date?` (data-model.md `CachedVault.serverUpdatedAt`)
- [X] T023 [US1] In `Monica/Data/Vaults/VaultRepository.swift`: take `offlineCopy: OfflineCopy` in `init` (wire it in `Monica/MonicaApp.swift` and `Harness`); `cachedVaults() -> Cached<[Vault]>?` from `Freshness("vaults")` and `CachedVault` sorted by `position`; after a successful `vaults()`, apply `reconcile` (insert with a new `localID` and `.synced`, update fields, `position`, `syncedAt`), set `Freshness("vaults")`, `save()`; update the type's documentation ("Nothing is kept on the phone" is no longer true) (data-model.md `CachedVault`, `Freshness`). Makes T019 pass
- [X] T024 [P] [US1] Create `Monica/Offline/StaleNotice.swift`: `staleNoticeText(since:now:locale:)` with `RelativeDateTimeFormatter` (`.full`) and the String Catalog key of T002. Makes T020 pass
- [X] T025 [P] [US1] Create `Monica/Offline/StaleNoticeView.swift`: `StaleNoticeView(since: Date?)`, nothing when nil; `TimelineView(.everyMinute)`; `icloud.slash` hidden from VoiceOver plus the text in the secondary style, wrapping; posts an `AccessibilityNotification.Announcement` when `since` becomes non-nil or nil; previews light and dark, normal and largest accessibility size (research R9; spec FR-017)
- [X] T026 [US1] Add `staleSince: Date?` to `Monica/Vaults/VaultsUiState.swift` and update `Monica/Vaults/VaultsViewModel.swift` per plan.md Implementation notes (`load()`). Makes T021 pass
- [X] T027 [US1] Show `StaleNoticeView(since: state.staleSince)` under the title in `Monica/Vaults/VaultsScreen.swift`, outside the scrolling list; add a preview of the stale state

**Checkpoint**: MVP — the list is readable offline, and erased with the session (Phase 3)

---

## Phase 5: User Story 2 - Instant screens when online (Priority: P1)

**Goal**: with a copy, the list shows at once, then the instance's answer replaces it with no spinner

**Independent Test**: with a copy and a fake instance that answers later, the state is `.loaded(copy)`
with `isRefreshing` and never `.loading`, then `.loaded(answer)`

- [X] T028 [P] [US2] Add to `MonicaTests/Vaults/VaultsViewModelTests.swift`: with a copy and an answer that differs (renamed, recoloured, added, deleted vault), the first state published is `.loaded(copy)` without `.loading`, the last is exactly the answer in its order; with no copy, `.loading` then `.loaded` as before (spec Story 2 scenarios 1, 2, 4; SC-006)
- [X] T029 [US2] Adjust `Monica/Vaults/VaultsViewModel.swift` if T028 fails (copy shown before the request starts, `isRefreshing` while it runs); keep vault ids stable so `Monica/Vaults/VaultsScreen.swift` keeps scroll position and VoiceOver focus (spec Story 2 scenario 3; checked by hand, quickstart.md #5)

**Checkpoint**: online launches show the list instantly

---

## Phase 6: User Story 4 - Open a vault without a connection (Priority: P2)

**Goal**: offline, any vault of the copied list opens with its name, colour, description and the line

**Independent Test**: load the list, make the instance unreachable, open a vault never opened: its
state is `.loaded(vault, staleSince: date)`; a 404 online shows "This vault no longer exists." and
removes it from the copy

### Tests first

- [X] T030 [P] [US4] Add to `MonicaTests/Data/Vaults/VaultRepositoryTests.swift`: `cachedVault(id:)` returns a vault stored by the list with its `syncedAt`; a successful `vault(id:)` updates the row and keeps its `position`; a vault fetched alone that was not in the list is inserted with `position` `Int.max` but `cachedVaults()` stays based on the list; a 404 deletes the row (spec FR-007; data-model.md `CachedVault.position`, `CachedVault.syncedAt`)
- [X] T031 [P] [US4] Add to `MonicaTests/Vaults/VaultViewModelTests.swift`: offline with a copy → `.loaded(vault, staleSince: syncedAt)`; online → `.loaded(answer, staleSince: nil)` replacing the copy in place; 404 → `.notFound` and the vault is gone from `cachedVaults()`; no copy offline → `.failed` as before (spec Story 4 scenarios 1–3)

### Implementation

- [X] T032 [US4] In `Monica/Data/Vaults/VaultRepository.swift`: `cachedVault(id:) -> Cached<Vault>?`; after a successful `vault(id:)`, reconcile that one id and `save()`; on `.notFound`, delete the synced row and `save()`. Makes T030 pass
- [X] T033 [US4] Change `Monica/Vaults/VaultUiState.swift` to `loaded(Vault, staleSince: Date?)`, update `Monica/Vaults/VaultViewModel.swift` (copy at once, no spinner when a copy exists, `staleSince` on failure) and `Monica/Vaults/VaultScreen.swift` (`StaleNoticeView` under the title, previews of the stale state). Makes T031 pass

**Checkpoint**: list and vault are both readable offline

---

## Phase 7: User Story 5 - Every later resource reads offline the same way (Priority: P3)

**Goal**: the rules are written once, for every resource, and erasure needs nothing from a feature

**Independent Test**: review — the contract and docs say how a resource joins; one test proves
erasure covers every model of the schema

- [X] T034 [P] [US5] Add to `MonicaTests/Data/Offline/OfflineCopyTests.swift`: after inserting one row of every model in `OfflineSchemaV1.models` and calling `erase()`, a reopened store holds no row of any of them (spec FR-010, FR-015)
- [X] T035 [P] [US5] Add an "Offline copy" section to `docs/architecture.md` (the contract in short, the `Data/Offline/` and `Offline/` folders, the five sync fields and the refresh rule, the link to `specs/004-offline-reading/contracts/offline-copy.md`) and update its "Rules of thumb" line on SwiftData
- [X] T036 [P] [US5] Add to `docs/testing.md` how the offline copy is tested (a real `OfflineCopy` on a temporary folder from `Harness`, why no fake) and what each screen reading offline must test (constitution VIII)

---

## Phase 8: Polish & cross-cutting

- [X] T037 [P] Summarise principle 8 "Readable offline" in `CLAUDE.md` (constitution 2.1.0), and remove the Sync Impact Report comment at the top of `.specify/memory/constitution.md`
- [X] T038 [P] Add the feature to `docs/FEATURES.md` (feature-documentator skill)
- [X] T039 Run the `accessibility-reviewer` agent on the changed screens and views, and fix what it finds
- [X] T040 Run the definition of done: `xcodegen generate && swiftformat . && swiftlint --strict`, the unit tests with the result bundle, `scripts/check-coverage.sh` (80% or more)
- [ ] T041 Check by hand on the simulator scenarios 1–12 of `specs/004-offline-reading/quickstart.md` (VoiceOver, largest text size, dark, French, Accessibility Inspector audit), and list the device checks 13–15 as still to do in the pull request

---

## Dependencies & execution order

- **Setup (Phase 1)** → **Foundational (Phase 2)** → **US3 (Phase 3)** → **US1 (Phase 4)** →
  **US2 (Phase 5)** and **US4 (Phase 6)** (independent of each other) → **US5 (Phase 7)** →
  **Polish (Phase 8)**.
- US3 is deliberately before US1: no build of the branch shows a copy whose erasure is not done.
- Within a phase: tests first, then implementation; T009 before T010; T010 before T012; T017 before
  T018; T023 before T026; T024 before T025.
- `SessionManager.swift` is touched by T011, T012, T017, T018 (in that order, never in parallel);
  `VaultRepository.swift` by T023 then T032; `VaultsViewModel.swift` by T026 then T029.

## Parallel opportunities

```text
Phase 2 tests:   T003, T004, T005 together
Phase 2 code:    T006, T008 together; then T007; T009 → T010 → T012 (T011 alongside T009)
Phase 3 tests:   T013, T014, T015, T016 together
Phase 4 tests:   T019, T020, T021 together
Phase 4 code:    T022, T024, T025 together, then T023 → T026 → T027
Phase 6 tests:   T030, T031 together
Phase 7:         T034, T035, T036 together
Phase 8:         T037, T038 together
```

## Implementation strategy

1. **Foundation and privacy first** (Phases 1–3): the store, the rule, the session lifecycle. Fully
   tested before any data is kept.
2. **MVP** (Phase 4, US1): the list readable offline. Stop and validate with quickstart.md #1–3, 7–9.
3. **Increment** (Phases 5–6): instant online launch, vault screen offline.
4. **Make it the rule** (Phase 7): docs and the schema-wide erasure test, so every later resource
   follows the contract.
5. **Polish** (Phase 8): accessibility, definition of done, checks by hand, one pull request.
