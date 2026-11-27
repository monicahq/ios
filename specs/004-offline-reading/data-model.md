# Data Model: Offline Reading

One SwiftData store, `Application Support/OfflineCopy/OfflineCopy.store`, schema `OfflineSchemaV1`.
Every model of every feature that reads offline lives in this one store, so erasing it erases them
all ([research.md](research.md) R5).

## Models (`Monica/Data/Offline/OfflineSchema.swift`, vaults in `Monica/Data/Vaults/`)

### `CopyInfo` — exactly one row

| Field | Type | Meaning |
|---|---|---|
| `owner` | `UUID` | `Session.copyOwner` of the session that opened the store (R6) |
| `lastContactAt` | `Date` | last answer from the instance that was not a 401 (R7), saved at most hourly |

Created by `open(owner:now:)` with `lastContactAt = now`.

### `Freshness` — one row per kind of list

| Field | Type | Meaning |
|---|---|---|
| `kind` | `String`, unique | `"vaults"` today; `"contacts:<vault id>"` and so on later |
| `updatedAt` | `Date` | when the instance last answered that whole list |

A list with no `Freshness` row has no copy (`cachedVaults()` answers nil), even if single vaults
were stored by `vault(id:)`.

### `CachedVault` — one row per vault

| Field | Type | From the API |
|---|---|---|
| `localID` | `UUID`, unique | — (made on the phone) |
| `serverID` | `String?` (unique by the refresh rule, not by the store, which would see two nils as a clash) | `id` |
| `syncState` | `SyncState` (raw `String`) | — (`.synced`) |
| `serverUpdatedAt` | `Date?` | `attributes.updated_at` (Unix seconds; null allowed) |
| `syncedAt` | `Date` | — (when this row last came from the instance) |
| `position` | `Int` | index in the last list answered (single fetches keep the old one, or `Int.max` if new) |
| `name` | `String` | `attributes.name` |
| `details` | `String?` | `attributes.description` (`description` clashes with `CustomStringConvertible`) |
| `colour` | `String` | the raw value of the vault's `VaultColour` |
| `isDefault` | `Bool` | `attributes.is_default` |
| `contactCount` | `Int` | `attributes.contact_count` |

Read back as the existing `Vault` value type; screens never see a model object.

`VaultAttributes` gains `updatedAt: Date?` (decoded from `updated_at`), and `Vault` gains
`updatedAt: Date?` so the repository can store it.

## Sync state (`Monica/Data/Offline/SyncState.swift`)

```text
enum SyncState: String { synced, pendingCreate, pendingUpdate, pendingDelete }
```

Today only `.synced` is ever written by the app. Transitions when offline writing arrives:

```text
(new on phone) ── pendingCreate ──send OK──▶ synced (serverID set)
synced ──edit offline──▶ pendingUpdate ──send OK──▶ synced
synced ──delete offline──▶ pendingDelete ──send OK──▶ (row removed)
pending* ──instance refuses──▶ stays pending, attempts/lastError in the queue
```

## The refresh rule (`Monica/Data/Offline/Reconcile.swift`)

A pure function, no SwiftData inside:

```text
reconcile(existing: [(serverID: String?, state: SyncState)], incoming: [String])
  -> (update: Set<String>, insert: [String], delete: Set<String>)
```

- `incoming` ids present in `existing` with state `.synced` → update (fields replaced, `position`
  and `syncedAt` set).
- `incoming` ids absent from `existing` → insert, with a new `localID`.
- `existing` `.synced` rows absent from `incoming` → delete.
- Rows with any other state → never in `update` or `delete`, whatever the answer.

Applied for a whole list, then one `save()`: the copy equals the last answer, never a mix of two
(spec Edge Cases). Single fetches use the same rule with one id.

## Reserved for offline writing (not created in this feature)

`PendingChange` (`OfflineSchemaV2`): `id: UUID`, `createdAt: Date`, `kind: String`
(`"vault.create"`...), `target: UUID` (the record's `localID`), `payload: Data` (the JSON body),
`attempts: Int`, `lastError: String?`. Sent in `createdAt` order once online, with the idempotency
key and the precondition the Monica API will offer.

## `Session` (Keychain)

Gains `copyOwner: UUID`, made in `complete(callback:currentInstance:)` and copied by every renewal.

## Lifetime

| Event | Effect on the store |
|---|---|
| Sign-in completed | `open(owner: new)` → previous store erased, empty store with the new owner |
| App start, signed in | `open(owner:)` → kept, or erased and recreated (other owner, unreadable, > 30 days, clock back) |
| App start, signed out | `erase()` |
| Any session end (5 reasons) | `erase()` before `.signedOut` |
| Answer not 401 | `lastContactAt` updated (at most hourly) |
| Vault list answered | `CachedVault` reconciled, `Freshness("vaults")` set |
| One vault answered / 404 | upserted / deleted |
