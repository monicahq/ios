---

description: "Tasks for Log In and Sign Up"
---

# Tasks: Log In and Sign Up

**Input**: Design documents from `specs/002-login-registration/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Mandatory (constitution III and IV): unit tests for every non-UI type, UI tests with the
accessibility audit for every screen state, one end-to-end UI journey per user story. Tests are
written before the code they cover and must fail first.

**Organization**: phase 2 is the Monica pull request (`../monica`), the rest is this repository.
Paths are relative to this repository unless they start with `../monica/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: user story from spec.md (US1 to US5)

---

## Phase 1: Setup

**Purpose**: project configuration the whole feature needs

- [X] T001 Declare `CFBundleURLTypes` with scheme `com.monicahq.ios` (research R6) in `Config/Info.plist`, and the same plus a Debug-only `NSAppTransportSecurity` (`NSAllowsLocalNetworking`, `NSAllowsArbitraryLoads`, research R11) in `Config/Info-Debug.plist`, selected per configuration with `INFOPLIST_FILE` in `project.yml`; keep `GENERATE_INFOPLIST_FILE: YES` so generated keys still merge
- [X] T002 [P] Run `xcodegen generate` and check a Release build has no ATS exception (`plutil -p` on the built app's Info.plist)
- [X] T003 [P] Create test support: `Monica/Debug/FakeMonica.swift` (Debug only; a fake Monica per host behind a `URLProtocol`, records every request, can answer `URLError` codes and 3xx, also used by UI tests per T021) and `MonicaTests/Support/Fakes.swift` (`FakeSecretStore`, in-memory, same protocol as T012; `FakeClock`; a `Harness` wiring them)

---

## Phase 2: Monica server (`../monica`, its own pull request, merged before the iOS PR)

**Purpose**: let the iOS app sign in (spec FR-020 to FR-023, [contracts/monica-server-ios.md](contracts/monica-server-ios.md), research R1 to R4)

**⚠️ Does not block iOS development** (local Monica on this branch, stubs in UI tests); blocks only merging the iOS PR.

- [X] T004 In `../monica`, update `main` and create branch `2026-11-27-ios-app-sign-in`; read Monica's `definition-of-done`, `migrations`, `api-docs-writer`, `changelog` and `pull-requests` skills under `../monica/.claude/skills/`
- [X] T005 Write failing tests first: `../monica/tests/Feature/MobileClientProvisioningTest.php` (both return addresses, migration run twice keeps one client with the same id, an Android session still renews), `../monica/tests/Feature/OAuth/MobileSignInTest.php` (iOS consent title in English and French, Allow redirects to `com.monicahq.ios:/oauth/callback?code&state`, exchange with the iOS address creates a `mobile_sessions` row with `device_name`, exchange of an iOS code with the Android address is `invalid_grant`), `../monica/tests/Feature/BindOAuthScopesTest.php` (refused scope from iOS redirects to the iOS address), `../monica/tests/Feature/Controllers/Api/StatusControllerTest.php` (`mobile.minimum_ios_version` null by default, configured value, empty string → null), `../monica/tests/Unit/ViewModels/Auth/OAuthAuthorizationViewModelTest.php` (title per return address)
- [X] T006 In `../monica/app/Models/MobileSession.php` replace `REDIRECT_URI` by `ANDROID_REDIRECT_URI`, `IOS_REDIRECT_URI` and `REDIRECT_URIS`; update every use (`tests/TestCase.php`, existing tests → `ANDROID_REDIRECT_URI`)
- [X] T007 Create `../monica/database/migrations/2026_11_27_000000_let_the_ios_app_sign_in.php` setting the mobile client's `redirect_uris` to both addresses (values written out, idempotent, `down()` restores Android only), per contract §1
- [X] T008 In `../monica/app/Http/Middleware/BindOAuthScopes.php`, `refuse()` redirects to whichever of `MobileSession::REDIRECT_URIS` the request named (contract §2)
- [X] T009 In `../monica/app/ViewModels/Auth/OAuthAuthorizationViewModel.php`, `title()` returns "Allow Monica for iOS to reach your account?" when the return address is `IOS_REDIRECT_URI`; add the key to every `../monica/lang/*.json` (French: "Autoriser Monica pour iOS à accéder à votre compte ?", others per Monica's `add-locale` rules) (contract §3)
- [X] T010 Add `minimum_ios_version` to `../monica/config/monica.php` (`MONICA_MINIMUM_IOS_VERSION`), `../monica/.env.example`, `../monica/app/Http/Controllers/Api/StatusController.php`, and document it in `../monica/resources/docs/api/10-health.php` (field list and example) (contract §4)
- [X] T011 Add the changelog entry for the iOS app sign-in per Monica's `changelog` skill, run Monica's definition of done (tests, static analysis, formatting), commit `feat(auth): sign in from the iOS app`, push and open the PR describing the change and linking this spec

**Checkpoint**: `curl {base}/api/v1/status` shows `minimum_ios_version`; quickstart §1 passes.

---

## Phase 3: Foundational (iOS, blocks every user story)

**Purpose**: the types every story uses

- [X] T012 [P] Write `MonicaTests/Auth/SecretStoreTests.swift` then `Monica/Auth/SecretStore.swift`: protocol (`read`, `write`, `delete` of a `Codable` value by key) and `KeychainSecretStore` (service `com.monicahq.ios.auth`, keys `session`, `pending-sign-in`, `pending-revocation`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, add-or-update in one call, undecodable value deleted and returned as nil, `wipeIfFreshInstall(defaults:)` using an "installed" marker in `UserDefaults`) (research R8)
- [X] T013 [P] Write `MonicaTests/Auth/PKCETests.swift` then `Monica/Auth/PKCE.swift`: random 32-byte base64url values for `data-model.md` `PendingSignIn.state` and `PendingSignIn.verifier`, S256 challenge checked against RFC 7636 appendix B, authorization URL builder per [contracts/ios-auth.md §3](contracts/ios-auth.md) (Log in `prompt=consent`, Sign up `prompt=consent create`) (research R9)
- [X] T014 [P] Write `MonicaTests/Auth/AuthErrorTests.swift` then `Monica/Auth/AuthError.swift`: every case of research R12, the `URLError` code mapping, one String Catalog key per case; add English and French values to `Monica/Resources/Localizable.xcstrings`, reusing Android's keys and wording from `../android/app/src/main/res/values*/strings.xml` where the text exists
- [X] T015 [P] Write `MonicaTests/Auth/AppVersionTests.swift` then `Monica/Auth/AppVersion.swift`: numeric component comparison, non-version strings ignored (research R16)
- [X] T016 [P] Create `Monica/Auth/PendingSignIn.swift`, `Monica/Auth/Session.swift` and `Monica/Auth/PendingRevocation.swift` as `Codable`, `Equatable` value types with the fields of `data-model.md` `PendingSignIn`, `Session` and `PendingRevocation`; `description` and `debugDescription` hide tokens, state and verifier (FR-019a), tested in `MonicaTests/Auth/SecretsDescriptionTests.swift`
- [X] T017 Write `MonicaTests/Auth/MonicaClientTests.swift` then `Monica/Auth/MonicaClient.swift`: built for one base URL on an injected `URLSessionConfiguration` (`.ephemeral` in the app), 15 s timeout, redirect delegate returning nil (3xx → `AuthError.moved`), `Authorization: Bearer` only when the request origin equals the base origin, form-encoded POST and JSON GET helpers, `URLError` → `AuthError`, `invalidateAndCancel()`; tests with `StubURLProtocol` prove no header goes to another origin or after a redirect (research R7, FR-017)
- [X] T018 Write `MonicaTests/Instance/InstanceCheckerTests.swift` then `Monica/Instance/InstanceChecker.swift`: reads status then metadata per [contracts/ios-auth.md §2](contracts/ios-auth.md) and returns `data-model.md` `InstanceDescription` (all fields) or `AuthError` (`notMonica`, `monicaTooOld` including a missing `minimum_ios_version`, `appTooOld` from `InstanceDescription.minimumIOSVersion` via `AppVersion`, `noAppSignIn` for issuer mismatch, missing S256, endpoint on another origin or outside the base path); base under a path (`https://example.com/monica`) tested
- [X] T019 Change `Monica/Instance/Instance.swift` to `normalizeInstanceURL(_:allowsHTTP:)` (http refused unless `allowsHTTP`, returning `.httpsRequired` vs `.invalidAddress` distinctly, credentials in the URL refused) and add an origin comparison helper; update `MonicaTests/Instance/InstanceTests.swift` (research R11, FR-019, `data-model.md` `Instance.url`)
- [X] T020 Write `MonicaTests/Auth/SessionManagerTests.swift` (sign-in part) then `Monica/Auth/SessionManager.swift`: `@MainActor @Observable`, `state` per `data-model.md` `SessionState`, `generation`, injected `SecretStore`, client factory, clock and device name; `startSignIn(description:isSignUp:)` stores a `PendingSignIn` (replacing any previous one) and returns the authorization URL; `complete(callback:)` validates per [contracts/ios-auth.md §1](contracts/ios-auth.md) (no pending, state mismatch, used, older than `PendingSignIn.createdAt` + 1 h, other instance → rejected with nothing sent), deletes the pending sign-in before exchanging, exchanges the code ([contracts/ios-auth.md §4](contracts/ios-auth.md)), loads `/api/v1/me`, stores the `Session` (`Session.accessTokenExpiresAt` from `expires_in` and the clock); a result arriving after `generation` changed is discarded
- [X] T021 Create `Monica/Debug/UITestServer.swift` (`#if DEBUG`): `URLProtocol` playing a Monica for scenarios selected by `MONICA_UI_TEST_SERVER` (`compatible`, `registrationClosed`, `notMonica`, `monicaTooOld`, `appTooOld`, `unreachable`, `renewalRefused`, `notAllowed`) and a fake browser returning `allow`, `deny` or `cancel` from `MONICA_UI_TEST_BROWSER` (research R17); add a `launchApp(server:browser:)` helper in `MonicaUITests/Launch.swift`
- [X] T022 Create `Monica/RootView.swift` switching on `SessionManager.state` (welcome or home) and wire `MonicaApp.swift`: build `KeychainSecretStore` (wipe on fresh install first), `SessionManager`, `InstanceChecker`, the real `.ephemeral` configuration or the Debug UI test server (research R13)

**Checkpoint**: unit tests green; the app still shows the welcome screen.

---

## Phase 4: User Story 1 - Log in to the official Monica instance (Priority: P1) 🎯 MVP

**Goal**: "Log in" opens the authentication sheet, and the person comes back signed in, kept across relaunches.

**Independent Test**: on the default instance, tap "Log in", allow, see the name on the home; relaunch, still signed in; cancel and deny show their messages.

- [X] T023 [P] [US1] Write `MonicaTests/Welcome/WelcomeViewModelTests.swift` cases for log in: checking → opening (URL handed to the view) → signing in → signed in; cancel → `failed(.cancelled)` and Log in works again; deny → `failed(.denied)`; check failure → its error; double tap starts one attempt (`data-model.md` `WelcomeUiState.signIn`)
- [X] T024 [P] [US1] Write `MonicaTests/Home/HomeViewModelTests.swift`: shows `Session.name` and the instance host from `data-model.md` `HomeUiState`
- [X] T025 [US1] Extend `Monica/Welcome/WelcomeUiState.swift` and `Monica/Welcome/WelcomeViewModel.swift` with `signIn` (`data-model.md` `WelcomeUiState.signIn`), `logIn()`, `browserReturned(url:)`, `browserCancelled()`, using `InstanceChecker` and `SessionManager`
- [X] T026 [US1] Wire `Monica/Welcome/WelcomeScreen.swift`: "Log in" calls the view model; the route runs `webAuthenticationSession.authenticate(using:callback: .customScheme("com.monicahq.ios"), preferredBrowserSession: .shared, additionalHeaderFields: [:])` (or the Debug fake browser) when the state asks for it; "Signing in…" progress and error text, announced to VoiceOver with focus moved to the error (accessibility skill), 44 pt targets, Dynamic Type (research R5)
- [X] T027 [US1] Create `Monica/Home/HomeUiState.swift`, `Monica/Home/HomeViewModel.swift`, `Monica/Home/HomeScreen.swift` (heading with the name, instance line), strings in English and French in `Monica/Resources/Localizable.xcstrings`
- [X] T028 [US1] Send `device_name` "<model> · iOS <version>" from `UIDevice` (research R15), computed in `MonicaApp.swift` and injected into `SessionManager`
- [X] T029 [P] [US1] Write `MonicaUITests/WelcomeScreenUITests.swift` cases (`compatible` server): Log in + allow → home with the name; cancel → "cancelled" message; deny → "did not allow" message; accessibility audit on each state; French launch shows French texts
- [X] T030 [P] [US1] Write `MonicaUITests/HomeScreenUITests.swift`: name and instance shown, accessibility audit, relaunch with the same preferences stays on home
- [X] T031 [US1] Write the US1 journey in `MonicaUITests/SignInJourneyUITests.swift`: welcome → Log in → home → relaunch → home

**Checkpoint**: MVP: log in on the default instance works end to end (quickstart §3 rows 3, 4, 7, 8).

---

## Phase 5: User Story 2 - Log in to my self-hosted instance (Priority: P1)

**Goal**: the instance sheet checks an address before saving and explains every refusal.

**Independent Test**: save a compatible address, then each kind of wrong one; log in on the saved one.

- [X] T032 [P] [US2] Extend `MonicaTests/Welcome/WelcomeViewModelTests.swift`: saving shows checking (`data-model.md` `InstanceSheetState.isChecking`), saves only on success, keeps the sheet open with `InstanceSheetState.error` for each `AuthError` of the check (invalid address, HTTPS required, not Monica, too old, app too old, no app sign-in, unreachable, certificate, timeout, moved), previous instance untouched; "Reset to default" checks and restores the official instance
- [X] T033 [US2] Change `Monica/Welcome/WelcomeUiState.swift` (`InstanceSheetState.isChecking`, `InstanceSheetState.error` replacing `isError`, keep `refusals`) and `Monica/Welcome/WelcomeViewModel.swift` `saveInstance()` to normalise with `allowsHTTP` (true only `#if DEBUG`), then check with `InstanceChecker` before `InstanceRepository.setURL` (FR-011)
- [X] T034 [US2] Update `Monica/Welcome/InstanceSheetView.swift`: progress while checking (Save disabled, announced), the error message per case with its next step, announced and focused; English and French strings in `Monica/Resources/Localizable.xcstrings`
- [X] T035 [US2] At launch in Release, a saved `http://` address shows the "HTTPS required" error in the sheet until corrected (research R11), in `Monica/Welcome/WelcomeViewModel.swift`, tested in `MonicaTests/Welcome/WelcomeViewModelTests.swift`
- [X] T036 [US2] "App too old" offers "Update the app" (explains only until the App Store page exists, research R16) in `Monica/Welcome/WelcomeScreen.swift`
- [X] T037 [P] [US2] Update `MonicaUITests/InstanceSheetUITests.swift`: checking state, one test per refusal scenario of `UITestServer`, accepted address saved and kept after relaunch, accessibility audit; adapt the existing test that saved an `http` address
- [X] T038 [US2] Write the US2 journey in `MonicaUITests/SignInJourneyUITests.swift`: sheet → self-hosted address under a path → saved → Log in → home showing that instance

**Checkpoint**: quickstart §3 rows 1 and 2.

---

## Phase 6: User Story 3 - Sign up from the app (Priority: P2)

**Goal**: "Sign up" opens the registration page, or explains that the instance is closed; the email link brings the person back signed in.

**Independent Test**: Sign up on an open instance (direct and through the email link) and on a closed one.

- [X] T039 [P] [US3] Extend `MonicaTests/Welcome/WelcomeViewModelTests.swift`: Sign up with `InstanceDescription.registrationEnabled` false → `registrationClosed`, no browser; true → authorization URL with `prompt=consent create`, `PendingSignIn.isSignUp` true; cancel after Sign up → `awaitingEmail` (pending sign-in kept, `data-model.md` `WelcomeUiState.signIn`)
- [X] T040 [P] [US3] Extend `MonicaTests/Auth/SessionManagerTests.swift`: a callback via `onOpenURL` after a relaunch (new `SessionManager` on the same store) completes the pending sign-in within 1 hour of `PendingSignIn.createdAt`, is refused after it ("sign-in expired"), and a second identical callback is ignored
- [X] T041 [US3] Implement `signUp()` and `registrationClosed` in `Monica/Welcome/WelcomeViewModel.swift` and `Monica/Welcome/WelcomeUiState.swift`; messages in `Monica/Welcome/WelcomeScreen.swift` ("does not accept new accounts, ask its administrator", "the link in the email brings you back"), English and French
- [X] T042 [US3] Add `.onOpenURL` in `Monica/RootView.swift` passing `com.monicahq.ios:/oauth/callback` URLs to `SessionManager.complete(callback:)` and ignoring every other URL (research R6)
- [X] T043 [P] [US3] Write `MonicaUITests/WelcomeScreenUITests.swift` cases: `registrationClosed` server → message, no sheet; Sign up + cancel → email message; accessibility audit
- [X] T044 [US3] Write the US3 journey in `MonicaUITests/SignInJourneyUITests.swift`: Sign up + allow → home

**Checkpoint**: quickstart §3 rows 9 and 10.

---

## Phase 7: User Story 4 - Stay signed in reliably (Priority: P2)

**Goal**: silent renewal, one at a time; offline never signs out; ended sessions return to welcome with a message.

**Independent Test**: unit tests with a fake clock and stub server; UI test with the `renewalRefused` and `notAllowed` scenarios.

- [X] T045 [P] [US4] Extend `MonicaTests/Auth/SessionManagerTests.swift`: renewal before a request when `Session.accessTokenExpiresAt` minus 60 s has passed; 20 concurrent requests → exactly 1 token request (SC-005); `401` from the session origin → one renewal and one retry, never a loop; network error → session kept and "offline" reported; `invalid_grant` → `signedOut(.expired)` when `Session.renewedAt` is more than 30 days old, else `signedOut(.ended)`, Keychain session deleted; `403` → `notAllowed`, no renewal; `5xx` → server error, session kept; renewal result discarded after a generation change; `Session.refreshToken` replaced in one write
- [X] T046 [US4] Implement `accessToken()`, `renew(after:)` with one stored renewal task, and the authenticated request path (attach token, react to `401` once) in `Monica/Auth/SessionManager.swift` and `Monica/Auth/MonicaClient.swift` (research R10, FR-015, FR-016)
- [X] T047 [US4] Show the "session ended" / "session expired" message on the welcome screen after `signedOut(reason)` and the "not allowed" / "can't reach your instance" messages on the home, in `Monica/Welcome/WelcomeViewModel.swift`, `Monica/Home/HomeViewModel.swift` and their screens, English and French, announced to VoiceOver
- [X] T048 [US4] Home refreshes the person from `/api/v1/me` on appear, exercising renewal, in `Monica/Home/HomeViewModel.swift`, tested in `MonicaTests/Home/HomeViewModelTests.swift`
- [X] T049 [P] [US4] Write `MonicaUITests/HomeScreenUITests.swift` cases: `renewalRefused` → back to welcome with "session ended"; `notAllowed` → message on home, still signed in; `unreachable` after sign-in → still signed in with the offline message
- [X] T050 [US4] Write the US4 journey in `MonicaUITests/SignInJourneyUITests.swift`: signed in → access expires (scenario with a 1 s `expires_in`) → home still works

**Checkpoint**: SC-003, SC-004, SC-005 covered by tests.

---

## Phase 8: User Story 5 - Log out and switch instance safely (Priority: P3)

**Goal**: log out of this phone only; switching instance ends the old session and leaks nothing.

**Independent Test**: log out online and offline; switch from A to B with a recording stub and check B received nothing of A's.

- [X] T051 [P] [US5] Extend `MonicaTests/Auth/SessionManagerTests.swift`: logout clears the session at once and calls the revocation endpoint ([contracts/ios-auth.md §6](contracts/ios-auth.md)); network failure stores a `PendingRevocation` retried at the next launch and on foreground, dropped 30 days after `PendingRevocation.createdAt`; switch cancels the pending sign-in, increments the generation, invalidates the old client, revokes A, and the recording stub for B receives no token, code or personal data of A (SC-006), including with a request and a renewal in flight
- [X] T052 [P] [US5] Extend `MonicaTests/Home/HomeViewModelTests.swift`: Log out asks for confirmation (`data-model.md` `HomeUiState.isConfirmingLogout`); saving another instance from the home sheet asks for confirmation (`HomeUiState.confirmSwitchTo`) then checks, switches and returns to welcome; a failed check leaves the session untouched
- [X] T053 [US5] Implement `logOut()`, `switchInstance(to:)` and pending revocation retry in `Monica/Auth/SessionManager.swift`; call the retry at launch and on `scenePhase` becoming active in `Monica/RootView.swift` (research R14, FR-017, FR-018)
- [X] T054 [US5] Add "Log out" with its confirmation, and the instance line opening the instance sheet with the switch confirmation, in `Monica/Home/HomeScreen.swift`, `Monica/Home/HomeViewModel.swift` and `Monica/Home/HomeUiState.swift`, reusing `Monica/Welcome/InstanceSheetView.swift`; English and French strings ("Log out" / "Déconnexion" as in Monica)
- [X] T055 [P] [US5] Write `MonicaUITests/HomeScreenUITests.swift` cases: Log out → confirm → welcome; cancel keeps home; switch instance → confirm → welcome on the new instance; accessibility audit
- [X] T056 [US5] Write the US5 journey in `MonicaUITests/SignInJourneyUITests.swift`: log in → log out → relaunch → welcome

**Checkpoint**: quickstart §3 rows 5, 6 and 11.

---

## Phase 9: Polish & cross-cutting

- [X] T057 [P] Update `docs/architecture.md` (Auth folder, `SessionManager`, Keychain store, Debug UI test server), `docs/testing.md` (`StubURLProtocol`, `MONICA_UI_TEST_SERVER`), `README.md` (running against a local Monica in Debug)
- [X] T058 [P] Amend `.specify/memory/constitution.md` with `/speckit-constitution` (PATCH): the API accepts Sanctum API keys and the mobile apps' OAuth access tokens; keep `CLAUDE.md` consistent
- [X] T059 [P] Mark the superseded rules in `specs/001-welcome-screen/spec.md` (http accepted, instance not contacted) with a pointer to this spec
- [X] T060 Run the `accessibility-reviewer` agent on the changed screens and fix its findings
- [X] T061 Run `LocalizationParityTests` and the whole definition of done: `xcodegen generate && swiftformat . && swiftlint --strict`, unit tests with `scripts/check-coverage.sh` (≥ 80%), then only the UI test classes of this feature (`WelcomeScreenUITests`, `InstanceSheetUITests`, `HomeScreenUITests`, `SignInJourneyUITests`)
- [ ] T062 Run the manual pass of [quickstart.md](quickstart.md) §3 against a local Monica on the phase 2 branch, with VoiceOver and in French; take screenshots with the `take-screenshot` skill for the PR
- [ ] T063 Update `docs/FEATURES.md` with the `feature-documentator` skill, then commit and open the iOS PR per the `commits` skill, stating it depends on the Monica PR of phase 2

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 3** → user stories. **Phase 2** (Monica) runs in parallel with everything; the iOS PR is merged only after it.
- **US1** (P1) needs phase 3 only. **US2** needs US1's welcome sign-in state (T025). **US3** needs US1 (same flow). **US4** needs US1 (a session to renew). **US5** needs US1 (home) and reuses US2's checked sheet (T033, T034).
- Within a story: tests first, failing; then models/state, view model, screen; then UI tests and the journey.

```
Setup ─► Foundational ─► US1 ─┬─► US2 ─► US5
                              ├─► US3
                              └─► US4
Monica (phase 2) ─────────────────────────────► merge before the iOS PR
```

## Parallel examples

- Phase 3: T012, T013, T014, T015, T016 together (separate files); then T017 → T018 → T020.
- US1: T023 and T024 together; T029 and T030 together once T026 and T027 are done.
- After US1: US3 (T039 to T044) and US4 (T045 to T050) can proceed side by side; US2 before US5.
- Phase 2 (Monica) can be done by another person at any time.

## Implementation strategy

1. **MVP**: Setup, Foundational, US1 → log in on the default instance (against a local Monica on the
   phase 2 branch, or the UI test stubs). Stop and validate with quickstart rows 3, 4, 7, 8.
2. US2 (self-hosted) completes the P1 scope.
3. US3 and US4 (P2), then US5 (P3).
4. Polish, then one iOS PR after the Monica PR is merged.
