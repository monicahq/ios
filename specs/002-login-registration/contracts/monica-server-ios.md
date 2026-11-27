# Contract: what Monica changes for the iOS app (phase 0)

Delta on top of the contract the Android app relies on
(`../android/specs/002-multi-instance-auth/contracts/monica-server.md`, merged as monicahq/monica#8053).
Everything not listed here is unchanged and used by iOS exactly as by Android. `{base}` is the
instance's `APP_URL`, which may include a path.

## 1. Mobile client: a second return address

- `MobileSession::ANDROID_REDIRECT_URI = 'com.monicahq.android:/oauth/callback'`
- `MobileSession::IOS_REDIRECT_URI = 'com.monicahq.ios:/oauth/callback'`
- `MobileSession::REDIRECT_URIS = [ANDROID_REDIRECT_URI, IOS_REDIRECT_URI]`; `REDIRECT_URI` is removed
  and its uses move to `ANDROID_REDIRECT_URI` (tests) or `REDIRECT_URIS` (code).
- New migration `2026_11_27_000000_let_the_ios_app_sign_in.php`: updates the `oauth_clients` row
  whose id is the mobile client's to `redirect_uris = ["com.monicahq.android:/oauth/callback",
  "com.monicahq.ios:/oauth/callback"]` and `updated_at = now()`. Values written out (not read from the
  model). Idempotent; no other column touched; no token or `mobile_sessions` row touched. `down()`
  restores the Android-only list.
- Effect: `GET {base}/oauth/authorize` and `POST {base}/oauth/token` accept
  `redirect_uri=com.monicahq.ios:/oauth/callback` for `client_id=<mobile client>`, by Passport's
  exact match. Any other value is still refused.

## 2. `BindOAuthScopes`: refusals sent back to the right app

When a mobile request with a refused scope names one of `REDIRECT_URIS`, the redirect goes to that
same address: `com.monicahq.ios:/oauth/callback?error=invalid_scope&state=…` for iOS. Otherwise the
JSON `400` answer is unchanged.

## 3. Consent page title

`OAuthAuthorizationViewModel::title()` for the mobile client:

| `redirect_uri` | English | French |
|----------------|---------|--------|
| `com.monicahq.ios:/oauth/callback` | Allow Monica for iOS to reach your account? | Autoriser Monica pour iOS à accéder à votre compte ? (narrow no-break space before "?", as Monica's French requires) |
| anything else (Android) | Allow Monica for Android to reach your account? (unchanged) | unchanged |

The new key is added to every `lang/*.json` (English value where no translation is written, as
Monica's `add-locale` rules say). Description, caution, notice and permissions are unchanged.

## 4. `GET {base}/api/v1/status`

```json
{
  "status": "ok",
  "version": "5.3.0",
  "instance": "monica.example.com",
  "mobile": {
    "api_version": 1,
    "client_id": "0198f6a4-7c2e-7d3b-9a61-5e0b4c8d2f17",
    "scope": "api",
    "registration_enabled": true,
    "minimum_android_version": null,
    "minimum_ios_version": null
  }
}
```

- `minimum_ios_version`: semantic version string or null, from `config('monica.mobile.minimum_ios_version')`
  (`MONICA_MINIMUM_IOS_VERSION`, empty by default, added to `.env.example`). Empty string → null.
- `api_version` stays `1`: the iOS app treats a missing `minimum_ios_version` (an instance with
  #8053 but not this change) as "Monica too old", since the iOS return address is refused there.
- Documented in `resources/docs/api/10-health.php` (field list and example).

## 5. Tests (Monica feature and unit tests)

- Provisioning: after migrations, the mobile client has both return addresses; running the new
  migration twice leaves the same list and the same id; an existing Android session still renews.
- Sign-in with the iOS return address: consent page shows the iOS title (English and French);
  "Allow" redirects to `com.monicahq.ios:/oauth/callback?code=…&state=…`; the code exchanges with
  the same `redirect_uri` and creates a `mobile_sessions` row with the given `device_name`; exchanging
  it with the Android address is refused (`400 invalid_request`: Passport's own check of the return
  address, left as it is), and creates no `mobile_sessions` row.
- Refused scope from iOS redirects to the iOS address.
- Status includes `minimum_ios_version` (null by default, the configured value otherwise).
- Every existing Android, MCP and API key test passes unchanged (apart from the constant rename).

## 6. Changelog and docs

- A changelog entry for the iOS app sign-in (same tone as the Android one), following Monica's
  `changelog` skill.
- `docs/` or `README` mention of `MONICA_MINIMUM_ANDROID_VERSION`, if any, gets the iOS twin.
