# Contract: the offline copy

What every feature can rely on, and what it must do. This is the reference for constitution
Principle VIII on iOS; a later feature that keeps data offline follows it without redesigning
anything. Same guarantees as the Android contract (monicahq/android `specs/004-offline-reading`).

## `OfflineCopy` (`Monica/Data/Offline/OfflineCopy.swift`, `@MainActor final class`)

```text
init(directory: URL, isProtectedDataAvailable: @escaping () -> Bool)
func open(owner: UUID, now: Date)          // SessionManager only
func erase()                               // SessionManager only
func recordContact(at: Date)               // SessionManager only
var context: ModelContext?                 // repositories; nil = no copy available right now
func save()                                // repositories; a failure is swallowed
```

## Guarantees (given by `OfflineCopy` and `SessionManager`)

1. **One owner.** The store belongs to one session (`Session.copyOwner`). It is opened by
   `SessionManager` when a session starts or is restored, never by a feature.
2. **Erased at every session end**, before `state` becomes `.signedOut`: log-out (even when the
   instance could not be told), instance switch, session ended by the instance, renewal refused,
   session expired.
3. **Erased at start** when the app is signed out, or the store belongs to another owner, cannot be
   opened, saw no contact for more than 30 days, or the clock is earlier than that contact.
4. **No late write.** Writes happen on the main actor right after `authorized(...)` returned, which
   throws when the session changed during the request.
5. **Protected at rest** (Data Protection, `completeUntilFirstUserAuthentication`), **never backed
   up** (`isExcludedFromBackup` on the folder), never logged.
6. **Everything at once.** Erasure deletes the whole folder: a feature never erases its own models.

## What a feature does to read offline

1. Add its `@Model` with the five sync fields ([data-model.md](../data-model.md)) to the current
   `VersionedSchema` (a new version and a migration stage once the app has shipped a store).
2. In its repository: a `cachedX() -> Cached<…>?` read; after each successful API answer, apply
   `reconcile` to its rows, set its `Freshness` row for a list, and `save()`. On 404, delete the row.
3. In its view model: show the copy at once; on a failed answer with a copy shown, set `staleSince`
   instead of an error.
4. In its screen: keep `StaleNoticeView(since: state.staleSince)` under the title, outside any
   scrolling list.
5. Tests: copy shown offline, "not up to date" state, update replacing the copy, pending rows left
   alone, and that its rows are gone after a session end.

## What a feature never does

- Write to the copy anything the instance did not answer (until offline writing is specified, with
  the `PendingChange` queue and the API's idempotency key and precondition).
- Keep instance data on the phone anywhere else (`UserDefaults`, files, Keychain, logs).
- Open, erase or move the store itself.

## Strings (English / French)

| Key | English | French |
|---|---|---|
| `stale_notice` | Not up to date. Last updated %@. | Pas à jour. Mis à jour %@. |
| `stale_notice_gone` (VoiceOver announcement when the line goes) | Up to date. | À jour. |

`%@` is the relative time from `RelativeDateTimeFormatter` in the person's locale ("3 hours ago" /
"il y a 3 heures").
