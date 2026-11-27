# Data model: Log In and Sign Up

App-side types. Server entities are unchanged apart from the mobile client's return addresses
([contracts/monica-server-ios.md](contracts/monica-server-ios.md)).

## Instance (existing, extended)

| Field | Type | Notes |
|-------|------|-------|
| `url` | String | Normalised address, the identity used for isolation. `UserDefaults` (`instance_url`, existing). |

Rules: `normalizeInstanceURL(_:allowsHTTP:)` (R11). Two spellings that normalise the same are the
same instance. Changing it while signed in requires confirmation and ends the session.

## InstanceDescription (new, in memory)

What checking an instance learned; rebuilt at each check, never stored.

| Field | Type | From |
|-------|------|------|
| `base` | URL | the normalised address |
| `clientID` | String | status `mobile.client_id` |
| `scope` | String | status `mobile.scope` |
| `registrationEnabled` | Bool | status `mobile.registration_enabled` |
| `minimumIOSVersion` | String? | status `mobile.minimum_ios_version` |
| `authorizationEndpoint`, `tokenEndpoint`, `revocationEndpoint` | URL | authorization server metadata |

Validation: see [contracts/ios-auth.md §2](contracts/ios-auth.md).

## PendingSignIn (new, Keychain `pending-sign-in`)

| Field | Type | Notes |
|-------|------|-------|
| `instance` | String | normalised address it started with |
| `clientID`, `scope` | String | |
| `tokenEndpoint` | URL | where the code may go, and only there |
| `revocationEndpoint` | URL | kept for the session |
| `state` | String | 32 random bytes, base64url |
| `verifier` | String | 32 random bytes, base64url |
| `isSignUp` | Bool | drives the "check your email" message after a cancel |
| `createdAt` | Date | expires after 1 hour |

Lifecycle: created before the sheet opens (replaces any previous one) → used once by a matching
callback (deleted before the code exchange) | expired | deleted on logout or instance change.
Cancelling the sheet does not delete it (the email link may still come).

## Session (new, Keychain `session`)

| Field | Type | Notes |
|-------|------|-------|
| `instance` | String | origin the tokens belong to |
| `clientID`, `scope` | String | for renewal |
| `tokenEndpoint`, `revocationEndpoint` | URL | |
| `accessToken` | String | never logged (custom `description`) |
| `accessTokenExpiresAt` | Date | now + `expires_in` at reception |
| `refreshToken` | String | replaced at every renewal |
| `renewedAt` | Date | to tell "expired after 30 days" from "ended" |
| `name`, `email` | String | from `/api/v1/me`, shown on the home |

At most one. Written in one Keychain call (renewal replaces it whole).

## PendingRevocation (new, Keychain `pending-revocation`)

| Field | Type |
|-------|------|
| `revocationEndpoint` | URL |
| `clientID`, `refreshToken` | String |
| `createdAt` | Date (dropped after 30 days) |

## SessionState (new, in `SessionManager`)

```
signedOut(reason: SignOutReason?)   reason: loggedOut | expired | ended | instanceChanged
signedIn(Session)
```

Transitions: `signedOut → signedIn` (successful exchange + `/me`); `signedIn → signedIn` (renewal);
`signedIn → signedOut(.loggedOut)` (Log out); `→ .expired / .ended` (`invalid_grant` on renewal);
`→ .instanceChanged` (switch confirmed). `generation` increments on every transition except renewal.

## WelcomeUiState (existing, extended)

| Field | Type | Notes |
|-------|------|-------|
| `instanceURL` | String | existing |
| `sheet` | InstanceSheetState? | existing; gains `isChecking` and `error: AuthError?` (replaces `isError`) |
| `signIn` | SignInProgress | `idle`, `checking`, `browsing(URL)`, `signingIn`, `failed(AuthError)`; a closed instance is `failed(.registrationClosed)`, waiting for the email `failed(.signUpUnfinished)` |

## HomeUiState (new)

`name`, `instanceHost`, `isConfirmingLogout`, `sheet: InstanceSheetState?` (the same instance sheet as the
welcome screen), `confirmSwitchTo: String?` (alert "This logs you out of …" before switching),
`message: AuthError?` (not allowed, offline).

## AuthError (new)

The cases listed in research R12, each with one String Catalog key.
