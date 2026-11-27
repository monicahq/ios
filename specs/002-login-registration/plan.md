# Implementation Plan: Log In and Sign Up

**Branch**: `2026-11-27-login-registration` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-login-registration/spec.md`

## Summary

Make "Log in" and "Sign up" work on iOS, on the official instance and on any self-hosted Monica,
through the instance's own web pages in iOS's secure authentication sheet (OAuth 2.0 authorization
code + PKCE, public client), as the Android app does. Two deliveries:

- **Phase 0, Monica** (`../monica`, its own PR, merged first): let the existing mobile client accept
  the iOS return address `com.monicahq.ios:/oauth/callback`, name "Monica for iOS" on the consent
  page, add `minimum_ios_version` to `/api/v1/status`, with API docs, tests and a changelog entry.
  See [contracts/monica-server-ios.md](contracts/monica-server-ios.md).
- **The iOS app**: instance check before saving, `ASWebAuthenticationSession` via SwiftUI's
  `webAuthenticationSession`, return through the app's URL scheme (also for the email confirmation
  link), session in the Keychain owned by one `SessionManager` with single-flight renewal,
  per-instance `URLSession` that never sends tokens elsewhere, logout with deferred revocation, a
  placeholder signed-in home. No new package. See [research.md](research.md).

## Technical Context

**Language/Version**: Swift 6 (language mode 6, complete concurrency checking); PHP 8.4 / Laravel 13 / Passport 13 for phase 0

**Primary Dependencies**: SwiftUI, Observation, AuthenticationServices, CryptoKit, Security (Keychain), Foundation `URLSession`. No Swift package. Monica: Laravel Passport (existing)

**Storage**: Keychain (session, pending sign-in, pending revocation); `UserDefaults` (instance address, existing; "installed" marker)

**Testing**: Swift Testing in `MonicaTests` with fakes and a `URLProtocol` stub; XCUITest in `MonicaUITests` with a Debug-only stubbed server and browser (R17); Monica: PHPUnit feature tests

**Target Platform**: iOS 18+, iPhone

**Project Type**: mobile app + small change to its API server

**Performance Goals**: instance check answers in under 2 s on a normal connection; sign-in from tap to home under 60 s (SC-001), of which the app's own work (exchange + `/me`) under 2 s

**Constraints**: HTTPS only in Release; tokens only to their instance's origin; no redirects followed; 15 s request timeout; offline never signs out; every text in English and French; WCAG 2.2 AA

**Scale/Scope**: 1 changed screen (welcome + instance sheet), 1 new placeholder screen (home), ~7 endpoints, 1 server PR

## Constitution Check

*GATE: checked before Phase 0 research, re-checked after Phase 1 design.*

| Principle | Status | How |
|-----------|--------|-----|
| Product context: API only, missing piece added to Monica first | ✅ | Phase 0 PR in Monica, merged before the app PR. The app uses only public endpoints (`/api/v1/status`, `/api/v1/me`, OAuth endpoints Monica documents). Note: the constitution says "Sanctum bearer tokens"; the API now also accepts OAuth access tokens with the `api` scope, which is how the mobile apps sign in (spec Assumptions). A PATCH amendment of that sentence is proposed in the same PR. |
| I. Simplicity | ✅ | No package. Two protocols only, each needed for tests: `SecretStore` (Keychain cannot be faked otherwise) and a browser seam (the sheet cannot run in unit tests). `URLSession` is tested with `URLProtocol`, not a protocol of our own. No navigation library, no use-case layer. |
| II. Apple practices | ✅ | `@Observable @MainActor` view models with one `state`; stateless `WelcomeScreen` / `HomeScreen`; `SessionManager` as the single source of truth for the session, `InstanceRepository` for the address; dependencies injected from `MonicaApp`; `ASWebAuthenticationSession` (Apple's recommended sign-in UA); Keychain for credentials; no `!` / `try!`. |
| III. Unit tested | ✅ | Tests for PKCE, URL normalisation, instance check, callback validation, token exchange/renewal (incl. concurrent), Keychain store, session manager, revocation, error mapping, every view model state. Coverage gate 80%. |
| IV. UI tested | ✅ | Every new state of the welcome screen, instance sheet and home has an XCUITest, plus one end-to-end journey per user story through the Debug stubs, with the accessibility audit. |
| V. Native only | ✅ | No web view: the sheet is iOS's own authentication session. |
| VI. Multilingual | ✅ | All new strings in `Localizable.xcstrings`, English and French, keys shared with Android where they exist; the consent page in Monica translated. |
| VII. Accessible | ✅ | Progress and errors announced (`AccessibilityNotification.Announcement`), focus moved to errors, Dynamic Type, 44 pt targets, audit in UI tests, VoiceOver pass in the PR. |
| Security standard: credentials only in the Keychain | ✅ | R8, with `ThisDeviceOnly` and reinstall wipe. |

Post-design re-check: ✅ no violation; Complexity Tracking empty.

## Phase 0 — Monica server (`../monica`)

Branch `2026-11-27-ios-app-sign-in` from Monica's `main`, PR `feat(auth): sign in from the iOS app`,
following Monica's `definition-of-done`. Exact changes in
[contracts/monica-server-ios.md](contracts/monica-server-ios.md):

1. `MobileSession`: `ANDROID_REDIRECT_URI`, `IOS_REDIRECT_URI`, `REDIRECT_URIS`; remove `REDIRECT_URI`.
2. Migration `2026_11_27_000000_let_the_ios_app_sign_in.php`: both return addresses on the mobile client.
3. `BindOAuthScopes::refuse()`: redirect to whichever of `REDIRECT_URIS` the request named.
4. `OAuthAuthorizationViewModel::title()`: iOS title from the return address; string in every `lang/*.json`, French translated.
5. `config/monica.php`, `.env.example`, `StatusController`: `minimum_ios_version`.
6. `resources/docs/api/10-health.php`: document the field.
7. Tests: provisioning (twice, Android session unaffected), iOS sign-in end to end, iOS consent title (en, fr), iOS scope refusal, status field; existing tests updated for the constant rename only.
8. Changelog entry for the iOS app sign-in.

The iOS work below does not wait for the merge: it is developed against a local Monica on that branch
(quickstart §1) and its UI tests use stubs. Only the iOS PR's merge waits.

## Phase 1 — iOS design

### Flow

```
Welcome ── Log in / Sign up ──► SignInViewModel.start(isSignUp)
   │                               │ InstanceChecker.check(base) → InstanceDescription
   │                               │ PendingSignIn (state, verifier) → Keychain
   │                               ▼
   │        WelcomeRoute: webAuthenticationSession.authenticate(url, .customScheme("com.monicahq.ios"))
   │                               │ callback URL (or cancel)        ◄── onOpenURL (email link)
   │                               ▼
   │                         SessionManager.complete(callback)
   │                               │ validate state → POST token → GET /me → Keychain session
   ▼                               ▼
RootView switches on SessionManager.state ──► HomeRoute (name, instance, Log out, instance sheet)
```

### Components (new unless noted)

| Type | Role |
|------|------|
| `Instance/Instance.swift` (changed) | `normalizeInstanceURL(_:allowsHTTP:)`, origin comparison |
| `Instance/InstanceChecker.swift` | Reads status + metadata, validates them, returns `InstanceDescription` or `AuthError` |
| `Auth/PKCE.swift` | Random state/verifier, S256 challenge, authorization URL |
| `Auth/PendingSignIn.swift`, `Auth/Session.swift` | Value types of [data-model.md](data-model.md), `Codable`, secrets hidden from `description` |
| `Auth/SecretStore.swift` | Protocol + `KeychainSecretStore` (+ reinstall wipe) |
| `Auth/MonicaClient.swift` | Per-instance `URLSession`: no redirects, bearer only to its origin, JSON decoding, `URLError` → `AuthError` |
| `Auth/SessionManager.swift` | `@MainActor @Observable`: state, generation, start/complete sign-in, single-flight renewal, logout, switch, pending revocation |
| `Auth/AuthError.swift` | Error cases and their String Catalog keys |
| `Auth/AppVersion.swift` | Version comparison for `minimum_ios_version` |
| `Welcome/*` (changed) | "Log in" / "Sign up" wired; sign-in progress and errors; instance sheet checks before saving |
| `Home/HomeViewModel.swift`, `HomeUiState.swift`, `HomeScreen.swift` | Placeholder signed-in home |
| `RootView.swift` | Switches on session state; `onOpenURL` |
| `MonicaApp.swift` (changed) | Builds `SessionManager`, `InstanceChecker`; Debug-only UI test stubs |
| `Debug/UITestServer.swift` | `#if DEBUG` `URLProtocol` scenarios + fake browser (R17) |
| `project.yml` (changed) | `info:` with `CFBundleURLTypes`; Debug-only ATS exception |

### Changes to existing behaviour

- Welcome spec FR-015 / edge case: `http://` accepted → now Release refuses it (FR-019). Unit tests of
  `normalizeInstanceURL` and the instance sheet UI test using an `http` address are updated.
- Saving an instance now contacts it (welcome spec Assumption "the app does not contact the instance
  when saving it" is superseded).
- `docs/architecture.md`: Keychain, session manager and the Debug UI test server documented;
  `docs/testing.md`: `MONICA_UI_TEST_SERVER`; `README.md`: running against a local Monica;
  `docs/FEATURES.md` via the `feature-documentator` skill.

## Project Structure

### Documentation (this feature)

```text
specs/002-login-registration/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── monica-server-ios.md   # phase 0, Monica
│   └── ios-auth.md            # what the app sends and accepts
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks
```

### Source Code (repository root)

```text
Monica/
├── MonicaApp.swift            # changed: builds SessionManager, InstanceChecker
├── RootView.swift             # new
├── Instance/
│   ├── Instance.swift         # changed: allowsHTTP, origin
│   ├── InstanceRepository.swift
│   └── InstanceChecker.swift  # new
├── Auth/                      # new
│   ├── AuthError.swift
│   ├── AppVersion.swift
│   ├── PKCE.swift
│   ├── PendingSignIn.swift
│   ├── Session.swift
│   ├── SecretStore.swift
│   ├── MonicaClient.swift
│   └── SessionManager.swift
├── Welcome/                   # changed
├── Home/                      # new: HomeViewModel, HomeUiState, HomeScreen
├── Debug/UITestServer.swift   # new, #if DEBUG
└── Resources/Localizable.xcstrings

MonicaTests/
├── Instance/                  # + InstanceCheckerTests
├── Auth/                      # PKCE, SecretStore, MonicaClient, SessionManager, AppVersion, AuthError
├── Welcome/                   # WelcomeViewModel sign-in states
├── Home/                      # HomeViewModel
└── Support/                   # StubURLProtocol, FakeSecretStore, FakeClock

MonicaUITests/
├── WelcomeScreenUITests.swift # + sign-in states, registration closed
├── InstanceSheetUITests.swift # + checking, each refusal
├── HomeScreenUITests.swift    # new
└── SignInJourneyUITests.swift # new: one journey per user story
```

**Structure Decision**: one app target as today, organised by feature (`Auth/`, `Home/`), following
`docs/architecture.md`. The server change lives in `../monica`, not in this repository.

## Complexity Tracking

None.
