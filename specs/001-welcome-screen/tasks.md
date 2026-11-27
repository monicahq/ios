---
description: "Task list for the welcome screen"
---

# Tasks: Welcome Screen

**Input**: Design documents from `specs/001-welcome-screen/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/welcome-screen.md](contracts/welcome-screen.md)

**Tests**: required by the constitution (principles III, IV and VII): unit tests for non-UI code,
XCUITest UI tests with the automated accessibility audit for the screen.

**Organization**: tasks are grouped by user story so each story can be built and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to (US1, US2, US3, US4)

## Phase 1: Setup

**Purpose**: build configuration shared by every story.

- [x] T001 Write `scripts/check-coverage.sh` with the exclusions and 80% line bound of research R10
- [x] T002 [P] Run the coverage gate after the tests in the "Unit tests" job of `.github/workflows/ci.yml`
- [x] T003 [P] Add `MonicaTests/.swiftlint.yml` so test names can be raw identifiers (`docs/testing.md`)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: theme, assets and the instance helper every story uses.

- [x] T004 [P] Add the Monica light and dark colour sets of research R2 in `Monica/Resources/Assets.xcassets/Colors/`
- [x] T005 [P] Write `PrimaryButtonStyle` and `OutlinedButtonStyle` (research R3) in `Monica/Theme/ButtonStyles.swift` (depends on T004)
- [x] T006 [P] Convert the logo of the design into `Monica/Resources/Assets.xcassets/Logo.imageset/Logo.svg` (colours kept, vector preserved)
- [x] T007 [P] Convert the panda illustration into `Monica/Resources/Assets.xcassets/PandaWelcome.imageset/PandaWelcome.heic`
- [x] T008 [P] Write `InstanceTests` covering the host derivation of `data-model.md` `Instance.host` (scheme removed, trailing slash removed, port and path kept) in `MonicaTests/Instance/InstanceTests.swift`
- [x] T009 Implement `defaultInstanceURL` (`data-model.md` `Instance.url`) and `instanceHost()` (`data-model.md` `Instance.host`) in `Monica/Instance/Instance.swift` until T008 passes
- [x] T010 [P] Write `HighlightTests` in `MonicaTests/Welcome/HighlightTests.swift`, then `highlight()` in `Monica/Welcome/Highlight.swift` until they pass

**Checkpoint**: theme, assets and helpers ready.

---

## Phase 3: User Story 1 - See the welcome screen (Priority: P1) 🎯 MVP

**Goal**: the app opens on the welcome screen of the design, in light and dark, with controls that do nothing.

**Independent test**: launch the app; every element of the design is visible, in order, taps do nothing.

### Tests for User Story 1

- [x] T011 [P] [US1] Write UI tests for every element, their order, the controls doing nothing and dark mode in `MonicaUITests/WelcomeScreenUITests.swift`, with the launch helpers in `MonicaUITests/Launch.swift`
- [x] T012 [P] [US1] Update `MonicaUITests/MonicaAppUITests.swift` so the end-to-end tests check the app opens on the welcome screen and a tap on "Log in" keeps it there

### Implementation for User Story 1

- [x] T013 [US1] Add the English strings of `data-model.md` (Strings table) and remove the old `welcome` string in `Monica/Resources/Localizable.xcstrings`
- [x] T014 [US1] Implement the stateless `WelcomeScreen` of `contracts/welcome-screen.md` with the layout of research R4 and R5, plus light, dark and French previews, in `Monica/Welcome/WelcomeScreen.swift`
- [x] T015 [US1] Show `WelcomeScreen(instanceHost: instanceHost(defaultInstanceURL), ...)` with empty closures from `Monica/MonicaApp.swift`

**Checkpoint**: User Story 1 is usable and tested.

---

## Phase 4: User Story 2 - Read the screen in my language (Priority: P2)

**Goal**: French on French devices, English everywhere else, both listed in the app's Language setting.

**Independent test**: switch the app language to French; every text is in French.

### Tests for User Story 2

- [x] T016 [P] [US2] Write `LocalizationParityTests` (every key translated in every language, same placeholders, research R7) in `MonicaTests/LocalizationParityTests.swift`
- [x] T017 [P] [US2] Add French and unsupported-language UI tests (research R8) to `MonicaUITests/WelcomeScreenUITests.swift`

### Implementation for User Story 2

- [x] T018 [US2] Add the French strings of `data-model.md` (Strings table, non-breaking space before the colon, `app_name` listed too) in `Monica/Resources/Localizable.xcstrings`

**Checkpoint**: User Stories 1 and 2 work independently.

---

## Phase 5: User Story 3 - Use the screen with accessibility settings (Priority: P3)

**Goal**: usable with VoiceOver, at the largest text size and on small screens.

**Independent test**: with VoiceOver and the largest text size, every control is reachable, labelled and nothing is cut.

### Tests for User Story 3

- [x] T019 [P] [US3] Add the accessibility audit in light and dark, the decorative-logo check, 44 pt targets and a largest-text-size reachability test to `MonicaUITests/WelcomeScreenUITests.swift`

### Implementation for User Story 3

- [x] T020 [US3] Fix in `Monica/Welcome/WelcomeScreen.swift` whatever T019 reveals (header trait, hidden icons, target sizes)

**Checkpoint**: all user stories work and are tested.

---

## Phase 6: User Story 4 - Choose the Monica instance (Priority: P4)

**Goal**: the settings button and the instance line open a sheet to choose the instance, kept on the device.

**Independent test**: open the sheet, save another address, relaunch the app: the instance line shows it.

### Tests for User Story 4

- [x] T027 [P] [US4] Write `NormalizeInstanceURLTests` (research R13) in `MonicaTests/Instance/InstanceTests.swift`
- [x] T028 [P] [US4] Write `InstanceRepositoryTests` with a temporary `UserDefaults` (research R12) in `MonicaTests/Instance/InstanceRepositoryTests.swift`
- [x] T029 [P] [US4] Write `WelcomeViewModelTests` for every state and event of `data-model.md` (Welcome UI state) in `MonicaTests/Welcome/WelcomeViewModelTests.swift`
- [x] T030 [P] [US4] Write `InstanceSheetUITests` (open from both controls, save, Return, cancel, pull down, reset, error, French, largest text size, audit in light, dark and with the error) in `MonicaUITests/InstanceSheetUITests.swift`, with a fresh preferences store per launch in `MonicaUITests/Launch.swift`
- [x] T031 [P] [US4] Add an end-to-end test of an address kept after relaunching to `MonicaUITests/MonicaAppUITests.swift`, and make `WelcomeScreenUITests` expect only "Sign up" and "Log in" to do nothing

### Implementation for User Story 4

- [x] T032 [US4] Implement `normalizeInstanceURL` in `Monica/Instance/Instance.swift` and `InstanceRepository` in `Monica/Instance/InstanceRepository.swift` until T027 and T028 pass
- [x] T033 [US4] Implement `WelcomeUiState` and `WelcomeViewModel` in `Monica/Welcome/` until T029 passes
- [x] T034 [US4] Add the sheet strings of `data-model.md` in English and French in `Monica/Resources/Localizable.xcstrings`
- [x] T035 [US4] Implement `InstanceSheetView` (research R14) and `TextButtonStyle`, present the sheet from `WelcomeScreen`, add `WelcomeRoute`, and show it from `MonicaApp` with an `InstanceRepository`, until T030 and T031 pass

**Checkpoint**: all user stories work and are tested.

---

## Phase 7: Polish & cross-cutting concerns

- [x] T021 [P] Resolve `TODO(COVERAGE_GATE)` in `.specify/memory/constitution.md` and describe the gate in `docs/testing.md`
- [x] T022 [P] Document languages and the theme in `docs/architecture.md`, accessibility in `docs/accessibility.md`, and the welcome screen in `docs/FEATURES.md`
- [x] T023 Run the `definition-of-done` checks: SwiftFormat, SwiftLint, unit tests, coverage gate, debug and release builds
- [x] T024 Run the UI tests on a simulator and the automated parts of `quickstart.md`
- [x] T025 Review the change with the `accessibility-reviewer` agent and fix its findings
- [ ] T026 Do the manual VoiceOver pass of `quickstart.md` on a device or a simulator, screen and sheet
- [x] T036 [P] Describe preferences in `docs/architecture.md` and `docs/testing.md`, and the instance sheet in `docs/FEATURES.md`

---

## Dependencies & execution order

- Setup (Phase 1) → Foundational (Phase 2) → User stories → Polish.
- US1 depends on Phase 2. US2, US3 and US4 depend on US1 (they test and extend the same screen) but not on each other.
- Within a story, tests are written first and fail before the implementation.

### Parallel opportunities

- T002 and T003 in parallel after T001.
- T004, T006, T007, T008 and T010 in parallel.
- T011 and T012 in parallel; T016 and T017 in parallel; T021 and T022 in parallel.

```text
# Phase 2 in parallel
T004 colour sets   T006 Logo.svg   T007 PandaWelcome.heic   T008 InstanceTests   T010 Highlight
```

## Implementation strategy

1. MVP: Phases 1–3, then validate User Story 1 on a simulator.
2. Add US2 (French), then US3 (accessibility checks), each validated on its own.
3. Polish, definition of done, pull request.
