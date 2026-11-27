# Research: Offline Reading

Decisions behind [plan.md](plan.md). The Android app made the same feature in
monicahq/android#8 (`specs/004-offline-reading/research.md` there); where iOS differs, it says why.

## R1. Storage: SwiftData *(decided by the person)*

**Decision**: one SwiftData store, `OfflineCopy.store`, in its own folder
`Application Support/OfflineCopy/`. A `VersionedSchema` (`OfflineSchemaV1`) and an empty
`SchemaMigrationPlan` exist from the first version, so the first feature that adds a model (the
queue of changes to send, R3) adds `OfflineSchemaV2` and a lightweight migration stage.

**Rationale**: SwiftData is the constitution's preferred local storage and a system framework: no
package, nothing to justify. It gives what offline writing will need: one row per record,
predicates, unique attributes and migrations. Repositories are `@MainActor`, so they use the
container's `mainContext` directly; fetching 100 vaults takes a few milliseconds.

**Alternatives considered**:
- *One encrypted JSON file per resource* (CryptoKit + Keychain key): simplest for read only, but a
  record-level sync state (FR-018 to FR-020) means rewriting whole files and hand-made merging.
  Dropped when offline writing became a requirement.
- *SQLite + SQLCipher (GRDB)*: same as Android, app-level encryption, but a third-party package
  against Principle I, and Data Protection already encrypts at rest (R2).
- *Core Data*: same engine as SwiftData with more code; SwiftData is the documented choice.

## R2. Encryption at rest: Data Protection

**Decision**: no encryption code. The store's files are protected by iOS Data Protection, class
`completeUntilFirstUserAuthentication` (the app's default class, set explicitly on the folder when
it is created). Each file is encrypted with a per-file key wrapped by a class key that is derived
from this iPhone's hardware key and the passcode: it never leaves the phone, is never synced or
backed up, and is unavailable before the first unlock after a restart (FR-012).

**Rationale**: it is Apple's documented way to protect app data at rest, it costs nothing, and it is
what protects the Keychain items too. The stricter class `complete` was rejected: it would make the
copy unreadable while the phone is locked, which the future background sync of offline changes
(BackgroundTasks) needs.

**What it does not do**: on a jailbroken phone, unlocked once since its restart, a process with root
can read the files, exactly as it could read a Keychain-held key of an app-level encryption.
Android's SQLCipher has the same limit with a live root. Accepted.

**If the store cannot be opened** (before the first unlock, damaged file, unknown schema): see R5.

## R3. Ready for offline writing *(asked by the person)*

**Decision**: every model holding instance data has the same five sync fields from version 1:

| Field | Today | When offline writing arrives |
|---|---|---|
| `localID: UUID` (`@Attribute(.unique)`) | made on the phone when the record first arrives | identity of a record not yet created on the instance |
| `serverID: String?` (unique by the rule below) | the instance's id | nil until the instance created the record |
| `syncState: SyncState` | always `.synced` | `.pendingCreate`, `.pendingUpdate`, `.pendingDelete` |
| `serverUpdatedAt: Date?` | `updated_at` the instance answered | detects that the instance changed a record edited offline |
| `syncedAt: Date` | when the row last came from the instance | same |

And one rule, enforced and tested now (`Reconcile.swift`, a pure function): **an answer from the
instance only inserts, replaces or removes records whose state is `.synced`.** A record with a change
waiting is never overwritten or removed by a refresh.

`SyncState` declares its four cases now (stored as its raw `String`), because the rule's tests need
a pending record and the stored values must not change later.

The queue of changes to send (`PendingChange`: id, createdAt, kind, target localID, payload,
attempts, lastError) is described in [data-model.md](data-model.md) but **not created**: it comes
with the feature that writes offline, as `OfflineSchemaV2`. Creating it now would ship an unused
model.

**API prerequisites, not in this feature** (checked in `../monica`): the API has no idempotency key
and no conditional update (no `If-Match` / `If-Unmodified-Since` handling, no 412). Both are added to
the Monica API before offline writing is specified (spec Assumptions). `VaultResource` already
answers `updated_at` (a Unix timestamp), which this feature now decodes.

**Rationale**: the costly part of adding offline writes later is changing every record's identity and
the refresh rule. Doing both now costs five fields and one tested function; the queue is additive.

## R4. Where the files live, and backups

**Decision**: `Application Support/OfflineCopy/` (created with its protection class, R2), marked
`isExcludedFromBackup` on the folder, so iCloud and computer backups skip it and everything SwiftData
puts in it (`.store`, `-wal`, `-shm`).

**Device-to-device transfer**: the session is in the Keychain with a `ThisDeviceOnly` accessibility
and does not move to a new iPhone, and a fresh install wipes the Keychain. So on a new phone the app
starts signed out, and the start-up sweep (R5) erases any copy found. Even if a file came along, it is
never shown and is deleted at the first launch (spec Story 3, scenario 6).

**Alternatives considered**: `Caches/` (excluded from backups too) was rejected: iOS may purge it
under storage pressure, which would make offline reading unreliable.

## R5. One erasure point: the session

**Decision**: `SessionManager` owns the copy's life through an `OfflineCopy` given to its
initializer. `OfflineCopy` is a `@MainActor final class` (no protocol: tests use a real one on a
temporary folder, R9).

- **Erase** (`erase()`): drops the `ModelContainer`, then deletes the whole folder. Every model of
  every later feature is in that store, so nothing can be forgotten (FR-010, FR-015). Called in
  `endLocally(_:)` after the session is deleted from the Keychain and **before**
  `state = .signedOut(reason)`. Every session end goes through `endLocally`: log-out (`logOut`
  calls it before telling the instance), instance switch (`logOut(reason: .instanceChanged)`),
  ended (401 after renewal, refused renewal), expired.
- **Sweep at start** (in `SessionManager.init`): signed out → `erase()`. Signed in →
  `open(owner:now:)`, which erases and recreates the store when its owner is not this session's, the
  store cannot be opened, the last contact is more than 30 days old, or the clock is earlier than the
  last contact (FR-013).
- **New session** (`complete(callback:currentInstance:)`): `open(owner:now:)` with the new session's
  owner before `state = .signedIn`, which erases whatever another session left.
- A failed deletion (I/O) is not reported to the person: the next sweep finds a store whose owner is
  not the current one, or a signed-out app, and erases it.
- **Before the first unlock** (app woken in the background after a restart): the store's files
  cannot be read. `open` then does nothing and erases nothing; reads answer nil (no copy) until the
  next opening (spec Edge Cases). Detected with `UIApplication.isProtectedDataAvailable`, passed in
  as a closure so tests can say no.

## R6. The owner, and no late write

**Decision**: the owner is a random `UUID` made when a session is created (`Session.copyOwner`),
stored in the Keychain with the session and kept by every renewal. The store keeps it in its one
`CopyInfo` row. A new sign-in, even to the same account on the same instance, makes a new owner, so a
copy can never be shown to another session (FR-008). No API change is needed (the instance's user id
would have needed `/me`'s id in the session).

`Session` gains a field: sessions stored by 0.1.0 builds fail to decode and the app starts signed
out, as after a fresh install. Acceptable: the app has not been released.

**No late write**: `authorized(...)` already throws `.cancelled` when the session changed during the
request (`generation`). The repository writes to the copy right after `authorized` returns, on the
main actor and without suspending, so no session end can happen in between. No extra owner check is
needed on writes (Android needed one because its writes are asynchronous).

## R7. "Last contact" for the 30-day limit

**Decision**: `SessionManager.authorized` calls `offlineCopy.recordContact(at: now())` for every
answer that is not a 401 (2xx, 403, 404, 422, 5xx all prove the instance and the session are alive).
The copy saves it at most once an hour, to avoid a disk write per request. The 30 days are counted
by the injected clock.

## R8. Showing the copy, then the instance's answer

**Decision**: repositories gain reads of the copy next to their API calls:

- `cachedVaults() -> Cached<[Vault]>?` and `cachedVault(id:) -> Cached<Vault>?`, where
  `Cached<Value>` holds the value and when it was last updated (the list's `Freshness` row, or the
  vault row's `syncedAt`). nil means no copy.
- `vaults()` on success replaces the list in the copy (R3 rule, list order kept in `position`), sets
  the list's freshness, saves, and returns. `vault(id:)` on success upserts the vault; on `.notFound`
  deletes it from the copy (FR-007).
- View models show the copy at once if their state holds nothing yet, then call the API. On a
  failure with a copy shown, they set `staleSince` (the copy's date) instead of the error. With no
  copy, nothing changes (FR-004).
- `create(_:)` is unchanged: the list reloads after a creation and picks the vault up.

Writing the copy is part of the repository's success path; if saving fails (storage full), the error
is swallowed and the answer is still returned (spec Edge Cases).

## R9. The "not up to date" line

**Decision**: one shared view, `Offline/StaleNoticeView.swift` (`StaleNoticeView(since: Date?)`,
shows nothing when nil), placed under the screen's title, outside the scrolling list. Its text comes
from a pure function in `Offline/StaleNotice.swift`, unit tested:
`staleNoticeText(since:now:locale:)` → "Not up to date. Last updated 3 hours ago." with
`RelativeDateTimeFormatter` (`.full` units style, the person's locale) for the relative part.

- Words and an icon (`icloud.slash`, hidden from VoiceOver), never colour alone; secondary text
  colour, which meets contrast in both appearances; wraps at every text size.
- Re-rendered every minute with `TimelineView(.everyMinute)` so "2 minutes ago" moves.
- VoiceOver reads it in place, and an announcement (`AccessibilityNotification.Announcement`) is
  posted when it appears or disappears.
- String Catalog key `stale_notice` (the Android key) — EN "Not up to date. Last updated %@.",
  FR "Pas à jour. Mis à jour %@."; `stale_notice_gone` ("Up to date." / "À jour.") is announced
  when the line goes.

## R10. Testing

**Decision**: unit tests only (constitution IV), with a **real** `OfflineCopy` on a temporary folder
rather than a fake: the files, their deletion and the backup flag are what must be proven, and a fake
behind a protocol would exist only for tests (same reasoning as `temporaryDefaults()`).

- `OfflineCopyTests`: open, owner mismatch, unreadable store (garbage file), 30 days, clock moved
  back, protected data unavailable, erase removes the folder, backup flag set, contact saved at most
  once an hour.
- `ReconcileTests`: the pure rule, including pending records left untouched.
- `SessionManagerOfflineTests`: erased before `.signedOut` for each of the five reasons (checked from
  an observer of `state`), sweep at start signed in and signed out, new owner at sign-in, contact
  recorded on non-401 answers only.
- `VaultRepositoryTests`, `VaultsViewModelTests`, `VaultViewModelTests`: copy written after success,
  replaced whole, pending untouched, deleted on 404, shown at once, stale on failure, unchanged
  behaviour with no copy.
- `StaleNoticeTests`: text in English and French at several distances.
- `Harness` builds the copy in a temporary folder; `relaunched()` reuses it, to test the sweep.
- Data Protection itself is not observable in the simulator: checked by hand on a device
  ([quickstart.md](quickstart.md)).

## R11. Exceptions (constitution VIII)

Creating a vault writes, so it stays online-only, as today. Nothing else in scope.
