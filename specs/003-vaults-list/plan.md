# Implementation Plan: Vault List

**Branch**: `2026-11-27-vaults-list` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-vaults-list/spec.md`

## Summary

Replace the placeholder home with "All your vaults", as the Android app does in its PR #7: the
account's vaults as cards (colour, initial, name, contact count, "Default"), an empty state, pull to
refresh, a placeholder vault screen, a form to create a vault, and an account sheet holding what the
placeholder home offered (instance, log out). Drawn from the design's iOS frames in Liquid Glass:
large title, frosted account button and centred logo floating over content that fades beneath, white
cards on the grouped grey, a floating "New vault" capsule.

Technically: one new repository (`VaultRepository`) over a generalised authorised call in
`SessionManager` and a JSON post in `MonicaClient`; an `ApiError` for 404 and 422; three screens and
their `@Observable` view models; `NavigationStack` with one typed destination; Liquid Glass from iOS
26 with a material or solid fallback and a solid style under Reduce Transparency; Android's measured
vault colours as colour sets; `FakeMonica` taught to hold vaults. No Monica change, no package. See
[research.md](research.md).

## Technical Context

**Language/Version**: Swift 6 (language mode 6, complete concurrency checking), Xcode 27.2 (iOS 27.2 SDK)

**Primary Dependencies**: SwiftUI (incl. `glassEffect` / `.glassProminent` behind `#available(iOS 26, *)`), Observation, Foundation `URLSession`. No Swift package

**Storage**: none new: vaults are kept in memory while shown (FR-024); the session stays in the Keychain (existing)

**Testing**: Swift Testing in `MonicaTests` against `FakeMonica` (extended with vault endpoints); XCUITest in `MonicaUITests` with new fake scenarios, accessibility audit in every state

**Target Platform**: iOS 18+ (Liquid Glass on iOS 26+), iPhone

**Project Type**: mobile app (no server change)

**Performance Goals**: list or empty state within 2 s of sign-in on a normal connection (SC-001): one request for up to 100 vaults; scrolling smooth with 150 vaults (`LazyVStack`)

**Constraints**: API only; every text in English and French; WCAG 2.2 AA in light, dark, Reduce Transparency, Increase Contrast and the accessibility text sizes; no translucent control under Reduce Transparency (SC-007); vault data never written to disk

**Scale/Scope**: 3 new screens (list, vault placeholder, new vault) and 1 sheet reworked from the placeholder home; 3 endpoints; ~35 strings; 19 colour sets

## Constitution Check

*GATE: checked before Phase 0 research, re-checked after Phase 1 design.*

| Principle | Status | How |
|-----------|--------|-----|
| Product context: API only, web wording, web read first | ✅ | Uses the documented `GET/POST /api/v1/vaults` and `GET /api/v1/vaults/{id}`; nothing invented for the data the API lacks (FR-011). Wording from the web ("No vault yet", "Default") and Android's spec; the web views and API docs were read. |
| I. Simplicity | ✅ | No package, no target. One new repository, no protocol for it (tests use `FakeMonica`). `ApiError` is needed by the 404 and 422 answers. `FloatingStyles` exists because two controls need the same three-way style. No router object, no use-case layer. |
| II. Apple practices | ✅ | `@Observable @MainActor` view models with one `state`; stateless `VaultsScreen`, `VaultScreen`, `NewVaultScreen`, `AccountSheetView`; `VaultRepository` as the single source of truth; dependencies injected from `MonicaApp`; `NavigationStack` with a typed destination; system glass APIs; no `!` / `try!`. |
| III. Unit tested | ✅ | Tests for `VaultRepository` (paging, decoding, statuses, request bodies), `Vault` parsing and colours, `ApiError` mapping, initials, `SessionManager.authorized` and `MonicaClient` JSON post, and every state and event of `VaultsViewModel`, `VaultViewModel`, `NewVaultViewModel`, `AccountViewModel`. Coverage gate 80%. |
| IV. UI tested | ✅ | Every state of every screen and the main interactions, one end-to-end test per user story (contracts/ui.md, "UI tests"), audit in each. |
| V. Native only | ✅ | SwiftUI only. |
| VI. Multilingual | ✅ | All new strings in the catalog in English and French, keys shared with Android, plural variations for the contact count, French from `lang/fr_FR.json` where it exists; `LocalizationParityTests` guards it. |
| VII. Accessible | ✅ | Cards as one button read from their visible texts; Refresh action as the gesture alternative; header traits; decorative images hidden; 44 pt targets; colours measured (R6, R7); glass made solid with Reduce Transparency (R8); layouts that rewrap at accessibility sizes; Reduce Motion respected by system components; audit in UI tests; VoiceOver pass stated in the PR. |
| Coverage exclusions respected | ✅ | Logic lives in view models, `Vault.swift`, `Initials.swift`; `*Screen.swift`, `*View.swift` and `Theme/` hold only drawing. |

Post-design re-check: ✅ no violation; Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-vaults-list/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R16
├── data-model.md        # Phase 1: types, states, transitions
├── quickstart.md        # Phase 1: how to validate
├── contracts/
│   ├── monica-api.md    # the three calls and their status mapping
│   └── ui.md            # screens, accessibility, strings, UI tests
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
Monica/
├── Auth/
│   ├── MonicaClient.swift          # changed: general send(method:url:json:token:), postJSON
│   └── SessionManager.swift        # changed: authorized(_:_:json:) under authorizedGet
├── Data/
│   ├── ApiError.swift              # new: ApiError, Refusal, 422 decoding
│   └── Vaults/
│       ├── Vault.swift             # new: Vault, VaultColour, NewVault, decoding
│       └── VaultRepository.swift   # new: vaults(), vault(id:), create(_:)
├── Vaults/
│   ├── Initials.swift              # new: vaultInitial, personInitials
│   ├── VaultsUiState.swift         # new
│   ├── VaultsViewModel.swift       # new
│   ├── VaultsScreen.swift          # new: VaultsRoute (NavigationStack, sheets) + VaultsScreen
│   ├── VaultUiState.swift          # new
│   ├── VaultViewModel.swift        # new
│   ├── VaultScreen.swift           # new: VaultRoute + VaultScreen
│   ├── NewVaultUiState.swift       # new
│   ├── NewVaultViewModel.swift     # new
│   └── NewVaultScreen.swift        # new: NewVaultRoute + NewVaultScreen
├── Account/                        # was Home/
│   ├── AccountUiState.swift        # was HomeUiState, + initials
│   ├── AccountViewModel.swift      # was HomeViewModel
│   └── AccountSheetView.swift      # was HomeScreen, as a sheet
├── Theme/
│   ├── FloatingStyles.swift        # new: glass / material / solid for the two floating controls
│   └── VaultColours.swift          # new: VaultColour → colour sets and spoken names
├── Debug/FakeMonica.swift          # changed: vault endpoints, JSON bodies, new scenarios
├── RootView.swift                  # changed: VaultsRoute when signed in
├── MonicaApp.swift                 # changed: builds VaultRepository, passes the dependencies
└── Resources/
    ├── Assets.xcassets/Colors/     # new: GroupedPage, GroupedCard, GroupedMuted, Vault/ (16 sets)
    └── Localizable.xcstrings       # changed: new strings, home_* removed or renamed

MonicaTests/
├── Auth/MonicaClientTests.swift, SessionManagerRenewalTests.swift   # changed: JSON post, authorized
├── Data/ApiErrorTests.swift, Vaults/VaultTests.swift, Vaults/VaultRepositoryTests.swift   # new
├── Vaults/InitialsTests.swift, VaultsViewModelTests.swift, VaultViewModelTests.swift, NewVaultViewModelTests.swift   # new
└── Account/AccountViewModelTests.swift   # was Home/HomeViewModelTests.swift

MonicaUITests/
├── VaultsScreenUITests.swift, VaultScreenUITests.swift, NewVaultScreenUITests.swift   # new
├── AccountSheetUITests.swift       # was HomeScreenUITests.swift
├── Launch.swift                    # changed: logIn waits for "All your vaults"; vault scenarios
└── SignInJourneyUITests.swift, MonicaAppUITests.swift   # changed: land on the list

docs/architecture.md                # changed: Data/ApiError, repositories over `authorized`, signed-in navigation, grouped tokens
docs/testing.md                     # changed: new fake scenarios
docs/FEATURES.md                    # changed: one line for the feature
```

**Structure Decision**: Feature folders as `docs/architecture.md` prescribes: screens and view models
in `Vaults/` and `Account/`, the repository and its model in `Data/Vaults/`, shared API error in
`Data/`. The placeholder `Home/` becomes `Account/`, since what is left of it is the account.

## Delivery order

1. **Data** (no UI): `MonicaClient` JSON post, `SessionManager.authorized`, `ApiError`, `Vault`,
   `VaultRepository`, `FakeMonica` vault endpoints, with their unit tests.
2. **US1 + US5**: colour sets, `FloatingStyles`, `VaultsViewModel` + `VaultsScreen` (list, loading,
   failed, refresh), `VaultScreen`, `RootView` switch; UI tests and audit in light and dark.
3. **US2**: empty state; UI tests.
4. **US4**: `Home` → `Account`, account sheet from the list; UI tests (sign-out journey kept green).
5. **US3**: `NewVaultViewModel` + `NewVaultScreen`; UI tests incl. the ceiling refusal.
6. Strings in French, docs, `FEATURES.md`, definition of done, screenshots, VoiceOver pass.

## Complexity Tracking

No violation.
