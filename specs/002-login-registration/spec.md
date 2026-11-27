# Feature Specification: Log In and Sign Up

**Feature Branch**: `2026-11-27-login-registration`

**Created**: 2026-11-27

**Status**: Draft

**Input**: User description: "je veux que tu regardes le repo android et que tu fasses marcher le
login et la registration pour ios. normalement on a tout ce qu'il faut coté app web." (Look at the
Android app and make log in and sign up work on iOS; the web app should already have everything
needed.)

**Builds on**: `specs/001-welcome-screen` (merged): the welcome screen, its "Sign up" and "Log in"
buttons, which do nothing yet, and the instance sheet.

**Reference**: the Android app shipped the same feature as `../android/specs/002-multi-instance-auth`
(merged as monicahq/android#6). Its server half was merged in Monica as monicahq/monica#8053
(`specs/165-mobile-app-sign-in` there). This spec follows the same flow, adapted to iOS, and does not
repeat the server design.

## What the server already provides, and what it lacks for iOS

Every Monica instance now lets a mobile app sign people in through the instance's own web sign-in
page, with no manual setup by its administrator: a status page that says whether the instance
supports app sign-in and whether it accepts new accounts, a standard description of its sign-in
addresses, a consent page, short-lived renewable access, logout of one phone only, and a "Mobile
apps" list in the web security settings where each phone can be signed out.

Three things in it are Android-only today, and block iOS:

1. The instance accepts only the Android app's return address; the iOS app's is refused.
2. The consent page always says "Allow Monica for Android to reach your account?".
3. The instance can tell the app it is too old only for Android (`minimum_android_version`).

Following the constitution (a missing piece of the API is added to Monica first), these are added to
Monica before the app ships (FR-020 to FR-023). Everything else is reused as is.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log in to the official Monica instance (Priority: P1)

A person who has an account on the official Monica instance opens the app and taps "Log in". A
secure browser sheet provided by iOS opens Monica's own sign-in page, where they sign in the way they
always do (password, two-factor code, security key, passkey, single sign-on), then allow the app to
reach their account. The sheet closes, and the app shows that they are signed in, and as whom. They
never type their password into the app itself.

**Why this priority**: Without signing in, the app can do nothing. The official instance is the
default and serves most people.

**Independent Test**: With a test account on the default instance, tap "Log in", complete sign-in in
the sheet (with and without two-factor), check the app shows the person's name, then quit and reopen
the app and check they are still signed in.

**Acceptance Scenarios**:

1. **Given** the welcome screen with the default instance, **When** the person taps "Log in",
   **Then** iOS asks whether the app may use "app.monicahq.com" to sign in, and on "Continue" a
   browser sheet opens the sign-in page of `app.monicahq.com`.
2. **Given** the person signs in, including a two-factor step if their account has one, and taps
   "Allow" on the consent page, **When** Monica sends them back, **Then** the sheet closes, the app
   shows a short "Signing in…" state, then the signed-in home with the person's name and the instance.
3. **Given** the person is already signed in on Monica in Safari, **When** they tap "Log in",
   **Then** they only confirm on the consent page and come back signed in.
4. **Given** the sheet is open, **When** the person taps "Cancel" in it, or "Cancel" on the iOS
   prompt before it, **Then** the welcome screen comes back with a message saying sign-in was
   cancelled, and "Log in" works again.
5. **Given** the person taps "Deny" on the consent page, **When** they come back, **Then** the
   welcome screen says they did not allow access.
6. **Given** the person is signed in, **When** the app is quit, the phone restarted and the app
   reopened, **Then** they are still signed in, without seeing the sheet.

---

### User Story 2 - Log in to my self-hosted instance (Priority: P1)

A person who runs their own Monica opens the instance sheet and types their server's address. Before
saving, the app checks it and says whether it is a Monica the app can work with. "Log in" then works
exactly as on the official instance, against their own server, with nothing to set up on the server.

**Why this priority**: Monica is open source and self-hostable; an app that only works with the
official instance leaves out a core part of its community.

**Independent Test**: Run a fresh Monica that includes the iOS additions, enter its address, check it
is accepted and that signing in works; enter a few wrong addresses and check each message.

**Acceptance Scenarios**:

1. **Given** the instance sheet is open, **When** the person enters `monica.example.com` and saves,
   **Then** the app shows it is checking the instance, and saves the address only once the instance
   answered as a compatible Monica.
2. **Given** the address is not a Monica, a Monica too old for the app, unreachable, has an invalid
   certificate or does not answer in time, **When** the person saves, **Then** the sheet stays open
   with a message saying which of these it is and what to do, and the saved instance, and any
   session on it, stay untouched.
3. **Given** a Monica served under a path (`https://example.com/monica`), **When** the person enters
   that address, **Then** checking and signing in work the same way.
4. **Given** a self-hosted instance is saved, **When** the person chooses "Reset to default" and
   saves, **Then** the official instance is checked and restored.
5. **Given** the instance requires a newer version of the app, **When** the person saves it or taps
   "Log in", **Then** the app says the app must be updated, with a way to open the App Store.

---

### User Story 3 - Sign up from the app (Priority: P2)

A person without an account taps "Sign up". If the instance accepts new accounts, the browser sheet
opens Monica's own registration page, and once the account is created they come back to the app
signed in. If it does not accept new accounts, the app says so instead of opening a page that would
fail.

**Why this priority**: People arrive through the App Store and need a way to create an account. It
reuses the whole log in flow, so it comes after it.

**Independent Test**: Tap "Sign up" on an instance with registration open (with and without email
confirmation required) and on one with registration closed.

**Acceptance Scenarios**:

1. **Given** registration is open, **When** the person taps "Sign up", **Then** the browser sheet
   opens the registration page of that instance, and after creating their account and allowing
   access they come back to the app signed in.
2. **Given** the instance asks new accounts to confirm their email, **When** the person closes the
   sheet to go read the email, **Then** the welcome screen explains that the link in the email will
   bring them back to the app signed in; **When** they open that link (in Safari, from Mail) within
   an hour and allow access, **Then** the app opens and finishes signing them in.
3. **Given** registration is closed on the instance, **When** the person taps "Sign up", **Then** the
   app explains that this instance does not accept new accounts and to ask its administrator, and
   does not open the browser.

---

### User Story 4 - Stay signed in reliably (Priority: P2)

Once signed in, the person stays signed in for as long as they use the app regularly. Short-lived
access is renewed silently. Losing the network or a server hiccup never signs them out. They are
signed out only when their session really ended: they logged out, it was signed out from the web, or
they did not use the app for 30 days.

**Why this priority**: Being asked to sign in again for no reason, or signed out by a bad network, is
one of the most frequent complaints about mobile apps.

**Independent Test**: Against a test instance with very short access lifetimes, use the app across
several expirations, with several requests at once, offline periods and a session signed out from the
web.

**Acceptance Scenarios**:

1. **Given** the person's access has expired, **When** the app talks to the instance, **Then** access
   is renewed once and the person notices nothing.
2. **Given** several requests find access expired at the same moment, **When** they are handled,
   **Then** exactly one renewal happens and each request is retried at most once.
3. **Given** the phone is offline or the instance unreachable when access must be renewed, **When**
   the app tries, **Then** the person stays signed in, sees that the instance cannot be reached, and
   renewal is tried again later.
4. **Given** the session was signed out from the web or expired, **When** the app next talks to the
   instance, **Then** the person is taken back to the welcome screen with a message saying their
   session ended and they need to log in again, and nothing from the session stays visible.
5. **Given** the instance refuses an action because the person is not allowed to do it, **When** the
   app receives that answer, **Then** it says so and does not renew access or sign the person out.

---

### User Story 5 - Log out and switch instance safely (Priority: P3)

The person can log out. They can also switch to another instance, which logs them out of the first
one. Nothing from one instance (access, personal data, requests in flight) ever reaches another.

**Why this priority**: Logging out is a basic right, and isolating instances is a security
requirement, since the instances a person uses can be run by different people.

**Independent Test**: Sign in on instance A, switch to instance B, and check with a recording test
server that B received nothing belonging to A and that A's session was ended.

**Acceptance Scenarios**:

1. **Given** the person is signed in, **When** they tap "Log out" and confirm, **Then** the app tells
   the instance to end this phone's session (other phones, assistants and API keys stay signed in),
   forgets the session on the phone and shows the welcome screen.
2. **Given** the person is offline when they log out, **When** they confirm, **Then** the session is
   forgotten on the phone right away, and the app tells the instance the next time it can reach it.
3. **Given** the person is signed in on instance A, **When** they save a different instance, **Then**
   they are warned that this logs them out of A, and after confirming, A's session is ended and
   forgotten, A's data is removed from the phone, and the app asks them to log in to B.
4. **Given** a request or a renewal for A is still running when the person switches to B, **When** it
   finishes, **Then** its result is thrown away and nothing about A is sent to B or kept.
5. **Given** the person logs out or switches instance, **When** they look at the "Mobile apps" list
   in the web security settings of A, **Then** this phone is no longer listed.

---

### Edge Cases

- The person taps "Log in" twice quickly: only one sheet opens and only one sign-in happens.
- The app is opened through its return address with no sign-in in progress, with an answer that does
  not match the sign-in in progress, with an answer already used, or after the instance changed: the
  answer is ignored, nothing is sent anywhere, and a pending sign-in shows "Sign-in failed".
- The person takes more than one hour between starting and finishing: the pending sign-in has
  expired, and they are asked to start again.
- The instance answers with an error page, maintenance mode or something that is not Monica: "We
  could not understand your instance's answer, try again later", never the raw error.
- The address typed has a trailing slash, uppercase letters, a port, a path or spaces around it: it is
  normalised as in the welcome screen spec, and two spellings of the same instance are one instance.
- The instance redirects the app's requests to another address: the app does not follow with
  credentials; if the instance moved for good, the person is told to update the address.
- The instance describes sign-in addresses on another origin than its own: it is refused as not
  supporting app sign-in.
- An `http://` address in the App Store build: refused, explaining that the instance must use HTTPS.
  An `http://` address saved by the current version of the app is treated the same way at the next
  launch: the person is asked to correct it. This replaces the welcome screen rule that accepted
  `http://` (its FR-015 and edge cases).
- The phone's clock is wrong: sessions still work, since expiry follows the instance's answers.
- The app is restored from a backup or moved to a new iPhone: the instance address may come along,
  the session never does; the person logs in again.
- The person changes the app's language while the sheet is open: the sheet keeps the web page's own
  language; the app's texts follow the new language when it comes back.
- VoiceOver users: the sheet is iOS's own and is read like Safari; the app announces "Signing in…"
  and any error when it comes back.

## Requirements *(mandatory)*

### Functional Requirements

**Signing in (app)**

- **FR-001**: The app MUST sign people in only through the instance's own web sign-in page, shown in
  the secure browser sheet provided by iOS for signing in. It MUST NOT show that page in a web view
  of its own, ask for a password, or store one. The sheet MUST share Safari's cookies, so a person
  already signed in on the web only confirms.
- **FR-002**: Sign-in MUST use the OAuth 2.0 authorization code flow for public clients with PKCE
  (S256 only), following RFC 7636, RFC 8252 and RFC 9700. The app MUST NOT hold a client secret or
  use the password or implicit grants. It MUST NOT use the API's email and password endpoints
  (`POST /api/v1/login`, `POST /api/v1/register`), which stay for other integrations.
- **FR-003**: Each attempt MUST use a new random verifier and state from a cryptographically secure
  source, bound to the instance, the client identifier and the return address it started with.
- **FR-004**: The app MUST return from the browser through the private address
  `com.monicahq.ios:/oauth/callback`, which works on every instance without an outside party. An
  answer MUST be accepted only if a sign-in is in progress, its state matches exactly, it has not
  been used, and it belongs to the current instance; anything else is rejected without contacting
  any server.
- **FR-005**: An answer MUST be accepted both when the browser sheet hands it back and when iOS opens
  the app through the return address (an email confirmation link opened later in Safari). The pending
  sign-in MUST survive the app being quit for up to 1 hour, and MUST be cleared once used, expired,
  replaced, on logout or when the instance changes.
- **FR-006**: "Log in" MUST open the instance's sign-in page and "Sign up" its registration page,
  both asking for consent at every sign-in.
- **FR-007**: After receiving access, the app MUST load the signed-in person's profile through the
  API, and only then show the signed-in home (the person's name, the instance, and "Log out"). The
  device name sent to the instance MUST let the person recognise this iPhone in the "Mobile apps"
  list on the web.
- **FR-008**: The app MUST request only access to the Monica API, never to the MCP server.

**Checking an instance**

- **FR-009**: Before saving a new address, the app MUST check the instance and learn from it its
  identity, that it supports app sign-in, the client identifier, the scope to request, its sign-in,
  token and session-ending addresses, whether it accepts new accounts, and the oldest iOS app version
  it supports. Addresses MUST come from what the instance describes, not be built from fixed paths,
  except the two documents that describe it.
- **FR-010**: The app MUST refuse, with a message naming the reason in plain words, an instance whose
  described addresses are not on its own origin, whose identity is not its own address, that does
  not support S256, or that does not describe app sign-in.
- **FR-011**: The address being checked MUST NOT replace the saved one, nor affect the current
  session, until the check succeeded and, when signed in, the person confirmed switching.
- **FR-012**: The official instance `https://app.monicahq.com` MUST stay the default and be
  restorable from the sheet. Whether it accepts new accounts is checked like any other instance.

**Session**

- **FR-013**: One session manager MUST own the session: it stores, renews and ends it, and tells the
  rest of the app whether the person is signed in. No other part of the app reads tokens.
- **FR-014**: Tokens MUST be stored in the device's secure storage, readable only by this app on this
  device, and never included in backups or moved to another device.
- **FR-015**: When several requests find access expired at the same time, exactly one renewal MUST
  run; the others wait and are retried once. Renewal MUST NOT loop.
- **FR-016**: The app MUST handle differently: no network or timeout (keep the session, retry later),
  expired access (renew), renewal refused (end the session locally and say the session ended), not
  allowed (say so, keep the session), and server errors (generic message, keep the session). Only a
  "not authenticated" answer from the instance the session belongs to may trigger a renewal.
- **FR-017**: Tokens MUST only ever be sent to the origin of the instance that issued them, over
  HTTPS, and never after a redirect to another origin. Switching instance MUST cancel a pending
  sign-in, stop requests and renewals for the previous instance, end its session when reachable, and
  remove its session and data from the phone.
- **FR-018**: Logging out MUST end the session on the instance using the session-ending address
  (which works even when access has expired), forget it on the phone at once, and retry telling the
  instance later when it could not be reached.

**Security and errors**

- **FR-019**: The App Store build MUST only talk to instances over HTTPS with normal certificate
  checks and refuse `http://` addresses. Only development builds MAY allow `http://` for local test
  servers. Addresses with another scheme, credentials, no host or malformed MUST be refused.
- **FR-019a**: Tokens, codes, verifiers and states MUST never appear in logs, error messages or
  analytics.
- **FR-019b**: The app MUST show a clear message, with a next step, for each of: invalid address,
  HTTPS required, unreachable instance, invalid certificate, timeout, Monica too old, app too old,
  instance without app sign-in, registration closed, sign-in cancelled, access denied, sign-in
  failed, sign-in expired, session ended, not allowed, unexpected answer. No raw or technical text.
- **FR-019c**: Every new text MUST exist in English and French and reuse the web app's and the
  Android app's wording where it exists ("Log in", "Sign up", "Log out", "instance"). Every new state
  MUST meet the constitution's accessibility rules: progress and errors announced by VoiceOver, focus
  moved to errors, Dynamic Type, touch targets.

**Server additions (monicahq/monica, delivered before the app)**

- **FR-020**: The mobile client on every instance MUST accept `com.monicahq.ios:/oauth/callback` as a
  return address, in addition to the Android one, added automatically on install and upgrade without
  ending existing sessions and without a manual step.
- **FR-021**: The consent page MUST name the app the person is signing in from: "Monica for iOS" when
  the return address is the iOS one, "Monica for Android" for the Android one, in the person's
  language.
- **FR-022**: The status page MUST also give the oldest iOS app version the instance supports (or
  none), set by the administrator like the Android one.
- **FR-023**: Monica's API documentation, its tests and its changelog entry MUST cover the iOS app;
  the Android app and assistants MUST keep working unchanged.

### Key Entities

- **Instance**: the Monica server the person chose: its normalised address (the identity used for
  isolation) and what the check learned about it. Exactly one is current.
- **Pending sign-in**: one attempt in progress (instance, client identifier, return address, state,
  verifier, whether it is a log in or a sign up, start time). Lives at most 1 hour; used once.
- **Session**: the signed-in state on this phone: the instance that issued it, access and its expiry,
  renewal token, the signed-in person's name and email. At most one.
- **Mobile session** (server, existing): what the instance knows of this phone's sign-in, listed in
  "Mobile apps" in the web security settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person with an account goes from tapping "Log in" to the signed-in home in under 60
  seconds (excluding reading a two-factor code), on the official and on a self-hosted instance.
- **SC-002**: A person without an account goes from tapping "Sign up" to the signed-in home in under
  3 minutes when no email confirmation is required.
- **SC-003**: Over 30 days of daily use, a person is never asked to log in again unless they logged
  out, were signed out from the web, or did not open the app for 30 days.
- **SC-004**: A network loss of any length never signs a person out.
- **SC-005**: With 20 requests finding access expired at once, exactly 1 renewal reaches the instance.
- **SC-006**: In automated tests, a recording server for instance B receives no credentials, codes or
  personal data from instance A, including during a switch with requests in flight.
- **SC-007**: Every error listed in FR-019b shows a message in the person's language, with no raw
  technical text, in 100% of the tested cases.
- **SC-008**: A fresh and an upgraded Monica accept iOS sign-in with zero manual steps, and the
  Android app and assistants keep signing in unchanged.

## Testing scope

Unit tests with fakes: address normalisation and HTTPS rule, instance check (compatible, too old,
app too old, no app sign-in, other origin, unreachable, certificate, timeout, unexpected answer),
pending sign-in (state match, reuse, expiry, survives restart, cleared on switch), code exchange,
renewal including concurrent renewal, refused renewal, logout online and offline, instance switch
with work in flight, no token sent to another origin, every view model state. UI tests: welcome
screen states (signing in, each error, registration closed), instance sheet checking and errors,
signed-in home and log out, with the browser sheet replaced by a fake in UI tests since its content
belongs to iOS and the server. One manual end-to-end pass per user story against a real instance,
recorded in the pull request. Monica: feature tests for FR-020 to FR-023.

## Assumptions

- The flow, the server contract and the security decisions are those of the Android app (`../android`
  spec 002, `contracts/monica-server.md`), already reviewed; only iOS differences are decided here.
- One instance and one signed-in person at a time. Several accounts side by side are out of scope.
- The return address is a private address scheme rather than a universal link, for the same reason
  as on Android: a universal link would need every self-hosted instance to vouch for a monicahq.com
  domain. The risk of another app claiming the same scheme is covered by PKCE and the consent page.
- The API accepts these OAuth access tokens next to Sanctum API keys; the constitution's mention of
  Sanctum tokens describes API keys and does not forbid this.
- "Log out" lives on a placeholder signed-in home for now; the real signed-in app (vaults, contacts)
  comes in later features, as on Android.
- The web list of phone sessions already exists on the server and needs no work here.
- The server additions (FR-020 to FR-023) are a small pull request on monicahq/monica, made and merged
  before the iOS pull request; until then, the iOS app can only be tested against a local Monica
  carrying that change.
