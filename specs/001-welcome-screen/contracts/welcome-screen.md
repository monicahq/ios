# UI Contract: WelcomeScreen

```swift
struct WelcomeRoute: View {
    @State var viewModel: WelcomeViewModel
}

struct WelcomeScreen: View {
    let state: WelcomeUiState
    let onSignUp: () -> Void
    let onLogIn: () -> Void
    let onOpenInstanceSheet: () -> Void
    let onDraftChange: (String) -> Void
    let onResetDraft: () -> Void
    let onDismissInstanceSheet: () -> Void
    let onSaveInstance: () -> Void
}
```

`WelcomeScreen` is stateless: it renders `state` and reports taps through the closures.
`WelcomeRoute` connects it to `WelcomeViewModel`. In this feature `onSignUp` and `onLogIn` do
nothing. `MonicaApp` creates the view model with an `InstanceRepository` over `UserDefaults`.

## Elements, top to bottom

| Element | Accessibility (what VoiceOver and UI tests see) | Closure |
| --- | --- | --- |
| Instance settings button | Button, labelled `welcome_instance_settings`, 44 × 44 pt, SF Symbol `gearshape` | `onOpenInstanceSheet` |
| Logo | Hidden (decorative) | none |
| "Monica" wordmark | Static text `app_name` | none |
| Illustration | Image, labelled `welcome_illustration` | none |
| Title | Static text `welcome_title`, header trait | none |
| Description | Static text `welcome_description` | none |
| Sign up | Button, label `welcome_sign_up`, filled, at least 56 pt high | `onSignUp` |
| Log in | Button, label `welcome_log_in`, outlined, at least 56 pt high | `onLogIn` |
| Instance line | Button, label `welcome_instance` with the host of `state.instanceURL`, hint `welcome_instance_settings`; its SF Symbol `server.rack` is hidden | `onOpenInstanceSheet` |

## Instance sheet (`InstanceSheetView`, shown while `state.sheet` is not nil)

| Element | Accessibility | Closure |
| --- | --- | --- |
| Sheet | Full-height modal sheet with a grabber; pulling it down closes it | `onDismissInstanceSheet` |
| Title | Static text `instance_sheet_title`, header trait | none |
| Explanation | Static text `instance_sheet_description` | none |
| "Address" label | Visible, hidden from VoiceOver (the field carries it) | none |
| Address field | Text field labelled `instance_sheet_address`, value `sheet.draft`, placeholder `instance_sheet_placeholder`, URL keyboard, wraps; hint `instance_sheet_invalid` when `sheet.isError` | `onDraftChange`; Return → `onSaveInstance` |
| Error | Shown when `sheet.isError`: `instance_sheet_invalid` with an icon, announced when it appears | none |
| Reset to default | Button `instance_sheet_reset`, text style | `onResetDraft` |
| Cancel | Button `instance_sheet_cancel`, text style | `onDismissInstanceSheet` |
| Save | Button `instance_sheet_save`, filled | `onSaveInstance` |

## Instance helpers

```swift
let defaultInstanceURL = "https://app.monicahq.com"
func instanceHost(_ url: String) -> String
func normalizeInstanceURL(_ input: String) -> String?
```

Both follow the rules of [data-model.md](../data-model.md#instance).
