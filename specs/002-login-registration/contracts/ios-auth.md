# Contract: what the iOS app sends and accepts

The app's external interfaces for this feature: what it asks of an instance, and the address iOS
opens it through. Endpoint shapes are those of
[monica-server-ios.md](monica-server-ios.md) and the Android server contract.

## 1. Return address

- Scheme `com.monicahq.ios`, declared in `CFBundleURLTypes`; full address
  `com.monicahq.ios:/oauth/callback`.
- Received from the browser sheet (`webAuthenticationSession`) or from iOS (`onOpenURL`).
- Accepted forms: `?code=<code>&state=<state>` and `?error=<error>&state=<state>`
  (`access_denied` → "You did not allow access"; anything else → "Sign-in failed").
- Accepted only if: a pending sign-in exists, is less than 1 hour old, its state equals `state`
  exactly, it was not used, and its instance is the current one. Otherwise: ignored, nothing sent.
  When a pending sign-in exists and the state does not match, it shows "Sign-in failed".
- Any other path on the scheme is ignored.

## 2. Checking an instance (in order)

1. `GET {base}/api/v1/status` → requires `status == "ok"` and a `mobile` object with
   `api_version >= 1` and a `minimum_ios_version` member (null allowed); else "not Monica" (no or
   invalid JSON) or "Monica too old". `minimum_ios_version` greater than the app version → "app too
   old".
2. `GET {base}/.well-known/oauth-authorization-server` → requires `issuer == base`, `S256` in
   `code_challenge_methods_supported`, and `authorization_endpoint`, `token_endpoint`,
   `revocation_endpoint` on the same origin as `base` and under its path; else "no app sign-in".

No redirect is followed (a `3xx` → "instance moved"). Timeout 15 s per request.

## 3. Authorization request (opened in the browser sheet)

```
{authorization_endpoint}?response_type=code&client_id={client_id}
  &redirect_uri=com.monicahq.ios:/oauth/callback&scope={scope}&state={state}
  &code_challenge={challenge}&code_challenge_method=S256&prompt=consent        (Log in)
  &prompt=consent%20create                                                    (Sign up)
```

"Sign up" is not offered when `registration_enabled` is false ("registration closed" message).

## 4. Token requests (`application/x-www-form-urlencoded`, no `Authorization` header)

- Exchange: `grant_type=authorization_code&client_id&redirect_uri&code&code_verifier&device_name`
- Renewal: `grant_type=refresh_token&client_id&refresh_token&scope`
- `200` → `access_token`, `refresh_token`, `expires_in`. `400`/`401` with `invalid_grant` → session
  over (renewal) or "sign-in failed" (exchange).

## 5. After sign-in

`GET {base}/api/v1/me` with `Authorization: Bearer {access_token}` → the person's name and email for
the session; failure here ends the attempt with the matching error and stores nothing.

## 6. Logout

`POST {revocation_endpoint}` with `token={refresh_token}&token_type_hint=refresh_token&client_id`.
`200` → done. Network failure → kept as pending revocation, retried at launch and on return to the
foreground, dropped after 30 days.

## 7. Never

- Never send `Authorization` to another origin than the session's instance, nor after a redirect.
- Never call `POST /api/v1/login`, `POST /api/v1/register`, or any MCP route.
- Never log or display tokens, codes, verifiers or states.
