# UI Contract: WelcomeScreen

```swift
struct WelcomeScreen: View {
    let instanceHost: String
    let onSignUp: () -> Void
    let onLogIn: () -> Void
    let onInstanceSettings: () -> Void
}
```

Stateless. Renders exactly what it is given and reports taps through the closures; it never
decides what a tap does. In this feature `MonicaApp` passes `instanceHost(defaultInstanceURL)` and
empty closures.

## Elements, top to bottom

| Element | Accessibility (what VoiceOver and UI tests see) | Closure |
| --- | --- | --- |
| Instance settings button | Button, labelled `welcome_instance_settings`, 44 × 44 pt, SF Symbol `gearshape` | `onInstanceSettings` |
| Logo | Hidden (decorative) | none |
| "Monica" wordmark | Static text `app_name` | none |
| Illustration | Image, labelled `welcome_illustration` | none |
| Title | Static text `welcome_title`, header trait | none |
| Description | Static text `welcome_description` | none |
| Sign up | Button, label `welcome_sign_up`, filled, at least 56 pt high | `onSignUp` |
| Log in | Button, label `welcome_log_in`, outlined, at least 56 pt high | `onLogIn` |
| Instance line | Button, label `welcome_instance` with the host, hint `welcome_instance_settings`; its SF Symbol `server.rack` is hidden | `onInstanceSettings` |

## Instance helpers

```swift
let defaultInstanceURL = "https://app.monicahq.com"
func instanceHost(_ url: String) -> String
```

`instanceHost` follows the derivation rule of [data-model.md](../data-model.md#instance).
