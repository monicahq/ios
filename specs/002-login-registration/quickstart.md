# Quickstart: validating Log In and Sign Up

## Prerequisites

- `mise install`, Xcode with an iPhone 17 simulator (iOS 26.1).
- `../monica` on branch `2026-11-27-ios-app-sign-in` (phase 0) until it is merged, running locally
  (`composer run dev` or Monica's usual setup), with `APP_URL=http://localhost:8000`, migrations run.
  A Debug build of the app accepts `http://` (research R11).
- A Monica account with two-factor turned on, and one without.

## 1. Server (phase 0), in `../monica`

```sh
php artisan migrate                      # runs the new migration
php artisan migrate:rollback --step=1 && php artisan migrate   # idempotent, same client id
curl -s http://localhost:8000/api/v1/status | jq .mobile     # minimum_ios_version present
php artisan test --filter='Mobile|OAuth|Status|BindOAuthScopes'
```

Expected: the mobile client lists both return addresses; status shows `minimum_ios_version: null`;
all tests pass, including the Android ones.

## 2. App automated checks, in this repo

Follow the `definition-of-done` skill (`xcodegen generate && swiftformat . && swiftlint --strict`,
unit tests with the coverage gate, then only the UI tests of the screens this feature touches:
`-only-testing:MonicaUITests/WelcomeScreenUITests`, `InstanceSheetUITests`, `HomeScreenUITests`,
`SignInJourneyUITests`).

## 3. Manual end-to-end pass (recorded in the PR)

Run the Debug app on the simulator, instance `http://localhost:8000`.

| # | Do | Expect |
|---|----|--------|
| 1 | Instance sheet → `localhost:8000` → Save | "Checking…", then saved |
| 2 | Instance sheet → `example.com` → Save | "not a Monica" message, previous instance kept |
| 3 | Log in → Continue → sign in with 2FA → Allow | consent says "Monica for iOS"; home shows the name |
| 4 | Quit and relaunch | still signed in, no sheet |
| 5 | Web → Settings → Security → Mobile apps | this iPhone listed ("iPhone · iOS 26.1") |
| 6 | Sign it out from the web, then pull the app to foreground and act | back to welcome, "session ended" |
| 7 | Log in → Cancel in the sheet | "Sign-in cancelled", Log in works again |
| 8 | Log in → Deny | "You did not allow access" |
| 9 | Sign up (registration open, email verification on) → create account → close the sheet → open the email link in Safari within 1 h → Allow | app opens signed in |
| 10 | Set `MONICA_REGISTRATION_ENABLED=false`, recheck instance, Sign up | "does not accept new accounts", no sheet |
| 11 | Log out, airplane mode first | welcome at once; after network is back and relaunch, web list no longer shows the phone |
| 12 | VoiceOver on, steps 3 and 7 | progress and errors announced, focus on the error |
| 13 | French app language, step 3 and 7 | texts in French, consent page in French |

With a short token lifetime (`Passport::tokensExpireIn` set to 1 minute locally), use the app across
several minutes: no sign-out, one renewal per expiry in Monica's logs.

## 4. Release build sanity

Archive build (CI "release build") succeeds; entering `http://localhost:8000` in a Release build is
refused with "HTTPS required".
