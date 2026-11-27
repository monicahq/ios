# Contract: Screens, accessibility and strings

Design reference: `Vaults Android.dc.html` (Claude Design project `c63853f6-…`), frames "iOS · With
vaults" and "iOS · Empty state". Colours come from the asset catalog symbols (`Color.groupedPage`,
`Color.ink`, `Color.vaultBlue`…), never raw values. Text uses system text styles, so it follows
Dynamic Type; sizes in pt below are the default-size reference only.

## Navigation (`Vaults/VaultsScreen.swift`, `VaultsRoute`)

| Where | Shows | Leaves by |
|---|---|---|
| `NavigationStack` root | `VaultsScreen` | — |
| push `VaultDestination(id:)` | `VaultRoute` → `VaultScreen` | system Back, edge swipe |
| sheet | `AccountSheetView` (the existing `InstanceSheetView` opens over it) | its own Close, swipe |
| sheet | `NewVaultRoute` → `NewVaultScreen` | Cancel (asks when text is typed), swipe only when nothing typed |

`RootView` shows `VaultsRoute` when signed in, in place of `HomeRoute`.

## VaultsScreen (stateless)

```text
VaultsScreen(
  state: VaultsUiState, initials: String?,
  onVaultTap: (Vault.ID) -> Void, onNewVault: () -> Void,
  onRefresh: () async -> Void, onTryAgain: () -> Void, onDismissRefreshMessage: () -> Void,
  onAccount: () -> Void
)
```

Layout, from the design:

- **Background** `groupedPage`, system navigation bar hidden.
- **Top bar** (in `.safeAreaInset(edge: .top)`), 16 pt side margins, 52 pt high: account button on
  the left (44 pt circle, 36 pt disc with the initials in `subheadline` semibold, or the
  `person.fill` symbol; floating style of research R8), the Monica logo centred (28 × 25, from the
  existing logo asset, decorative), an empty 44 pt slot on the right for balance. Behind it, a
  gradient from `groupedPage` to clear, so cards fade under it.
- **Title** "All your vaults", `largeTitle` bold, header trait, 20 pt from the sides, in every
  state.
- **Card** (`GroupedCard` fill, 26 pt continuous corners, 16 pt side margins, 16 pt between cards,
  18 pt padding): 44 pt rounded square (12 pt corners) in the vault's tint with the initial in its
  colour (`headline`); name (`headline`, wraps); contact line (`subheadline`, `groupedMuted`); the
  "Default" pill (`footnote` medium, `ink` on a `hairline` capsule, min height 24 pt) at the top
  right on the default vault. No faces, no footer (FR-011). With the accessibility text sizes, the
  pill moves under the name instead of squeezing it.
- **"New vault"** floating at the bottom centre (in `.safeAreaInset(edge: .bottom)`, so the last
  card scrolls clear of it), `plus` symbol + label, `headline`, min height 52 pt, floating style of
  research R8. Not shown in the empty, loading and failed states.
- **Refresh message** (research R10): above the cards, `exclamationmark.circle` + "Your vaults could
  not be updated." + a dismiss button ("Dismiss"), announced when it appears.
- **Empty**: centred 64 pt tile (`GroupedCard`, 18 pt corners) with the vault symbol
  (`archivebox`, decorative), "No vault yet" (`title2` bold, header trait), the explanation (`body`,
  `groupedMuted`, centred), and a "New vault" button in `PrimaryButtonStyle` (not floating).
- **Loading**: centred `ProgressView` with the label "Loading your vaults" (visible text under it).
- **Failed**: the error's message and a "Try again" button (`OutlinedButtonStyle`).

Accessibility:

- Each card: one `Button`, `.accessibilityElement(children: .combine)`: "Personal, 25 contacts,
  Default", button trait. The initial square is hidden (the name is read). Activating opens the
  vault.
- The title and each card carry `.accessibilityAction(named: "Refresh")` → `onRefresh` (VoiceOver
  reads actions of the focused element, so a container action would not be reached).
- Reading order: account button, title, refresh message, cards, "New vault".
- Account button label "Your account", hint none, button trait.
- When the list replaces the welcome screen after sign-in, VoiceOver focus moves to the title
  (as the placeholder home did with its greeting).

## VaultScreen (stateless, placeholder)

`VaultScreen(state: VaultUiState, onTryAgain: () -> Void, onBackToList: () -> Void)`

System navigation bar, standard Back, inline title = vault name when loaded. Content on
`groupedPage`: the 64 pt square with the initial, the name (`title` bold, header trait), the
description (`body`) when not blank. `notFound`: "This vault no longer exists." and a "Back to your
vaults" button (pops; the list reloads on reappearing). `failed`: message + "Try again". `loading`:
the progress view with "Loading".

## NewVaultScreen (stateless)

```text
NewVaultScreen(
  state: NewVaultUiState,
  onNameChange, onDescriptionChange, onColourChoose, onMakeDefaultToggle,
  onCreate, onCancel, onConfirmDiscard, onKeepEditing
)
```

- Full-height sheet on `groupedCard` (as the instance sheet), `.interactiveDismissDisabled(state
  .hasTypedSomething)`.
- Header row: "Cancel" (`TextButtonStyle`) on the left, title "New vault" (`title3` semibold,
  header trait) under it.
- "Name" field (required; focused when the sheet opens; submit moves to Description), the error
  text under it, read right after the field and announced when it appears.
- "Description (optional)" multi-line field (`axis: .vertical`, 3–6 lines), error under it.
- "Colour": header text, then a wrapping row (`LazyVGrid` adaptive 44 pt) of eight 44 pt circles
  in the swatch colour, each a `Button` labelled with its colour name, `isSelected` trait on the
  selected one, which also shows a `checkmark` in white/ink drawn on it (not colour alone). Error
  under the group.
- "Make this the default vault": a `Toggle`, only when `offersDefault`.
- General error (a refusal not tied to a field, or the connection error) above the button, with
  `exclamationmark.circle`, announced when it appears.
- "Create vault" in `PrimaryButtonStyle`, disabled unless `canCreate`; while saving, a
  `ProgressView` and "Creating…" in it.
- Discard confirmation: an alert (an iOS 26 action sheet hides its cancel button) "Discard this
  vault?" / message "What you typed will be lost." / "Discard" (destructive) / "Keep editing"
  (cancel). The VoiceOver escape gesture goes through Cancel.
- Disabled "Create vault": `PrimaryButtonStyle` draws a disabled button grey (`hairline`) with an
  `ink` label, readable at 4.5:1, rather than dimmed.

## AccountSheetView (stateless)

`AccountSheetView(state: AccountUiState, onClose, onLogOut, onConfirmLogOut, onCancelLogOut,
onOpenInstanceSheet, …instance sheet events…, onConfirmSwitch, onCancelSwitch)`

Full-height sheet on `groupedCard`, laid out as the instance sheet: "Close" (`TextButtonStyle`), the
name (`title2` semibold, header trait; "Your account" when the name is empty), the
`server.rack` + "Connected to {host}" button (hint "Instance settings") that opens the existing
`InstanceSheetView` over this sheet, the message of `state.message` when any, and "Log out"
(`OutlinedButtonStyle`) with the existing alert (`log_out_title`, `log_out_message`). Switching
instance uses the existing alert. These are the placeholder home's controls, moved unchanged.

## Strings (English / French)

Keys shared with Android where the text is the same. French from `lang/fr_FR.json` when the text
exists there, otherwise Android's French.

| Key | English | French |
|---|---|---|
| `vaults_title` | All your vaults | Tous vos coffres |
| `vaults_loading` | Loading your vaults | Chargement de vos coffres |
| `vaults_empty_title` | No vault yet | Aucun coffre pour l’instant |
| `vaults_empty_body` | A vault holds the people you want to remember, with their notes, dates and reminders. Start with one for yourself; you can share it or add others later. | Un coffre réunit les personnes dont vous voulez vous souvenir, avec leurs notes, leurs dates et leurs rappels. Commencez par un coffre pour vous ; vous pourrez le partager ou en ajouter d’autres plus tard. |
| `vaults_new` | New vault | Nouveau coffre |
| `vaults_refresh` | Refresh | Actualiser |
| `vaults_refresh_failed` | Your vaults could not be updated. | Vos coffres n’ont pas pu être mis à jour. |
| `vaults_dismiss` | Dismiss | Fermer |
| `vaults_try_again` | Try again | Réessayer |
| `vault_default` | Default | Par défaut |
| `vault_contacts` (plural, `%lld`) | zero: No contacts · one: %lld contact · other: %lld contacts | zero: Aucun contact · one: %lld contact · other: %lld contacts |
| `vault_loading` | Loading | Chargement |
| `vault_not_found` | This vault no longer exists. | Ce coffre n’existe plus. |
| `vault_back_to_list` | Back to your vaults | Retour à vos coffres |
| `account_button` | Your account | Votre compte |
| `account_connected` | Connected to %@ | Connecté à %@ |
| `account_log_out` | Log out | Déconnexion |
| `account_close` | Close | Fermer |
| `new_vault_title` | New vault | Nouveau coffre |
| `new_vault_name` | Name | Nom |
| `new_vault_description` | Description (optional) | Description (facultatif) |
| `new_vault_colour` | Colour | Couleur |
| `new_vault_make_default` | Make this the default vault | Faire de ce coffre le coffre par défaut |
| `new_vault_create` | Create vault | Créer le coffre |
| `new_vault_creating` | Creating… | Création… |
| `new_vault_cancel` | Cancel | Annuler |
| `new_vault_discard_title` | Discard this vault? | Abandonner ce coffre ? |
| `new_vault_discard_message` | What you typed will be lost. | Ce que vous avez saisi sera perdu. |
| `new_vault_discard` | Discard | Abandonner |
| `new_vault_keep_editing` | Keep editing | Continuer |
| `colour_blue` … `colour_graphite` | Blue, Green, Ochre, Rust, Violet, Teal, Rose, Graphite | Bleu, Vert, Ocre, Rouille, Violet, Bleu canard, Rose, Graphite |

Removed: `home_greeting`, `home_greeting_no_name`, `home_connected` (→ `account_connected`),
`home_log_out` (→ `account_log_out`). Kept and reused: `log_out_title`, `log_out_message`,
`instance_switch_*`, `instance_sheet_*`, `welcome_instance_settings`, every `auth_error_*`.

## UI tests (`MonicaUITests`)

| File | Covers |
|---|---|
| `VaultsScreenUITests` | list (names, counts, one Default, order), empty state, loading (`slowVaults`), failed + Try again (`vaultsUnreachable`), refresh by pull and by the Refresh action, 150 vaults (last one reachable), largest accessibility text size, French, dark, audit in each state |
| `VaultScreenUITests` | open from a card, name and description, Back keeps the place, not found + Back to your vaults, audit |
| `NewVaultScreenUITests` | create from empty state (becomes Default), create from the list (appears at the end), blank name disables Create, make default moves the badge, refusal at the ceiling (`vaultLimit`) keeps values, Cancel with text asks, Cancel without text closes, colour selection read by VoiceOver labels, audit |
| `AccountSheetUITests` (replaces `HomeScreenUITests`) | name and instance, initials, log out after confirming, instance settings opens the instance sheet, audit |
| `SignInJourneyUITests`, `MonicaAppUITests` | updated to land on "All your vaults" |
