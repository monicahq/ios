# Feature Specification: Offline Reading

**Feature Branch**: `2026-11-27-offline-reading`

**Created**: 2026-11-27

**Status**: Draft

**Input**: User description: "je veux faire sur ios ce qu'on a fait pour android dans la branche
https://github.com/monicahq/android/pull/8"

**Source**: the same feature in the Android app, `specs/004-offline-reading` on the
`2026-11-27-offline-reading` branch of monicahq/android (pull request #8). This spec carries over its
behaviour, its guarantees and its decisions (30-day expiry, read only), with iOS words: VoiceOver,
iCloud backup, device-to-device transfer.

**Builds on**: `specs/003-vaults-list` (pull request #10, merged), which added the vault list, the
vault screen and the vault creation form. This feature changes how those screens get their data.

**Constitution**: the Android project added Principle VIII "Readable Offline" to its constitution with
this feature. The iOS constitution gets the same principle (an amendment through
`/speckit-constitution`, before or with the plan); the requirements below are its detailed form. The
server stays the source of truth: the phone only keeps a copy of what the instance already answered.

## Clarifications

### Session 2026-11-27

- Q: If the phone never reaches the instance again (lost phone, session ended from the web while the
  phone is offline), should the copy expire on its own? → A: Yes, as decided for Android. After
  30 days without any successful contact with the instance, the copy is erased the next time the app
  opens (FR-013).
- Q: Must the copy be ready for adding and editing offline later, with the changes sent to the
  instance once back online? → A: Yes. Offline writing stays out of this feature, but the copy is
  built so that it can be added later without redoing it: each record has its own identity on the
  phone, says whether it matches the instance or has a change waiting, and keeps the instance's last
  modification time; an update from the instance never overwrites a change waiting (FR-018 to
  FR-020). The Android app made the same choice.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See my vaults without a connection (Priority: P1)

A person on a plane, in the metro or abroad without data opens the app. Instead of an error, they see
their vaults as they were the last time the app reached the instance, with a discreet line saying the
list is not up to date and when it was last updated ("Last updated 3 hours ago"). When the connection
comes back, the list updates by itself and the line disappears.

**Why this priority**: It is the reason for the feature. Without it, the app is useless whenever the
network is.

**Independent Test**: Sign in and open the vault list once online. Turn on Airplane Mode, quit the app
from the app switcher, reopen it: the same vaults appear, with the "not up to date" line and the right
time. Turn Airplane Mode off: the list refreshes and the line goes.

**Acceptance Scenarios**:

1. **Given** the vault list was loaded at least once on this iPhone for this account, **When** the app
   opens without a connection, **Then** the vault list shows the copy, with the same vaults, order,
   names, colours, contact counts and default badge as when it was last loaded.
2. **Given** the copy is shown because the instance cannot be reached, **When** the screen is
   displayed, **Then** it says the information is not up to date and since when, in words and a
   relative time in the person's language ("Last updated 3 hours ago" / "Mis à jour il y a
   3 heures"), not by colour alone.
3. **Given** the copy is shown offline, **When** the connection comes back and the screen is shown
   again, the app returns to the foreground, or the list is pulled down, **Then** the list is updated
   from the instance and the "not up to date" line disappears.
4. **Given** the app has never loaded the vault list for this account on this iPhone (first sign-in,
   or the copy was erased), **When** it opens without a connection, **Then** the screen shows the
   connection error with "Try again", as it does today.
5. **Given** the copy is shown offline, **When** the person pulls the list down, **Then** the copy
   stays and the screen says "Your vaults could not be updated.", as it does today.

---

### User Story 2 - Instant screens when online (Priority: P1)

A person with a connection opens the app. Their vaults appear at once, from the copy, then are
replaced by the instance's answer a moment later, without a loading indicator in between and without
the list jumping or flashing.

**Why this priority**: Every person benefits from it, every day, not only offline. It also proves the
copy is used consistently before the offline case is relied on.

**Independent Test**: With a slow connection (Network Link Conditioner, or an instance that answers
after 3 seconds), open the app: the list shows immediately. Rename a vault on the web, reopen the app:
the old name shows, then the new one replaces it without any action.

**Acceptance Scenarios**:

1. **Given** a copy exists and the instance answers, **When** the app opens, **Then** the list
   appears from the copy before the instance answers, with no loading indicator covering it.
2. **Given** a vault was renamed, recoloured, added or deleted on the web, **When** the instance
   answers, **Then** the list shows exactly what the instance answered: renamed and recoloured vaults
   change, new ones appear, deleted ones disappear, in the instance's order.
3. **Given** the instance answers while the copy is shown, **When** the list updates, **Then** the
   person's scroll position and the vault they were about to tap stay in place where those vaults
   still exist, and VoiceOver focus is not moved.
4. **Given** no copy exists yet, **When** the app opens online, **Then** the screen shows loading,
   then the list, as today.

---

### User Story 3 - The copy never outlives the session, never leaves the phone (Priority: P1)

The copy holds what a person knows about the people they love. It exists only for the session that
loaded it: it disappears when the person logs out, switches instance, when the instance ends the
session, or when the session expires, and it disappears on its own after 30 days without reaching the
instance. It is never included in iCloud or computer backups or in a transfer to a new iPhone, and it
cannot be read by other apps or by someone copying the app's files.

**Why this priority**: Keeping personal data on the phone is acceptable only with these guarantees. A
copy that survives a log-out, or shows one instance's data on another, would be a serious privacy
failure.

**Independent Test**: For each way a session ends (log out, instance switch, session ended from the
web, session expired), check that the next launch shows no data from that session, even offline. Move
the iPhone's clock 31 days ahead with no network: the copy is gone. Inspect a computer backup and the
app's container: no vault name appears in readable form.

**Acceptance Scenarios**:

1. **Given** a copy exists, **When** the person logs out (confirmed), **Then** the copy is erased
   before the welcome screen appears, whether the instance could be told or not.
2. **Given** a copy exists for instance A, **When** the person switches to instance B, **Then**
   nothing from A is ever shown while signed in to B, even offline, even for a moment.
3. **Given** a copy exists, **When** the instance ends the session (ended from the web, or renewal
   refused) or the session expires, **Then** the copy is erased as soon as the app learns it, and the
   welcome screen says why, as today.
4. **Given** the person logs out and another account signs in on the same instance, **When** the list
   loads, **Then** nothing from the first account appears.
5. **Given** the app has not reached the instance successfully for more than 30 days, **When** the app
   opens, **Then** the copy is erased before anything is shown, and the screens behave as if no copy
   had ever existed (online: loading then the list; offline: the connection error).
6. **Given** the iPhone is backed up to iCloud or a computer, or transferred to a new iPhone, **When**
   the backup or transfer is restored, **Then** it contains no usable copy; the restored app shows no
   data until it signs in and loads again.
7. **Given** someone reads the app's files directly (jailbroken phone, forensic copy), **When** they
   look for the copy, **Then** its contents are not readable without a key that never leaves this
   iPhone.

---

### User Story 4 - Open a vault without a connection (Priority: P2)

Offline, the person taps a vault in the list and sees its screen (name, colour, description) from the
copy, with the same "not up to date" line.

**Why this priority**: Opening a vault is the next step after the list; the vault screen is still
small, so the value is smaller today but grows with every later feature.

**Independent Test**: Load the list online, go offline, tap any vault (including one never opened
before): its screen shows its name, colour and description, with the "not up to date" line.

**Acceptance Scenarios**:

1. **Given** a vault is in the copy of the list, **When** the person opens it offline, **Then** its
   screen shows its name, colour and description from the copy, even if it was never opened online.
2. **Given** a vault is shown from the copy, **When** the instance answers that it no longer exists,
   **Then** the screen says "This vault no longer exists." and the vault disappears from the copy and
   the list.
3. **Given** the vault screen shows the copy, **When** the instance answers with changes, **Then** the
   screen updates in place.

---

### User Story 5 - Every later resource reads offline the same way (Priority: P3)

When contacts, reminders and the other resources arrive, each one is kept and shown offline under
exactly the rules of this feature, without anyone having to redesign them: same encryption, same
erasure, same expiry, same "not up to date" line.

**Why this priority**: It is not visible today, but it decides whether offline reading stays safe as
the app grows. A resource that forgets to erase its copy on log-out would undo Story 3.

**Independent Test**: Review: the rules of Stories 1 to 4 are stated once, for any resource, and the
erasure at the end of a session covers every resource kept, not a list that must be updated by hand.

**Acceptance Scenarios**:

1. **Given** a new resource keeps a copy, **When** the session ends or 30 days pass, **Then** its copy
   is erased with the others, without that resource doing anything specific.
2. **Given** a new resource keeps a copy, **When** it is shown offline, **Then** it shows the same "not
   up to date" line with the same wording.

---

### Edge Cases

- **Never online since sign-in**: no copy; offline launch shows the connection error (as today).
- **Copy cannot be read** (key lost after restoring a backup or resetting the phone, file damaged,
  app updated with a different storage format): the copy is discarded without an error message and
  the screens behave as with no copy.
- **App opened before the first unlock after a restart** (in the background): the copy is not read
  and nothing is erased because of it; the next normal opening behaves as usual.
- **Phone storage full**: the app keeps working online without a copy; nothing is shown as broken.
- **Session ended from the web while the phone is offline**: the app cannot know; the copy stays
  readable until the app reaches the instance or 30 days pass (accepted risk, see Clarifications).
- **Clock moved**: the 30-day limit counts from the last successful contact, by the phone's clock. A
  clock moved forwards erases early; a clock set before the last successful contact also erases,
  since the limit can no longer be trusted (both on the safe side).
- **Instance reachable but failing** (server error, timeout): same as offline: copy shown with the
  "not up to date" line.
- **Session ended while a screen shows the copy**: the copy is erased and the app goes to the welcome
  screen; nothing of the copy stays on screen, including in the app switcher snapshot taken next.
- **Creating a vault offline**: not possible (read only). The form behaves as today: it keeps what was
  typed and says the instance cannot be reached.
- **A vault created online**: appears in the copy at the next update of the list.
- **Two vault lists in quick succession** (pull to refresh while the automatic update runs): the copy
  ends up equal to the latest answer, never a mix of two answers.
- **Largest accessibility text size, VoiceOver, dark mode**: the "not up to date" line wraps, is read
  by VoiceOver when the screen opens and announced when it appears or disappears, and meets contrast
  in both appearances.

## Requirements *(mandatory)*

### Functional Requirements

**Showing the copy**

- **FR-001**: Each time the vault list or a vault is received from the instance, the app MUST keep it
  as the copy for the current session, replacing the previous copy of the same data entirely (a vault
  absent from a new list is removed from the copy).
- **FR-002**: When a screen opens and a copy exists, the app MUST show the copy at once, then ask the
  instance and replace what is shown with its answer.
- **FR-003**: When the instance cannot be reached or fails, and a copy exists, the screen MUST keep
  showing the copy and MUST say it is not up to date, with the time of the last successful update as a
  relative time in the person's language.
- **FR-004**: When no copy exists, screens MUST behave exactly as they do without this feature
  (loading, error with "Try again").
- **FR-005**: The "not up to date" line MUST disappear as soon as an update succeeds.
- **FR-006**: The copy is read only: no action offered by the app MUST change it without the instance
  answering first. Actions that need the instance (creating a vault) keep their current behaviour
  offline.
- **FR-007**: A vault the instance reports as no longer existing MUST be removed from the copy.

**Isolation and erasure**

- **FR-008**: The copy MUST belong to one instance and one account. Data kept for one instance or
  account MUST never be shown while signed in to another.
- **FR-009**: The copy MUST be erased whenever a session ends, whatever the reason: log-out
  (including when the instance could not be told), instance switch, session ended by the instance,
  renewal refused, session expired.
- **FR-010**: Erasure MUST be complete before the welcome screen is shown, and MUST cover every kind of
  data kept, including kinds added by later features.
- **FR-011**: The copy MUST be excluded from iCloud and computer backups and from transfers to a new
  iPhone.
- **FR-012**: The copy MUST be stored encrypted with a key that only this app on this iPhone can use,
  that is never synced or backed up, and that is protected while the phone is locked after a restart;
  if the key is unavailable, the copy is discarded.
- **FR-013**: When more than 30 days have passed since the last successful contact with the instance,
  or when the phone's clock is earlier than that last contact, the copy MUST be erased the next time
  the app opens, before anything is shown.
- **FR-014**: The copy MUST NOT be readable by other apps or extensions, shared, exported, or included
  in logs and crash reports.

**For every resource**

- **FR-015**: The rules FR-001 to FR-014 MUST apply to every resource that later keeps a copy
  (contacts, reminders...), and the erasure MUST not depend on each resource remembering to erase
  itself.

**Ready for offline writing later**

- **FR-018**: Each record in the copy MUST have an identity of its own on the phone, separate from the
  identity the instance gives it, so that a record created offline later can exist before the
  instance knows it, and keep its identity once the instance has created it.
- **FR-019**: Each record MUST say whether it matches the instance or holds a change waiting to be
  sent (created, edited or deleted), and MUST keep the instance's last modification time for it.
  Today every record matches the instance.
- **FR-020**: An update from the instance MUST only replace or remove records that match the
  instance; a record holding a change waiting MUST never be overwritten or removed by it. Today this
  changes nothing visible, and it is tested now so that it holds the day offline writing arrives.

**Language and accessibility**

- **FR-016**: Every new text (the "not up to date" line and its relative times) MUST exist in English
  and French, with times formatted for the person's locale; the wording matches the Android app.
- **FR-017**: The "not up to date" state MUST be conveyed in words (never by colour alone), be read by
  VoiceOver, be announced when it appears or disappears, meet the contrast rules in light and dark,
  and stay readable at the largest accessibility text size.

### Key Entities *(include if feature involves data)*

- **Local copy**: what the instance last answered for the current session, per kind of data (today:
  the vault list and each vault). Belongs to one instance and one account. Read only.
- **Last successful update**: per kind of data, when the instance last answered; used for the "not up
  to date" line.
- **Sync state**: per record, its identity on the phone, the instance's identity (none yet for a
  record created offline later), whether it matches the instance or has a change waiting, and the
  instance's last modification time.
- **Last contact with the instance**: when any request last succeeded; used for the 30-day expiry.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a copy present, the vault list is visible within 1 second of opening the app, with
  or without a connection, on the oldest supported iPhone.
- **SC-002**: In Airplane Mode, a person who loaded their vaults at least once can see the list and
  open any vault in 100% of attempts, until a session end or the 30-day limit.
- **SC-003**: After any of the five ways a session ends, 0 items of the previous session's data can be
  seen in the app, even offline, and 0 remain readable in the app's storage.
- **SC-004**: An iCloud or computer backup, or a transfer to a new iPhone, gives 0 readable items of
  vault data once restored.
- **SC-005**: Read directly from the app's files, the copy reveals 0 readable vault names or
  descriptions.
- **SC-006**: After an update succeeds, the screen shows exactly the instance's answer in 100% of cases
  (no vault left over, none missing, same order).
- **SC-007**: Every state of the affected screens, including "not up to date", passes the
  Accessibility Inspector audit in light and dark, and is understood with VoiceOver alone.

## Assumptions

- Read only, as decided for Android: writing offline (creating or editing while disconnected, then
  sending later) is out of scope here, but FR-018 to FR-020 keep the copy ready for it. The feature
  that adds it brings the queue of changes to send, the sending once back online, the handling of a
  change the instance refuses, and what happens to unsent changes at log-out (warn before erasing).
- Sending offline changes safely needs two things the Monica API does not offer today (checked in
  the Monica repository): a create that can be retried without making a duplicate (an idempotency
  key, or an id chosen by the app), and an update that is refused when the record changed on the
  instance since it was read (a precondition on its last modification time). Per the project rules,
  they are added to the Monica API first, for both mobile apps, before offline writing is specified.
  The vault API already answers each vault's last modification time, which FR-019 keeps.
- The scope of this feature is the vault list and the vault screen; contacts, reminders and the rest
  follow FR-015 when their own features arrive.
- The phone's own passcode, Face ID or Touch ID protects access to the unlocked app; the app adds no
  lock of its own (a possible later feature).
- The 30-day limit counts from the last successful request of any kind to the instance.
- Nothing about the session (tokens) changes: it stays where and how `specs/002-login-registration`
  stores it. The copy is separate and erased with it.
- No new Monica API endpoint is needed: the copy holds exactly what the existing endpoints answer.
- The iOS constitution gains a "Readable Offline" principle matching the Android one.
- Storage: SwiftData, the constitution's preferred local storage (decided by the person,
  2026-11-27). It has no encryption of its own: FR-012 is met by iOS Data Protection on the store's
  files (keys bound to this iPhone's hardware, never synced, unavailable before the first unlock
  after a restart), with the files excluded from backups (FR-011). The plan details how.
