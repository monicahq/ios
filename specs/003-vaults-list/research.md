# Research: Vault List

Decisions taken before design. Each one names what was chosen, why, and what was rejected. Where
the Android app (monicahq/android #7, `specs/003-vaults-list/research.md` on its branch) already
answered the same question, the answer is reused and the iOS difference stated.

## R1. Where API calls live

**Decision**: The layers the app already has, with one more repository:

- `Auth/MonicaClient` gains one general `send(method:url:json:token:)`, which `get` and a new JSON
  post use. The token rules stay where they are (own origin only, no redirects).
- `Auth/SessionManager` gains `authorized(_ method:, _ path:, json:)`, the core of today's
  `authorizedGet`: it renews access, retries once on 401, ends the session on a second 401,
  discards answers from an earlier generation, and returns the raw response for any other status.
  `authorizedGet` becomes a thin wrapper over it and keeps its behaviour, so `refreshPerson` is
  unchanged.
- `Data/Vaults/VaultRepository` (new) is the single source of truth for vaults: `vaults()` (every
  page), `vault(id:)`, `create(_:)`. It builds the requests, decodes the answers and turns statuses
  into `ApiError` (R2). View models call only it.

**Rationale**: The constitution asks for repositories as the single source of truth and no
abstraction without a need. The session rules already live in one place, so the repository only
has to add what is specific to vaults. A repository per data type stays the place to look for
"which call does this screen make", which is what the Android question (Laravel Actions and
controllers) was about.

**Alternatives considered**: a protocol for the repository with a fake implementation (rejected:
the view model tests run against the real repository and `FakeMonica`, as the existing view model
tests do, which also tests the decoding; no second consumer); a generic `ApiClient` layer between
the session manager and repositories (rejected: one repository today, its methods are three lines
each over `authorized`).

## R2. Errors the vault endpoints can answer

**Decision**: A new `Data/ApiError.swift`:

```text
enum ApiError: Error, Equatable {
  case failed(AuthError)        // network, session ended, 403, unexpected answer...
  case notFound                 // 404: deleted, someone else's, never existed
  case invalid(Refusal)         // 422: message and the first message of each field
}
struct Refusal: Equatable { let message: String; let fields: [String: String] }
```

Status mapping in the repository: 2xx decode (undecodable → `failed(.unexpectedAnswer)`), 404 →
`notFound`, 422 → `invalid` (undecodable → `failed(.unexpectedAnswer)`), 403 →
`failed(.notAllowed)`, other → `failed(.unexpectedAnswer)`. Errors thrown by the session manager
(network, ended session, cancelled) arrive as `failed`.

**Rationale**: `AuthError` is a closed list of messages from the String Catalog; a 422 carries the
instance's own text, which belongs in a value, not a new case per message. Keeping `AuthError` as
is avoids touching every screen of the sign-in feature. Same split as Android's `ApiResult.NotFound`
and `ApiResult.Invalid`.

**Alternatives considered**: adding `.notFound` and `.refused(String)` to `AuthError` (rejected: it
makes an auth type carry API concerns and an associated value through `message`, used everywhere).

## R3. Pagination

**Decision**: `vaults()` asks `GET /api/v1/vaults?page=n&per_page=100` (the API maximum) from page 1
and keeps going until it holds `meta.total` vaults or a page comes back empty, then returns them in
the order received.

**Rationale**: FR-002 and SC-003 (1, 25, 26, 150 vaults). One request covers nearly every account.
The empty-page stop protects against a total that changes while loading.

**Alternatives considered**: loading pages while scrolling (rejected: needless for a list this size,
and it would make the order and the "Default" badge depend on scrolling).

## R4. Navigation and the screens' shape

**Decision**: The signed-in branch of `RootView` shows `VaultsRoute`, which owns a `NavigationStack`
with a typed path of `VaultDestination(id:)` and the two sheets (account, new vault). Pushing a
`VaultDestination` shows `VaultRoute`. The list hides the system navigation bar and draws the
design's top bar itself; the vault screen uses the system bar with its standard back button and
an inline title.

**Rationale**: `NavigationStack` with typed destinations is the framework the constitution names,
and gives the edge swipe back and the standard Back button for free. The list's top bar is not a
standard navigation bar in the design (centred logo, account button on the left, large title in the
content, content fading beneath), and the instance sheet already showed that the iOS 26 system bar
with a large title fails the accessibility audit (Dynamic Type, contrast over glass). Drawing the
list's bar ourselves keeps it under our control; the vault screen's bar carries only Back and a
short inline title, which the audit accepts on the existing screens.

**Alternatives considered**: a system `.toolbar` with a large `navigationTitle` on the list (closest
to stock, but the centred logo and the audit failures rule it out); a router object holding the path
(rejected: one stack and one destination type, `@State` in the route is enough).

## R5. Refreshing the list after creating a vault or coming back

**Decision**: `VaultsViewModel.load()` runs in `.task` on the list (first appearance and each time
the list appears again after a pop). The first load shows the loading state; later loads keep the
list shown and only replace it on success, showing the refresh message on failure. After a vault is
created, the new vault view model reports it, the sheet closes, and the list reloads.

**Rationale**: The instance is the source of truth; reloading is a single cheap request and covers
the created vault, a vault deleted on the web and found missing on its screen, and a rename. Same
choice as Android (`onShown`).

**Alternatives considered**: inserting the created vault locally (rejected: the default badge may
move, and the server decides position).

## R6. Vault colours in light and dark (FR-020)

**Decision**: Reuse Android's measured pairs (initial colour on tinted square). They pass on iOS
because the iOS dark palette is the same night blue (card `#1E293B`):

| Colour (server) | Name | Light initial / tint | Ratio | Dark initial / tint | Ratio |
|---|---|---|---|---|---|
| `#3f5fd0` | Blue | `#3F5FD0` / `#E8ECF9` | 4.73 | `#97A9E6` / `#333F5B` | 4.56 |
| `#4f8a49` | Green | `#447740` / `#EAF1E9` | 4.61 | `#8EB48B` / `#314249` | 4.51 |
| `#9a6a24` | Ochre | `#8D6122` / `#F3EDE5` | 4.67 | `#C2A67C` / `#3C3F46` | 4.54 |
| `#9a3f2b` | Rust | `#9A3F2B` / `#F3E8E6` | 5.61 | `#CC9F95` / `#3E3D4B` | 4.54 |
| `#6b4fa8` | Violet | `#6B4FA8` / `#EDEAF5` | 5.35 | `#B2A3D2` / `#383E57` | 4.54 |
| `#2f7f86` | Teal | `#2C747B` / `#E6F0F0` | 4.65 | `#82B2B6` / `#2F4151` | 4.51 |
| `#a8447a` | Rose | `#A8447A` / `#F5E9EF` | 4.71 | `#D09AB7` / `#3E3C51` | 4.56 |
| `#4a4a52` | Graphite | `#4A4A52` / `#E9E9EA` | 7.23 | `#AAAAAE` / `#374050` | 4.51 |

They become 16 colour sets in `Assets.xcassets/Colors/Vault` (`VaultBlue`, `VaultBlueTint`, ...),
so screens use generated symbols, never raw values, as the theme rule asks. An unknown colour uses
the Graphite pair. In the form, the swatch is the initial colour; against the sheet's card it
measures at least 5.3:1 light and 6.2:1 dark (3:1 needed for a control).

**Rationale**: Measured by script with the WCAG formula (ratios above). One set of values for both
apps keeps a vault the same colour on both phones.

**Alternatives considered**: computing tints at run time (rejected: untestable contrast, and the
theme rule says colours come from the catalog).

## R7. The design's grouped background and secondary text

**Decision**: Three new colour sets for the screens of this feature:

| Token | Light | Dark | Use |
|---|---|---|---|
| `GroupedPage` | `#F2F2F7` | `#0F172A` (= `Page`) | background of the list, empty, loading, error and vault screens |
| `GroupedCard` | `#FFFFFF` | `#1E293B` (= `Card`) | vault cards, the empty state's icon tile, the form's sheet |
| `GroupedMuted` | `#68686F` | `#94A3B8` (= `Muted`) | secondary text on `GroupedPage` and `GroupedCard` |

**Rationale**: The design's iOS frames use the system grouped grey with white cards. The app's
`Muted` (`#71717A`) measures 4.33:1 on `#F2F2F7`, below 4.5:1; `#68686F` measures 4.95:1 on it and
5.53:1 on white. A white card on `#F2F2F7` is 1.12:1, so a card's edge is not a boundary people rely
on: the card is one button whose label is read, and cards are separated by space (as in the
design); this is decoration, not a control boundary (WCAG 1.4.11 applies to the control's
identifying parts, here its text). Dark values reuse the existing dark tokens, so dark mode stays
the app's night blue.

**Alternatives considered**: darkening `Muted` for the whole app (rejected: changes the welcome
screen, outside this feature's scope); using the system's `secondaryLabel` (rejected: translucent,
measures under 4.5:1 on `#F2F2F7`, and breaks the dark palette).

## R8. Liquid Glass, older iOS and Reduce Transparency (FR-021)

**Decision**: Two floating controls, each drawn three ways:

| Control | iOS 26 and later | iOS 18–25 | Reduce Transparency on |
|---|---|---|---|
| Account button (44 pt circle, initials in a 36 pt disc) | `.glassEffect(.regular.interactive(), in: .circle)` | `.regularMaterial` in a circle | `GroupedCard` circle with a `Hairline` border |
| "New vault" (capsule, bottom centre) | `.buttonStyle(.glassProminent)` tinted `PrimaryFill` | `PrimaryFill` capsule with a shadow | `PrimaryFill` capsule |

A small `Theme/FloatingStyles.swift` holds the two modifiers with the `#available(iOS 26, *)` check
and the `accessibilityReduceTransparency` environment value. The top of the list fades content into
`GroupedPage` under the account button and logo (a gradient, as in the design), so the button is
always drawn over a known background. The project builds with the iOS 27.2 SDK, which has these
APIs; the deployment target stays iOS 18.

**Rationale**: The design's two controls are exactly what the system glass gives on iOS 26. The
system makes glass more opaque with Reduce Transparency, but the spec asks for solid (SC-007), so
the environment value is read explicitly. Before iOS 26, a dark translucent capsule is not a system
style; a solid primary capsule is the readable equivalent (FR-021 allows it).

**Alternatives considered**: a custom blur imitating glass on every version (rejected: not native,
and the system glass adapts to content and accessibility settings by itself); raising the minimum to
iOS 26 (rejected: outside this feature, the constitution sets iOS 18).

## R9. Pull to refresh and its alternative (FR-006)

**Decision**: `.refreshable` on the list's `ScrollView` (it calls `load()` and the indicator stays
until it returns). The title and each card carry `.accessibilityAction(named: "Refresh")`, since
VoiceOver offers the actions of the focused element, and the refresh-failure message has a visible
"Try again" button, for whoever can neither drag nor use an assistive technology.

**Rationale**: The standard iOS gesture plus the accessible alternative the constitution asks for
any gesture.

**Alternatives considered**: a visible Refresh button in the top bar (rejected: not in the design,
and the action already covers every assistive technology).

## R10. Refresh failure message

**Decision**: When a reload fails while a list is shown, a short message "Your vaults could not be
updated." appears above the cards, with "Try again" and "Dismiss" buttons, and is announced to VoiceOver
(`AccessibilityNotification.Announcement`). It goes away at the next successful load.

**Rationale**: iOS has no snackbar; an inline message is how the placeholder home already reports
an error, and it does not disappear before someone has read it (WCAG 2.2.1).

**Alternatives considered**: an alert (rejected: interrupts for a transient, recoverable problem).

## R11. Account sheet

**Decision**: `Home/` becomes `Account/`. `HomeViewModel` becomes `AccountViewModel` with the same
responsibilities (name, instance, refresh of the person, log out, switch instance with the existing
instance sheet and confirmations) and a computed `initials`. `HomeScreen` becomes
`AccountSheetView`, shown as a sheet from the list: name (heading), "Connected to {host}",
"Instance settings", "Log out". It follows the instance sheet's layout (opaque card background,
content with its own buttons, full height with the accessibility text sizes), since the glass
sheet background failed the audit there. "Log out" asks with the existing alert. The "Connected
to {host}" button opens the existing instance sheet over the account sheet, so its alerts work
unchanged.

**Rationale**: Reuses the tested logic and screen as is (FR-018); a sheet over a sheet is standard on
iOS and avoids juggling which sheet is shown.

**Alternatives considered**: a `Menu` on the account button (rejected: it cannot show who is signed
in and on which instance in a readable way, and destructive actions in menus are easy to trigger by
mistake).

## R12. Initials

**Decision**: `Vaults/Initials.swift`, pure functions with unit tests:

- `vaultInitial(_ name: String) -> String`: the first grapheme (`Character`) of the trimmed name,
  uppercased for the current locale (`"élan"` → `"É"`, an emoji stays whole).
- `personInitials(_ name: String) -> String?`: the first character of the first two words that
  start with a letter, uppercased (`"Jean-Pierre Martin"` → `"JM"`); nil when none, so the button
  shows the `person.fill` symbol.

**Rationale**: Swift's `Character` is already a grapheme cluster, so no break iterator is needed.
Same rules as Android and the web.

## R13. Creating a vault: the form

**Decision**: `NewVaultViewModel` holds the draft (name, description, colour, make default), the
saving flag, field errors, a general error and whether discarding needs confirmation.
`canCreate` = name not blank and not saving. `create()` trims the name, omits a blank description,
sends `is_default` only when true, never sends `structure_version_id`. On `invalid`, the message of
the `name` field goes under the name, of `description` under the description, of `colour` under the
colour group, and the general message above the button when no field is named. On `failed`, the
error's message from the String Catalog. On success, it returns the created vault to the route,
which closes the sheet.

The sheet is drawn like the instance sheet (title and Cancel at the top of the content, opaque
`GroupedCard` background, full height), not a system `Form` with a navigation bar, for the audit
reason of R4. `.interactiveDismissDisabled(hasTypedSomething)` keeps a swipe from closing a sheet
holding text (FR-016); "Cancel" then shows a confirmation dialog. Colours are a wrapping grid of
eight 44 pt circles, each a button with its colour name as label, the `isSelected` trait on the
selected one, and a check mark drawn on it.

**Rationale**: Same rules as Android and the web form. SwiftUI has no simple hook for a swipe
attempt on a sheet; refusing the swipe while text is typed is the standard SwiftUI behaviour and
protects the text (spec updated accordingly).

**Alternatives considered**: a UIKit presentation delegate to ask on swipe (rejected: UIKit bridge
for one gesture, against Principle I); a system `Form` (rejected: audit, see R4).

## R14. A fake Monica that holds vaults

**Decision**: `FakeMonica` gains an in-memory list of vaults in its settings and answers
`GET /api/v1/vaults` (paged with `page` and `per_page`, `meta.total`), `GET /api/v1/vaults/{id}`
(404 when unknown) and `POST /api/v1/vaults` (JSON body; 422 with the free plan's message when
`vaultLimit` is reached or the name is blank; first vault becomes default; `is_default: true` moves
the badge). `Request` gains `body: Data` so JSON bodies are readable. New UI test scenarios:
`withVaults` (three vaults, the first default), `manyVaults` (150), `vaultLimit` (one vault, limit
one), `vaultsUnreachable` (the vault list fails, the rest works), `slowVaults` (the list answers
after two seconds, to see the loading state). `compatible` starts with no vault, like every new
account. `launchApp` and `logIn` wait for "All your vaults" instead of the greeting.

**Rationale**: The existing way to test against the network (see `docs/testing.md`), extended.

## R15. Strings

**Decision**: Keys shared with the Android feature (its `contracts/ui.md`), so both apps say the
same thing, with these iOS differences: `account_log_out` ("Log out", the iOS wording kept from the
placeholder home, replacing `home_log_out`), `account_connected` (replaces `home_connected`), the
plural `vault_contacts` uses the String Catalog's zero/one/other variations ("No contacts", "%lld
contact", "%lld contacts"), and the card has no spoken label of its own: VoiceOver reads its visible
texts in order ("Personal, 25 contacts, Default", `.accessibilityElement(children: .combine)`), so
what is heard cannot drift from what is shown. Removed: `home_greeting`, `home_greeting_no_name`, `home_title` if present. French reuses
`lang/fr_FR.json` ("Aucun coffre pour l’instant", "Par défaut") and Android's French otherwise.

## R16. What the API does not give (FR-011)

**Decision**: No "Opened …" line, no faces, no open tasks or dates this month. The card's second
line is the contact count.

**Rationale**: Clarification carried over from Android. When Monica exposes them, a later feature
adds them on both apps.
