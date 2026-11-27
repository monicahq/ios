# Research: Welcome Screen

## R1. View model or not (superseded by R11)

- **Decision**: no view model. `MonicaApp` shows a stateless `WelcomeScreen(instanceHost:,
  onSignUp:, onLogIn:, onInstanceSettings:)` with empty closures and the host of the default
  instance.
- **Rationale**: the screen has no state, no data source and no event to handle (FR-005).
  Principle I forbids an abstraction without a consumer; principle II's split is respected because
  the screen is already the stateless half, and the stateful half (route + view model) arrives
  with the instance sheet, the first feature that has state.
- **Alternatives considered**: a `WelcomeViewModel` holding the host: rejected, it would hold a
  constant.

## R2. Colours: Monica tokens in the asset catalog

- **Decision**: one colour set per Monica token in `Assets.xcassets/Colors`, each with a light and
  a dark value, used through the symbols Xcode generates
  (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`):

  | Monica token | Colour set | Light | Dark |
  | --- | --- | --- | --- |
  | page / canvas | `Page` | `#FFFFFF` | `#09090B` |
  | ink | `Ink` | `#09090B` | `#FAFAFA` |
  | muted | `Muted` | `#71717A` | `#A1A1AA` |
  | primary | `PrimaryFill` | `#18181B` | `#FAFAFA` |
  | on-primary | `OnPrimaryFill` | `#FAFAFA` | `#18181B` |
  | hairline-strong | `HairlineStrong` | `#D4D4D8` | `#3F3F46` |
  | hairline | `Hairline` | `#E4E4E7` | `#27272A` |
  | card | `Card` | `#FAFAFA` | `#18181B` |

  `primary` becomes `PrimaryFill` because a `Primary` colour set would clash with SwiftUI's
  `Color.primary`.
- **Rationale**: the platform's own way to declare appearance-dependent colours; no code to switch
  palettes, and the values match the Android app's. Contrast of these pairs is measured in the
  design system (ink, muted ≥ 4.5:1 on page in both themes) and checked by the accessibility audit.
- **Alternatives considered**: colours built in code with `UIColor(dynamicProvider:)`: rejected,
  more code for the same result.
- **Deviation from the design**: the outlined "Log in" button is drawn with `Muted` instead of
  `HairlineStrong`, which is only 1.5:1 (light) and 1.9:1 (dark) against the page, below the 3:1
  that principle VII requires for controls. No token between the two reaches 3:1. Its pressed fill
  is `Hairline` so the press is visible.

## R3. Typography: system text styles

- **Decision**: the system font with the text styles closest to the design: title `.title`
  semibold (28 pt at the default size, as in the design), description `.body`, buttons `.body`
  medium, instance line `.footnote` with the host in `Ink` medium, wordmark 30 pt semibold scaled
  with `@ScaledMetric(relativeTo: .largeTitle)`.
- **Rationale**: no webfont is a design system rule, and text styles follow Dynamic Type
  (principle VII). Sizes differ from the design by a point at most (17 pt body instead of 16),
  which is the iOS convention.
- **Alternatives considered**: fixed sizes copied from the design: rejected, they would not follow
  the person's text size.

## R4. Images and icons

- **Decision**:
  - `assets/logo.svg` → `Logo.imageset/Logo.svg`, rebuilt from the Android vector, with
    "preserve vector data" on and the original colours (the mark is never recoloured). Hidden from
    VoiceOver, since "Monica" is written next to it.
  - The settings and instance glyphs become SF Symbols: `gearshape` in a 44 pt button, and
    `server.rack`, hidden from VoiceOver.
  - `assets/panda-welcome.png` → `PandaWelcome.imageset/PandaWelcome.heic` (69 KB, converted from
    the Android app's WebP; asset catalogs do not take WebP), full width, aspect ratio 880:530,
    filled and clipped, edges faded with an `EllipticalGradient` mask (opaque to 62% of the
    radius).
- **Rationale**: SF Symbols scale with the text size and match the system's look; one bitmap only.
- **Alternatives considered**: copying the design's glyphs as SVGs: rejected, they would not
  follow Dynamic Type.

## R5. Layout that fills tall screens and scrolls on small ones

- **Decision**: a `ScrollView` inside a `GeometryReader`; its content is a `VStack` with
  `frame(minHeight: proxy.size.height)`, split into a top group (settings button, logo,
  illustration, texts) and a bottom group (buttons, instance line) separated by a `Spacer`.
  `scrollBounceBehavior(.basedOnSize)` keeps the screen still when everything fits.
- **Rationale**: matches the design's `flex:1` spacer on tall screens and meets FR-012 (scroll, no
  clipping) at large text sizes and in landscape. Safe areas are respected by default.

## R6. Languages and per-app language

- **Decision**: one String Catalog, `Monica/Resources/Localizable.xcstrings`, English as source
  language and French, with the Android app's keys (`welcome_title`...). Views use the keys
  (`Text("welcome_title")`). The instance line is one format string (`Instance: %@` /
  `Instance : %@`, with the French non-breaking space) and the host is styled by locating it in
  the formatted text (`highlight`).
- **Rationale**: Xcode compiles the catalog into `en.lproj` and `fr.lproj`, which is what iOS reads
  to offer the app's Language setting (FR-009) and to fall back to English for any other language
  (FR-007). Shared keys make it easy to compare both apps' translations.
- **Alternatives considered**: English text as keys (the Xcode default): rejected, the keys would
  differ from Android's and change whenever the English text does.

## R7. Keeping languages in step

- **Decision**: a unit test (`LocalizationParityTests`) decodes the catalog from the source tree
  and fails when a key has no translated value in a supported language, or when a translation's
  placeholders differ from English.
- **Rationale**: principle VI requires every language to be updated in the same pull request. iOS
  shows the raw key when a language lacks it (it does not fall back to English per key), so the
  test also covers texts that are the same in every language, like the product name.

## R8. Testing in French, in dark mode and with the largest text size

- **Decision**: UI tests launch the app with `-AppleLanguages (fr) -AppleLocale fr`, with
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`, or after
  `XCUIDevice.shared.appearance = .dark`.
- **Rationale**: no need to change the simulator's settings; tests stay independent.

## R9. Automated accessibility checks

- **Decision**: `XCUIApplication.performAccessibilityAudit()` in light and dark, plus explicit
  tests for what the audit does not cover: the logo is hidden, controls are at least 44 pt, every
  control is reachable at the largest text size.
- **Rationale**: required by principle VII and `docs/accessibility.md`; the audit checks
  descriptions, contrast, hit regions, Dynamic Type and clipped text with Apple's own rules.
  XCUITest does not expose traits, so the header trait of the title is checked by the
  `accessibility-reviewer` agent and the manual VoiceOver pass.

## R10. Coverage gate

- **Decision**: `scripts/check-coverage.sh` reads the unit tests' result bundle with
  `xcrun xccov view --report --json` and `jq`, keeps the app target's files except views
  (`MonicaApp.swift`, `*Screen.swift`, `*View.swift`, `Theme/`) and fails under 80% line coverage.
  The CI "Unit tests" job runs it after the tests, so the required checks of the `main` ruleset do
  not change.
- **Rationale**: closes the constitution's `TODO(COVERAGE_GATE)`. Unit tests are hosted in the
  app, so they also execute view code; measuring it would hide untested logic behind view lines.
- **Alternatives considered**: a separate "Coverage" CI job: rejected, it would need a ruleset
  change for no benefit.

## R11. State of the screen once the instance sheet exists (User Story 4)

- **Decision**: R1 no longer holds: the screen now has state (the saved address, whether the sheet
  is open, the draft, the error). `WelcomeViewModel` (`@Observable`, `@MainActor`) exposes one
  `WelcomeUiState` (`instanceURL`, `sheet: InstanceSheetState?`) and one method per event.
  `WelcomeRoute` owns it and passes the state and closures to the stateless `WelcomeScreen`, which
  presents the sheet with `.sheet(isPresented:)` bound to `state.sheet != nil`; pulling the sheet
  down calls the same dismiss event as Cancel.
- **Rationale**: principle II's reference shape, and the same state as the Android app's
  `WelcomeUiState`, so both apps behave alike.

## R12. Storing the address: `UserDefaults`

- **Decision**: one key `instance_url` in `UserDefaults`, behind a `@MainActor`
  `InstanceRepository` (`url`, `setURL(_:)`) that receives its `UserDefaults` in its initializer.
  Absent key = default. Synchronous: `UserDefaults` keeps values in memory and writes in the
  background, so reading one string does not block the main actor, and the screen shows the saved
  address on its first frame instead of flashing the default.
- **Tests**: a real `UserDefaults` in a suite of its own per test (unit tests), and per launch (UI
  tests, through `MONICA_DEFAULTS_SUITE`, read in Debug only). No protocol and fake: they would
  exist only for the tests (principle I), and the real store is as fast.
- **Alternatives considered**: SwiftData: far too much for one string. Keychain: the address is
  not a secret.

## R13. Normalising and validating the address

- **Decision**: a pure function `normalizeInstanceURL(_:) -> String?` in `Instance/Instance.swift`,
  the same rule as the Android app: trim; empty → default; any space → refused; no `://` → prefix
  `https://`; remove trailing slashes; refused unless `URLComponents` finds an `http`/`https`
  scheme and a host. The view model keeps the sheet open with `isError` when it returns nil.
- **Rationale**: unit tested without UI; same addresses accepted on both platforms.

## R14. Sheet layout and accessibility

- **Decision**: drawn as in the design: title (header trait), explanation, visible "Address" label
  above a bordered field, error line, then "Reset to default", "Cancel" (text buttons) and "Save"
  (filled) side by side, stacked at accessibility text sizes. Full height, opaque `Card`
  background, visible grabber. The field wraps (`axis: .vertical`, URL keyboard, no
  autocapitalisation or autocorrection); a new line typed with Return is removed and means Save.
  The error is a sentence with an icon in `Ink` (not colour alone), also the field's hint, and
  announced with `AccessibilityNotification.Announcement`. The field's border is `Muted`, not the
  design's hairline, for 3:1.
- **Rationale**: `performAccessibilityAudit()` on iOS 26 fails a system `Form` with Cancel and
  Save in the navigation bar (bar buttons do not fully follow Dynamic Type; glass background
  fails contrast), half-height sheets (text reported as clipped) and single-line fields (long
  address clipped). The chosen layout passes the audit in light, dark and with the error.
- **Alternatives considered**: `Form` in a `NavigationStack` with toolbar buttons, the usual iOS
  sheet: rejected for the audit failures above. `ViewThatFits` for the buttons: rejected, the
  audit reports Dynamic Type as partially unsupported inside it.
