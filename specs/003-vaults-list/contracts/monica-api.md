# Contract: Monica API calls used by this feature

Source of truth: `resources/docs/api/05-vaults.php` and `app/Http/Controllers/Api/VaultController.php`
in the Monica repository (checked at `20ebb987d`). Same three calls as the Android feature. No
endpoint is added to Monica.

Every call goes through `SessionManager.authorized` (research R1): bearer token of the session, to
the instance's own origin only, no redirect followed, renewed when expired, retried once after a
401, answers from before a logout or switch discarded.

## GET /api/v1/vaults?page={n}&per_page=100

Answer 200:

```json
{
  "data": [
    {
      "type": "vault",
      "id": "9d4f1c2e-7b3a-4f88-9a2d-6c1e5b0f7a31",
      "attributes": {
        "slug": "dunder-mifflin",
        "name": "Dunder Mifflin",
        "description": "Everybody at the Scranton branch.",
        "colour": "#4f8a49",
        "position": 1,
        "is_default": true,
        "contact_count": 12,
        "shows_people": true, "shows_things": true, "shows_knowledge": false,
        "created_at": 1756252800, "updated_at": 1756339200
      },
      "links": { "self": "…", "web": "…" }
    }
  ],
  "meta": { "page": 1, "per_page": 100, "total": 1 }
}
```

- Read: `id`, `name`, `description`, `colour`, `is_default`, `contact_count`, `meta.total`. Other
  keys are ignored (`Decodable` without them).
- An account with no vault answers `"data": []`, `"total": 0`.
- The app asks page 1, 2, … until it holds `total` vaults or a page is empty (research R3).
- `per_page` above 100 is brought back to 100 by the server, so 100 is asked.

## GET /api/v1/vaults/{id}

Answer 200: `{ "data": <vault object> }`. Answer 404 when the vault was deleted, belongs to someone
else or never existed → `ApiError.notFound`.

## POST /api/v1/vaults

Request (`Content-Type: application/json`, `Accept: application/json`):

```json
{ "name": "Family", "description": "Everybody I am related to.", "colour": "#4f8a49", "is_default": true }
```

`description` is omitted when blank; `is_default` is omitted unless true; `structure_version_id` is
never sent (the account's default contact template is used).

Answer 201: `{ "data": <vault object> }`. The first vault of an account is the default; a new vault
goes at the end of the list.

Answer 422:

```json
{
  "message": "The free plan holds 1 vault, and this account already has it. Full access lifts the ceiling.",
  "errors": { "name": ["The free plan holds 1 vault, and this account already has it. Full access lifts the ceiling."] }
}
```

→ `ApiError.invalid(Refusal(message:, fields: ["name": "…"]))`.

## Status mapping (repository, all calls)

| Status | Result |
|---|---|
| 2xx | decoded value (undecodable body → `failed(.unexpectedAnswer)`) |
| 401 | renewed once and retried by the session manager; second 401 → session ended, `failed(.sessionEnded)` |
| 403 | `failed(.notAllowed)` |
| 404 | `notFound` |
| 422 | `invalid(Refusal)` (undecodable body → `failed(.unexpectedAnswer)`) |
| 3xx | `failed(.moved)` (thrown by `MonicaClient`) |
| other | `failed(.unexpectedAnswer)` |
| network | `failed(.unreachable / .timeout / .certificate)` |
| logout or switch during the call | `failed(.cancelled)`, ignored by view models |

## Test double

`FakeMonica` answers these three endpoints from an in-memory list of vaults (research R14): empty by
default, with settings for the list, a vault ceiling, and overrides for failures and slowness.
