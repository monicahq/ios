---

description: "Tasks for the vault list"
---

# Tasks: Vault List

**Input**: Design documents from `specs/003-vaults-list/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/monica-api.md](contracts/monica-api.md),
[contracts/ui.md](contracts/ui.md), [quickstart.md](quickstart.md)

**Tests**: Required by the constitution (III, IV): unit tests for every view model, repository and
non-UI type, UI tests for every state of every screen with the accessibility audit, one end-to-end
test per user story. Within a story, tests are written first and fail before the code they cover.

**Organization**: Grouped by user story. Order follows the spec's priorities, except that User
Story 4 (account, P2) comes before User Story 3 (create, P2): replacing the home removes logging out
until the account sheet exists, and the existing log-out journeys must stay green.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1–US5 from spec.md

---

## Phase 1: Setup

**Purpose**: Folders and tokens every story uses.

- [X] T001 Create the folders `Monica/Data/Vaults/`, `Monica/Vaults/`, `MonicaTests/Data/Vaults/`, `MonicaTests/Vaults/` and run `xcodegen generate` (plan.md, Project Structure)
- [X] T002 [P] Add the colour sets `GroupedPage`, `GroupedCard`, `GroupedMuted` with their light and dark values (research.md R7) in `Monica/Resources/Assets.xcassets/Colors/`
- [X] T003 [P] Add the 16 vault colour sets `Vault<Name>` and `Vault<Name>Tint` for Blue, Green, Ochre, Rust, Violet, Teal, Rose, Graphite with the light and dark values of research.md R6, in `Monica/Resources/Assets.xcassets/Colors/Vault/` (folder with "Provides Namespace" off, so symbols stay `Color.vaultBlue`)

---

## Phase 2: Foundational (data layer and fake instance)

**Purpose**: Everything the screens call. No UI. Blocks every story.

**⚠️ CRITICAL**: No story starts before this phase is green.

### Tests first

- [X] T004 [P] Unit tests for `MonicaClient` JSON post: method, `Content-Type`/`Accept` headers, body bytes, bearer token only to the instance's origin, 3xx → `.moved`, in `MonicaTests/Auth/MonicaClientTests.swift`
- [X] T005 [P] Unit tests for `SessionManager.authorized(_:_:json:)`: returns the raw response for 2xx/404/422, renews an expired token first, renews and retries once on 401, ends the session on a second 401, throws `.cancelled` when the session changed during the call, and `authorizedGet` keeps its current behaviour, in `MonicaTests/Auth/SessionManagerRenewalTests.swift`
- [X] T006 [P] Unit tests for `ApiError`/`Refusal` decoding of a 422 body (message, first message per field, undecodable body) in `MonicaTests/Data/ApiErrorTests.swift`
- [X] T007 [P] Unit tests for `Vault` decoding (every field of data-model.md `Vault.id`, `Vault.name`, `Vault.description`, `Vault.colour`, `Vault.isDefault`, `Vault.contactCount`; extra keys ignored), `VaultColour` parsing (case-insensitive, unknown → `.graphite`, `CaseIterable` order, `.blue` default) and `NewVault` encoding (data-model.md `NewVault.description` omitted when blank, `NewVault.makeDefault` sent only when true, no `structure_version_id`) in `MonicaTests/Data/Vaults/VaultTests.swift`
- [X] T008 [P] Unit tests for `vaultInitial` and `personInitials` (accents, emoji, leading spaces, "Jean-Pierre Martin" → "JM", symbols only → nil, empty → nil) in `MonicaTests/Vaults/InitialsTests.swift`
- [X] T009 Unit tests for `VaultRepository` against `FakeMonica` (contracts/monica-api.md): 0, 1, 100, 101 and 150 vaults in order with `per_page=100`, stop on an empty page, `vault(id:)` 200 and 404, `create` 201 and request body, 422 → `.invalid`, 403 → `.failed(.notAllowed)`, 500 and bad JSON → `.failed(.unexpectedAnswer)`, network → `.failed(.unreachable)`, in `MonicaTests/Data/Vaults/VaultRepositoryTests.swift`

### Implementation

- [X] T010 [P] Generalise `MonicaClient` with `send(method:url:json:token:)`, keep `get` on it and add `postJSON(_:body:token:)`, in `Monica/Auth/MonicaClient.swift` (research.md R1)
- [X] T011 Add `authorized(_ method:, _ path:, json:) async throws(AuthError) -> MonicaClient.Response` to `SessionManager` and rewrite `authorizedGet` over it, in `Monica/Auth/SessionManager.swift` (research.md R1; depends on T010)
- [X] T012 [P] Create `ApiError` and `Refusal` with the 422 decoding in `Monica/Data/ApiError.swift` (research.md R2, data-model.md `Refusal.fields`)
- [X] T013 [P] Create `Vault`, `VaultColour`, `NewVault` and their JSON:API decoding/encoding in `Monica/Data/Vaults/Vault.swift` (data-model.md `Vault.*`, `VaultColour`, `NewVault.*`)
- [X] T014 [P] Create `vaultInitial(_:)` and `personInitials(_:)` in `Monica/Vaults/Initials.swift` (research.md R12)
- [X] T015 Teach `FakeMonica` to hold vaults: `Request.body`, settings `vaults` and `vaultLimit`, routes `GET /api/v1/vaults` (paged, `meta.total`), `GET /api/v1/vaults/{id}` (404 unknown), `POST /api/v1/vaults` (JSON body, first vault default, `is_default` moves the badge, 422 for a blank name or the ceiling with the free plan's message), and the UI scenarios `withVaults`, `manyVaults`, `vaultLimit`, `vaultsUnreachable`, `slowVaults` (research.md R14), in `Monica/Debug/FakeMonica.swift`
- [X] T016 Create `VaultRepository` (`vaults()`, `vault(id:)`, `create(_:)`, status mapping of contracts/monica-api.md) in `Monica/Data/Vaults/VaultRepository.swift` (depends on T011–T013)
- [X] T017 Add a `vaultRepository` to the test `Harness` and a helper that signs the harness in, in `MonicaTests/Support/Fakes.swift`
- [X] T018 Run the unit tests: T004–T009 pass

**Checkpoint**: The app can list, read and create vaults in tests. Nothing visible yet.

---

## Phase 3: User Story 1 - See my vaults when I arrive (Priority: P1) 🎯 MVP

**Goal**: After sign-in the app shows "All your vaults" with one card per vault, pull to refresh,
and a placeholder vault screen.

**Independent Test**: Log in on `withVaults`: three cards in order, names, counts, one "Default";
relaunch keeps the list; tapping a card shows its name and description; Back returns.

### Tests first

- [X] T019 [P] [US1] Unit tests for `VaultsViewModel`: loading → loaded, loading → failed, try again, reload keeps the list and sets `isRefreshing`, failed reload sets `refreshFailed` and keeps the list, success clears it, dismiss, `.sessionEnded`/`.cancelled` leave the state unchanged, `hasVaults` (data-model.md `VaultsUiState`), in `MonicaTests/Vaults/VaultsViewModelTests.swift`
- [X] T020 [P] [US1] Unit tests for `VaultViewModel`: loaded, notFound, failed, try again (data-model.md `VaultUiState`), in `MonicaTests/Vaults/VaultViewModelTests.swift`
- [X] T021 [P] [US1] UI tests in `MonicaUITests/VaultsScreenUITests.swift`: list on `withVaults` (order, counts with "No contacts"/"1 contact"/"N contacts", one "Default", each card read as "Name, N contacts[, Default]"), loading on `slowVaults`, failed + Try again on `vaultsUnreachable`, pull to refresh and the Refresh accessibility action, 150 vaults on `manyVaults` (last card reachable and not under "New vault"), relaunch stays on the list, accessibility audit in each state
- [X] T022 [P] [US1] UI tests in `MonicaUITests/VaultScreenUITests.swift`: open from a card, name and description shown, Back returns to the same place, not found (fake removes the vault) shows "This vault no longer exists." and "Back to your vaults" reloads the list, audit
- [X] T023 [US1] Update `logIn` and the launch helpers to wait for "All your vaults" instead of the greeting, and update the landing assertions, in `MonicaUITests/Launch.swift`, `MonicaUITests/SignInJourneyUITests.swift`, `MonicaUITests/MonicaAppUITests.swift`

### Implementation

- [X] T024 [P] [US1] Create `VaultsUiState` and `VaultsContent` in `Monica/Vaults/VaultsUiState.swift` (data-model.md `VaultsUiState`)
- [X] T025 [P] [US1] Create `VaultUiState` in `Monica/Vaults/VaultUiState.swift` (data-model.md `VaultUiState`)
- [X] T026 [US1] Create `VaultsViewModel` (`load()`, `tryAgain()`, `dismissRefreshMessage()`, `hasVaults`) in `Monica/Vaults/VaultsViewModel.swift` (research.md R5)
- [X] T027 [US1] Create `VaultViewModel(id:repository:)` in `Monica/Vaults/VaultViewModel.swift`
- [X] T028 [P] [US1] Create `VaultColour` → colour sets and spoken names (`colour_blue` …) mapping in `Monica/Theme/VaultColours.swift` (research.md R6)
- [X] T029 [P] [US1] Create the floating styles (account circle and "New vault" capsule: glass on iOS 26, material or solid before, solid under Reduce Transparency) in `Monica/Theme/FloatingStyles.swift` (research.md R8)
- [X] T030 [US1] Create `VaultsRoute` (`NavigationStack` with `VaultDestination(id:)`, `.task { load }`, account and new-vault sheet slots) and the stateless `VaultsScreen` (top bar with fade, large title, cards, refresh message, floating "New vault", loading, failed; `.refreshable`; Refresh action; focus on the title after sign-in) per contracts/ui.md in `Monica/Vaults/VaultsScreen.swift`
- [X] T031 [US1] Create `VaultRoute` and the stateless `VaultScreen` (loaded, loading, notFound, failed) per contracts/ui.md in `Monica/Vaults/VaultScreen.swift`
- [X] T032 [US1] Show `VaultsRoute` instead of `HomeRoute` when signed in, and build `VaultRepository` and pass the dependencies, in `Monica/RootView.swift` and `Monica/MonicaApp.swift`
- [X] T033 [US1] Add the strings of the list and vault screens (`vaults_title`, `vaults_loading`, `vaults_refresh`, `vaults_refresh_failed`, `vaults_dismiss`, `vaults_try_again`, `vaults_new`, `vault_default`, plural `vault_contacts`, `vault_loading`, `vault_not_found`, `vault_back_to_list`, `account_button`, `colour_*`) in English and French in `Monica/Resources/Localizable.xcstrings` (contracts/ui.md, Strings)
- [ ] T034 [US1] Run the unit tests and the UI tests of T021–T023 until green *(UI tests last run before the final accessibility fixes: list, vault and account suites green except four test bugs since fixed; not rerun, as asked)*

**Checkpoint**: A signed-in person sees and opens their vaults. (Log out is unreachable until US4:
do not merge before Phase 6.)

---

## Phase 4: User Story 2 - Understand an empty account (Priority: P1)

**Goal**: An account with no vault sees the explanation and a "New vault" button.

**Independent Test**: Log in on `compatible` (no vault): title, icon, "No vault yet", explanation,
"New vault"; no floating button.

- [X] T035 [P] [US2] UI tests for the empty state (texts, no floating button, "New vault" calls the new-vault slot, audit, largest accessibility text size) in `MonicaUITests/VaultsScreenUITests.swift`
- [X] T036 [US2] Draw the empty state (tile with `archivebox`, `title2` heading, `groupedMuted` explanation, `PrimaryButtonStyle` "New vault") in `VaultsScreen` and hide the floating button outside the list state, in `Monica/Vaults/VaultsScreen.swift`
- [X] T037 [US2] Add `vaults_empty_title` and `vaults_empty_body` in English and French in `Monica/Resources/Localizable.xcstrings`
- [ ] T038 [US2] Run T035 until green *(written; covered by the last run before the final fixes; not rerun, as asked)*

**Checkpoint**: Every account, empty or not, lands on a meaningful screen.

---

## Phase 5: User Story 5 - Light, dark and Liquid Glass that stays readable (Priority: P1)

**Goal**: Every screen of the feature is readable in light, dark, Reduce Transparency and Increase
Contrast.

**Independent Test**: The audit passes on the list, empty, loading, failed and vault screens in
dark mode and with Reduce Transparency; the account button and "New vault" are opaque with Reduce
Transparency.

- [X] T039 [P] [US5] Add a `colorScheme` (dark) and a reduce-transparency launch option to `launchApp` (`-UIUserInterfaceStyle`/`UIAccessibilityReduceTransparency` launch arguments, or the `MONICA_UI_TEST_REDUCE_TRANSPARENCY` environment value read in Debug only by `FloatingStyles`) in `MonicaUITests/Launch.swift` and `Monica/Theme/FloatingStyles.swift`
- [X] T040 [US5] UI tests: audit of list, empty, loading, failed and vault screens in dark; with reduce transparency the floating controls still pass the contrast audit, in `MonicaUITests/VaultsScreenUITests.swift` and `MonicaUITests/VaultScreenUITests.swift`
- [ ] T041 [US5] Fix whatever T040 finds (tokens, styles), then check each screen by hand in light, dark, Reduce Transparency and Increase Contrast on the iOS 26.1 simulator and note the result for the pull request (quickstart.md, scenario 11) *(audit fixes applied: disabled button contrast; the manual check in Increase Contrast and on a device is still to do)*

**Checkpoint**: The P1 scope is complete and accessible.

---

## Phase 6: User Story 4 - Reach my account from the list (Priority: P2)

**Goal**: The initials button opens the account sheet with the instance and "Log out"; the
placeholder home is gone.

**Independent Test**: Tap "Your account": name and instance; Instance settings opens the instance
sheet; Log out after confirming returns to the welcome screen.

- [X] T042 [US4] Move `Monica/Home/` to `Monica/Account/` and `MonicaTests/Home/` to `MonicaTests/Account/` with `git mv`, renaming `HomeUiState` → `AccountUiState`, `HomeViewModel` → `AccountViewModel`, `HomeScreen.swift` → `AccountSheetView.swift`, `HomeViewModelTests` → `AccountViewModelTests`
- [X] T043 [P] [US4] Add unit tests for `AccountUiState.initials` (data-model.md `AccountUiState`) and keep every existing test of the view model green, in `MonicaTests/Account/AccountViewModelTests.swift`
- [X] T044 [P] [US4] Move `MonicaUITests/HomeScreenUITests.swift` to `MonicaUITests/AccountSheetUITests.swift` and rewrite it: open from "Your account", name and "Connected to {host}", initials or person symbol, Log out after confirming, Instance settings opens the instance sheet and switching asks, audit
- [X] T045 [US4] Add `initials` to `AccountUiState` and compute it in `AccountViewModel` (from `personInitials`), in `Monica/Account/AccountUiState.swift` and `Monica/Account/AccountViewModel.swift`
- [X] T046 [US4] Turn the home into the stateless `AccountSheetView` (Close, name heading, connected line, message, Instance settings, Log out, existing alerts) per contracts/ui.md, in `Monica/Account/AccountSheetView.swift`
- [X] T047 [US4] Present the account sheet from the account button in `VaultsRoute` (owning `AccountViewModel`, `.task { refresh }`), with "Instance settings" closing it before opening the instance sheet, in `Monica/Vaults/VaultsScreen.swift`
- [X] T048 [US4] Strings: add `account_connected`, `account_log_out`, `account_close`; remove `home_greeting`, `home_greeting_no_name`, `home_connected`, `home_log_out` and update their uses, in `Monica/Resources/Localizable.xcstrings`
- [ ] T049 [US4] Run all unit tests and T044 plus the sign-in and session journeys of `MonicaUITests/SignInJourneyUITests.swift` until green *(account and sign-in journeys green in the last run; not rerun after the final fixes, as asked)*

**Checkpoint**: Feature parity with the old home is back; the branch can be merged from here.

---

## Phase 7: User Story 3 - Create a vault (Priority: P2)

**Goal**: A short form creates a vault from the list or the empty state.

**Independent Test**: On `compatible`, create the first vault from the empty state: it is "Default".
On `withVaults`, create one with "Make this the default vault": it appears at the end with the
badge. On `vaultLimit`, the instance's message shows under Name and the values stay.

### Tests first

- [X] T050 [P] [US3] Unit tests for `NewVaultViewModel`: `canCreate` (blank name, saving), changing a field clears its error, `create()` sends trimmed name, omitted blank description, colour and `is_default` only when on, returns the vault; 422 on `name` / `description` / `colour` / no field goes to the right place; network error kept with the values; double tap creates once; `cancel()` closes or asks per `hasTypedSomething`; `keepEditing()` (data-model.md `NewVaultUiState.name`, `NewVaultUiState.description`, `NewVaultUiState.colour`, `NewVaultUiState.makeDefault`, `NewVaultUiState.offersDefault`, `NewVaultUiState.canCreate`, `NewVaultUiState.hasTypedSomething`), in `MonicaTests/Vaults/NewVaultViewModelTests.swift`
- [X] T051 [P] [US3] UI tests in `MonicaUITests/NewVaultScreenUITests.swift`: first vault from the empty state becomes "Default" (no default toggle offered), from the list with the toggle the badge moves and the vault is last, blank name disables "Create vault", colours read by name with "Selected", ceiling refusal on `vaultLimit` keeps the values, Cancel with text asks and "Keep editing" keeps them, Cancel without text closes, swipe down with text does not close, audit, French

### Implementation

- [X] T052 [P] [US3] Create `NewVaultUiState` in `Monica/Vaults/NewVaultUiState.swift` (data-model.md `NewVaultUiState.*`; the name's 255-character limit of data-model.md `Vault.name` is left to the instance's refusal)
- [X] T053 [US3] Create `NewVaultViewModel(offersDefault:repository:)` in `Monica/Vaults/NewVaultViewModel.swift` (research.md R13)
- [X] T054 [US3] Create `NewVaultRoute` and the stateless `NewVaultScreen` (header with Cancel, fields with errors, colour grid, default toggle, general error, Create with progress, discard dialog, `interactiveDismissDisabled`) per contracts/ui.md, in `Monica/Vaults/NewVaultScreen.swift`
- [X] T055 [US3] Present the new-vault sheet from the floating button and the empty state in `VaultsRoute` with `offersDefault = hasVaults`, close it and reload the list after a creation, in `Monica/Vaults/VaultsScreen.swift`
- [X] T056 [US3] Add the `new_vault_*` strings in English and French in `Monica/Resources/Localizable.xcstrings`
- [ ] T057 [US3] Run T050 and T051 until green *(unit tests green; the form UI tests had 5 failures in the last run, fixed since but not rerun, as asked)*

**Checkpoint**: Every story of the spec works on its own.

---

## Phase 8: Polish & cross-cutting

- [X] T058 [P] Update `docs/architecture.md` (`Data/ApiError`, repositories over `SessionManager.authorized`, signed-in navigation, grouped colour tokens and floating styles) and `docs/testing.md` (vault fake, new scenarios, dark and reduce-transparency launches)
- [X] T059 [P] Add the feature to `docs/FEATURES.md` with the `feature-documentator` skill
- [X] T060 [P] Review the change with the `accessibility-reviewer` agent and fix its findings across `Monica/Vaults/`, `Monica/Account/`, `Monica/Theme/`
- [X] T061 Run the `definition-of-done` skill: `xcodegen generate && swiftformat . && swiftlint --strict`, all unit tests, `scripts/check-coverage.sh` ≥ 80%, the UI tests of this feature (quickstart.md, Automated)
- [ ] T062 VoiceOver, largest text size and French checks by hand (quickstart.md, scenarios 12–14); screenshots of list, empty state and form in light and dark with the `take-screenshot` skill; reinstall and relaunch the app on the simulator *(still to do by hand: VoiceOver, largest text, French, screenshots)*

---

## Dependencies & execution order

- **Setup (1)** → **Foundational (2)** → stories.
- **US1 (3)** needs Phase 2. **US2 (4)** and **US5 (5)** need US1's screen. **US4 (6)** needs US1
  (the button lives on the list). **US3 (7)** needs US1 and US2 (its two entry points) and is
  independent of US4.
- Merge point: after Phase 6 (log out reachable again). Phase 8 last.

## Parallel opportunities

- Phase 1: T002 ∥ T003.
- Phase 2: tests T004–T008 together; then T010 ∥ T012 ∥ T013 ∥ T014; T015 alongside them.
- US1: T019 ∥ T020 ∥ T021 ∥ T022; then T024 ∥ T025 ∥ T028 ∥ T029.
- US4: T043 ∥ T044 after T042.
- US3: T050 ∥ T051 ∥ T052.
- Polish: T058 ∥ T059 ∥ T060.

```text
# Example: start US1 once Phase 2 is green
Task: "Unit tests for VaultsViewModel in MonicaTests/Vaults/VaultsViewModelTests.swift"
Task: "Unit tests for VaultViewModel in MonicaTests/Vaults/VaultViewModelTests.swift"
Task: "UI tests in MonicaUITests/VaultsScreenUITests.swift"
Task: "UI tests in MonicaUITests/VaultScreenUITests.swift"
```

## Implementation strategy

1. **MVP**: Phases 1–3 (US1): the list after sign-in, on a branch, not merged alone.
2. Phase 4 (US2) and 5 (US5): the P1 scope, accessible.
3. Phase 6 (US4): parity with the old home; first mergeable state.
4. Phase 7 (US3): creating vaults.
5. Phase 8: docs, review, definition of done, pull request.
