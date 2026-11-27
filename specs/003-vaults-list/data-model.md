# Data Model: Vault List

Nothing is stored on the phone (FR-024): every type here lives in memory while a screen shows it.
Server fields come from `GET /api/v1/vaults` (see [contracts/monica-api.md](contracts/monica-api.md)).

## Vault (`Data/Vaults/Vault.swift`)

| Field | Type | From | Rule |
|---|---|---|---|
| `id` | `String` | `id` | stable reference; the slug is never stored (it changes on rename) |
| `name` | `String` | `attributes.name` | up to 255 characters, plain text |
| `description` | `String?` | `attributes.description` | nil or empty means none; shown only when not blank |
| `colour` | `VaultColour` | `attributes.colour` | parsed case-insensitively; unknown → `.graphite` |
| `isDefault` | `Bool` | `attributes.is_default` | at most one true in a list |
| `contactCount` | `Int` | `attributes.contact_count` | ≥ 0 |

`Identifiable`, `Equatable`, `Hashable`, `Sendable`. Decoded from the JSON:API resource; every other
attribute is ignored. `position` is not kept: the list keeps the order the instance answers in.

Derived: `initial` = `vaultInitial(name)` (research R12).

## VaultColour (`Data/Vaults/Vault.swift`)

`enum VaultColour: String, CaseIterable` in the server's order, raw value = the server hex:
`blue #3f5fd0`, `green #4f8a49`, `ochre #9a6a24`, `rust #9a3f2b`, `violet #6b4fa8`,
`teal #2f7f86`, `rose #a8447a`, `graphite #4a4a52`. `CaseIterable` gives the form's order; `.blue`
is the default. Its spoken name (`colour_blue` …) and its two colour sets (research R6) are mapped
in `Theme/VaultColours.swift`.

## NewVault (`Data/Vaults/Vault.swift`)

What the form sends: `name` (trimmed, not blank), `description` (nil when blank), `colour`,
`makeDefault`. Encoded as `{"name", "description"?, "colour", "is_default"?: true}`.

## ApiError and Refusal (`Data/ApiError.swift`)

See research R2. `Refusal.fields` keeps the first message of each field of a 422
(`errors.name[0]` → `fields["name"]`).

## VaultsUiState (`Vaults/VaultsUiState.swift`)

```text
enum VaultsContent: Equatable {
  case loading
  case loaded([Vault])          // empty array = empty state
  case failed(AuthError)        // first load failed: message + Try again
}
struct VaultsUiState: Equatable {
  var content: VaultsContent = .loading
  var isRefreshing = false      // a reload while a list is shown
  var refreshFailed = false     // the inline "could not be updated" message (R10)
}
```

Transitions (`VaultsViewModel`):

| From | Event | To |
|---|---|---|
| `.loading` | `load()` succeeds | `.loaded(vaults)` |
| `.loading` | `load()` fails (not ended/cancelled) | `.failed(error)` |
| `.failed` | `tryAgain()` | `.loading` → as above |
| `.loaded` | `load()` (reappear, pull, created) | `isRefreshing`; success → `.loaded(new)`, `refreshFailed = false`; failure → keeps list, `refreshFailed = true` |
| any | `dismissRefreshMessage()` | `refreshFailed = false` |
| any | session ended / cancelled | unchanged (RootView shows the welcome screen) |

`hasVaults` (for the form's "Make default" option) = `.loaded` with at least one vault.

## VaultUiState (`Vaults/VaultUiState.swift`)

```text
enum VaultUiState: Equatable { case loading, loaded(Vault), notFound, failed(AuthError) }
```

`VaultViewModel(id:repository:)`: `load()` → `loaded` / `notFound` (404) / `failed`; `tryAgain()`.

## NewVaultUiState (`Vaults/NewVaultUiState.swift`)

```text
struct NewVaultUiState: Equatable {
  var name = "", description = ""
  var colour: VaultColour = .blue
  var makeDefault = false
  let offersDefault: Bool       // the account already has a vault (FR-013)
  var isSaving = false
  var fieldErrors: [String: String] = [:]   // "name", "description", "colour"
  var generalError: String?     // a refusal not tied to a field
  var connectionError: AuthError?
  var isConfirmingDiscard = false
  var canCreate: Bool           // name not blank && !isSaving
  var hasTypedSomething: Bool   // name or description not blank
}
```

Events (`NewVaultViewModel`): `changeName`, `changeDescription` (each clears its field error and the
connection error), `chooseColour`, `toggleMakeDefault`, `create() async -> Vault?` (nil when it did
not succeed), `cancel()` (closes directly when nothing typed, otherwise `isConfirmingDiscard`),
`keepEditing()`.

## AccountUiState (`Account/AccountUiState.swift`)

Today's `HomeUiState`, renamed, plus `initials: String?` (research R12). Fields: `name`,
`instanceURL`, `isConfirmingLogout`, `sheet` (instance sheet), `confirmSwitchTo`, `message`.
