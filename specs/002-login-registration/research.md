# Research: Log In and Sign Up

Decisions taken while planning. Each one: decision, rationale, alternatives rejected. The server
design and the security decisions shared with Android are in
`../android/specs/002-multi-instance-auth/research.md` (R1 to R16) and are not repeated: only what
differs for iOS, or what iOS has to decide on its own, is here.

## R0. Facts verified in Monica (`../monica`, `main` at `701670286`)

Android-only spots, all to change in phase 0:

| Where | What |
|-------|------|
| `app/Models/MobileSession.php:63` | `REDIRECT_URI = 'com.monicahq.android:/oauth/callback'` (single value) |
| `database/migrations/2026_11_26_000001_provision_the_mobile_oauth_client.php` | client inserted with only the Android return address (`insertOrIgnore`, already run on every instance) |
| `app/Http/Middleware/BindOAuthScopes.php:55-58` | a refused scope is sent back to the app only when `redirect_uri` is the Android one |
| `app/ViewModels/Auth/OAuthAuthorizationViewModel.php:56` | title "Allow Monica for Android to reach your account?" for every mobile sign-in |
| `app/Http/Controllers/Api/StatusController.php:32`, `config/monica.php:336` | `mobile.minimum_android_version` only |
| `resources/docs/api/10-health.php:22,41` | documents `minimum_android_version` only |
| `tests/...` (`MobileClientProvisioningTest`, `MobileSignInTest`, `OAuthAuthorizationViewModelTest`, `StatusControllerTest`, `BindOAuthScopesTest`) | assert the Android values |

Everything else (discovery, `prompt=create`, consent at every sign-in, `/oauth/token` with
`device_name`, `/oauth/revoke`, `mobile_sessions`, the web "Mobile apps" list) is client-agnostic:
it keys on `MobileSession::CLIENT_ID`, never on the return address. Passport checks the
`redirect_uri` against the client's `redirect_uris` list by exact match, so adding a second entry is
enough for the authorization and token endpoints.

## Server (Monica), phase 0

### R1. One mobile client, two return addresses

- **Decision**: keep the single mobile client (`MobileSession::CLIENT_ID`) and add
  `com.monicahq.ios:/oauth/callback` to its `redirect_uris`. `MobileSession` gets
  `ANDROID_REDIRECT_URI`, `IOS_REDIRECT_URI` and `REDIRECT_URIS` (both); `REDIRECT_URI` goes.
  A new migration updates the existing row to both addresses, idempotently (it writes the full list,
  so running it twice changes nothing), without touching the id or any token, so Android sessions
  keep working. The provisioning migration is left as it was (already run everywhere).
- **Rationale**: the status page hands the app one `client_id`, the "Mobile apps" list and the
  scope rules already treat every mobile phone the same way, and Android research R4 chose a fixed
  id for all instances. A second client would mean a second id in the status, in the scope
  middleware and in the web list, for no security gain: the return address already tells the apps
  apart, and PKCE protects each.
- **Alternatives**: a second client for iOS (more server changes, `client_id` per platform in the
  status); reusing `com.monicahq.android:` on iOS (consent would say Android, and the scheme name
  would be wrong for the iOS bundle id).

### R2. The consent page names the platform from the return address

- **Decision**: `OAuthAuthorizationViewModel::title()` returns "Allow Monica for iOS to reach your
  account?" when the request's return address is `IOS_REDIRECT_URI`, and keeps the Android title
  otherwise. The new string is added to `lang/en.json` and every language Monica ships, with the
  French translation written by hand ("Autoriser Monica pour iOS à accéder à votre compte ?",
  matching the existing Android translation's wording). The description, caution and notice texts
  already say "the app on your phone" / "the Monica app" and stay shared.
- **Rationale**: FR-021; the return address is checked by Passport before the page is shown, so it
  is a reliable signal of which app asked.

### R3. `minimum_ios_version` in the status

- **Decision**: `config('monica.mobile.minimum_ios_version')` from `MONICA_MINIMUM_IOS_VERSION`, in
  `.env.example` next to the Android one; the status adds `mobile.minimum_ios_version` (string or
  null), documented in `10-health.php`. The scope-refusal redirect in `BindOAuthScopes` sends back to
  whichever of the two return addresses the request named.
- **Rationale**: FR-022, same shape as Android, so the app's check is the same.

### R4. How the Monica change is delivered

- **Decision**: one pull request on `monicahq/monica`, branch `2026-11-27-ios-app-sign-in`, title
  `feat(auth): sign in from the iOS app`, following Monica's own `definition-of-done`, `migrations`,
  `api-docs-writer`, `changelog` and `pull-requests` skills. No full Spec Kit run in Monica for it:
  it extends the merged `specs/165-mobile-app-sign-in` by one return address, one string and one
  status field; the PR description points to this spec and to
  [contracts/monica-server-ios.md](contracts/monica-server-ios.md). If Monica's rules require a spec
  for every PR, a short one is written there from that contract.
- **Changelog**: a new entry announcing the iOS app sign-in, shown when the iOS app ships (the
  existing Android entry stays as it is).
- **Order**: merged before the iOS pull request. The iOS app is developed in parallel against a local
  Monica on that branch (see quickstart).

## App (iOS)

### R5. Browser: `ASWebAuthenticationSession`, through SwiftUI's `webAuthenticationSession`

- **Decision**: open the authorization URL with SwiftUI's `@Environment(\.webAuthenticationSession)`
  action (AuthenticationServices), callback `.customScheme("com.monicahq.ios")`,
  `prefersEphemeralWebBrowserSession = false` (shares Safari's cookies, FR-001, acceptance US1-3).
  The view calls it and hands the resulting URL (or the cancellation) to the view model, which stays
  free of UI frameworks. The view model asks for the sign-in URL and receives the callback through
  plain methods, so tests drive it without a browser.
- **Rationale**: Apple's recommended, RFC 8252-compliant user agent on iOS: Safari's cookies,
  passkeys and password AutoFill, iOS's own "wants to use … to sign in" prompt, no web view. The
  SwiftUI environment action is the official SwiftUI entry point and needs no presentation anchor.
- **Alternatives**: `SFSafariViewController` (no callback handling, cookies isolated since iOS 11);
  opening Safari with `openURL` (leaves the app, needs the URL scheme for every sign-in, worse
  experience); AppAuth-iOS (third-party package for ~200 lines that must also enforce Monica's
  discovery rules, same reasoning as Android R18); a web view (forbidden by FR-001).

### R6. The email confirmation link: the app's URL scheme and `onOpenURL`

- **Decision**: the app also declares `com.monicahq.ios` in `CFBundleURLTypes`, and the root view
  handles `.onOpenURL`, passing the URL to the same callback handling as the browser sheet. The
  pending sign-in is stored before the sheet opens (R8) and lives 1 hour, so a callback arriving from
  Safari after the app was quit still completes (FR-005, US3-2). When the sheet is cancelled after a
  "Sign up", the welcome screen explains that the email link brings the person back.
- **Rationale**: `ASWebAuthenticationSession` only receives callbacks while its sheet is open; the
  email link is opened later in Safari, which can only reach the app through its registered scheme.
- **Note**: the scheme needs the Info.plist array `CFBundleURLTypes`, which `INFOPLIST_KEY_*` build
  settings cannot express. Two small committed files hold it, merged with the generated keys:
  `Config/Info.plist` (Release) and `Config/Info-Debug.plist` (Debug, which adds the `http`
  exception of R11), chosen per configuration by `INFOPLIST_FILE` in `project.yml`. They sit outside
  `Monica/` so XcodeGen does not copy them as resources.

### R7. HTTP: `URLSession` and `Codable`, no package

- **Decision**: one `MonicaClient` per instance and per session generation, built on its own
  `URLSession(configuration: .ephemeral)` (no shared cookies, no cache, no credential storage), with
  a delegate that refuses every redirect (`willPerformHTTPRedirection` → `nil`, a `3xx` becomes the
  "instance moved" error). It adds `Authorization: Bearer` only to requests whose origin (scheme,
  host, port) equals the session's instance. Requests, timeouts (15 s), JSON decoding with `Codable`.
  Switching instance invalidates the old session (`invalidateAndCancel()`).
- **Testing**: `URLProtocol` subclass registered on the test session's configuration
  (`protocolClasses`), playing a whole Monica in memory, including redirects, timeouts and TLS
  errors as `URLError` codes. No third-party mock server.
- **Found while testing**: `URLSession` raises an exception (a crash) when a task is created after
  it was invalidated. A request still on its way when the session ends must fail instead, so the
  client creates its tasks under a lock that `invalidate()` also takes, and refuses new ones after.
- **Rationale**: Apple's networking stack does everything the rules need; seven endpoints do not
  justify a package (constitution I and II).

### R8. Secure storage: Keychain, one item per secret blob

- **Decision**: three generic-password Keychain items under service `com.monicahq.ios.auth`:
  `session`, `pending-sign-in`, `pending-revocation`, each a JSON value written in one call
  (`SecItemAdd`, or `SecItemUpdate` when it exists, so a renewal replaces the whole value at once),
  accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: never in iCloud or iTunes
  backups, never moved to another iPhone (FR-014), readable after the first unlock so a renewal can
  happen when the app wakes in the background later. A value that cannot be decoded is deleted and
  treated as absent.
- **Keychain outlives the app**: iOS keeps Keychain items after the app is deleted. The app stores
  an "installed" marker in `UserDefaults` (which is deleted with the app); when it is missing at
  launch, the three items are deleted before anything reads them, so a reinstall starts signed out.
- **Testing**: a `SecretStore` protocol with a Keychain implementation and an in-memory fake (needed
  to test the session manager without the Keychain; the Keychain implementation has its own tests,
  which run in the hosted unit test target).
- **Alternatives**: SwiftData or files with Data Protection (secrets belong in the Keychain per the
  constitution); a Keychain wrapper package (three calls do not need one).

### R9. PKCE and state

- **Decision**: 32 random bytes from `SystemRandomNumberGenerator` (cryptographically secure on
  Apple platforms, and it cannot fail, unlike `SecRandomCopyBytes`) for the verifier and the state,
  base64url without padding; challenge = base64url(SHA-256(verifier)) with CryptoKit. Unit tested
  against RFC 7636 appendix B's example.

### R10. Session manager and single-flight renewal

- **Decision**: one `SessionManager`, `@MainActor @Observable`, created in `MonicaApp` and injected.
  It exposes `state` (`signedOut(reason)`, `signedIn(Session)`), a `generation` number incremented at
  every sign-in, sign-out and instance switch, and one stored renewal `Task`:
  - `accessToken()` returns the stored token, or renews first when its expiry (from `expires_in`,
    minus 60 s, measured with an injected clock) has passed.
  - `renew(after staleToken:)`: if the stored token differs from the stale one, return it (someone
    else renewed); if a renewal task is running, await it; otherwise start one. Its result is stored
    only if the generation did not change meanwhile.
  - The client calls `renew` on a `401` from the session's own origin for a request that carried the
    current token, and retries that request once.
  - Outcomes: `URLError` network codes → keep the session, report "offline"; `invalid_grant` → end
    the session locally with reason "expired" (last renewal more than 30 days ago) or "ended";
    `403` → "not allowed"; `5xx` → server error, keep the session.
- **Rationale**: FR-013, FR-015, FR-016 with the main actor as the lock (no actor hopping, the UI
  reads `state` directly), testable with fakes and an injected clock. Same shape as Android R21.
- **Alternatives**: an `actor` (the UI would need a separate observable mirror of its state).

### R11. HTTPS only in Release, `http` in Debug only

- **Decision**: `normalizeInstanceURL(_:allowsHTTP:)` gets a flag, passed `true` only in Debug
  (`#if DEBUG`). The welcome spec's rule that accepted `http` is replaced; its unit and UI tests are
  updated. App Transport Security stays at its default (HTTPS only) in Release; Debug builds add
  `NSAllowsLocalNetworking` and `NSAllowsArbitraryLoads` through a Debug-only Info.plist setting in
  `project.yml`, so a local Monica over `http` can be used in development. A saved `http` address in
  Release is shown as "HTTPS required" at launch and must be corrected (welcome screen shows the
  sheet's error). No custom certificate trust anywhere.

### R12. Error classification

- **Decision**: one `AuthError` enum, mapped from `URLError` codes and answers: `invalidAddress`,
  `httpsRequired`, `unreachable` (`cannotFindHost`, `cannotConnectToHost`, `notConnectedToInternet`,
  `networkConnectionLost`, `dnsLookupFailed`), `timeout` (`timedOut`), `certificate`
  (`serverCertificate*`, `secureConnectionFailed`, `clientCertificate*`), `moved` (3xx), `notMonica`,
  `monicaTooOld`, `appTooOld`, `noAppSignIn`, `registrationClosed`, `cancelled`, `denied`,
  `signInFailed`, `signInExpired`, `sessionExpired`, `sessionEnded`, `notAllowed`, `serverError`.
  Each has one String Catalog key, shared with Android's keys where the text exists; error
  descriptions from the system are never shown or logged (FR-019a, FR-019b).

### R13. Navigation without `NavigationStack` yet

- **Decision**: a root view switches on `SessionManager.state`: `WelcomeRoute` (signed out, with
  sign-in progress and errors) or a placeholder `HomeRoute` (signed in: name, instance, "Log out").
  `NavigationStack` arrives with the first real signed-in screen.

### R14. Deferred revocation

- **Decision**: logout (and switch) clear the session at once, then call the revocation endpoint. If
  it fails for network reasons, the refresh token and the endpoint go to the `pending-revocation`
  Keychain item, retried at the next launch and when the app comes back to the foreground; given up
  after 30 days. Same as Android R26, without BackgroundTasks (best effort is enough: the token dies
  in 30 days anyway).

### R15. Device name

- **Decision**: since iOS 16, `UIDevice.current.name` returns only the model ("iPhone") without a
  special entitlement. The code exchange sends `device_name` = "<model> · iOS <version>" (for example
  "iPhone · iOS 26.1"), so the web list says which kind of device it is and when it signed in.
- **Alternatives**: the user-assigned device name entitlement (Apple grants it only to apps whose
  main purpose needs it); asking the person to name the phone (an extra step for a small gain).

### R16. Version check

- **Decision**: compare `minimum_ios_version` with `CFBundleShortVersionString` numerically,
  component by component (`1.10.0` > `1.9.0`); a value that is not a version is ignored. "Update the
  app" opens the App Store page once the app has one; until then it only explains.

### R17. UI tests without a real Monica or browser

- **Decision**: in Debug builds only, `MONICA_UI_TEST_SERVER=<scenario>` in the launch environment
  makes `MonicaApp` build its `URLSession` with an in-app `URLProtocol` stub playing a Monica
  (`Monica/Debug/FakeMonica.swift`, which the unit tests use too, one fake per test on its own host)
  (compatible, too old, registration closed, sign-in refused, renewal refused…), and replaces the
  browser step with a fake that returns the callback URL the scenario chooses (allow, deny, cancel).
  Release builds do not contain this code (`#if DEBUG`). The UI tests thus exercise the real view
  models, session manager and client. The browser sheet itself (iOS's and Monica's pages) is checked
  in the manual end-to-end pass (quickstart).
- **Rationale**: XCUITest cannot script the authentication sheet reliably, and the constitution
  requires every screen state in UI tests. Same principle as `MONICA_DEFAULTS_SUITE`.
- **Alternatives**: a local Monica in CI (slow, needs PHP and a database in the iOS CI); driving the
  sheet through `springboard` (flaky, depends on iOS's prompt wording).
