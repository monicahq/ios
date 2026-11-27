# Quickstart: validating the vault list

How to prove the feature works, automatically and by hand. What each screen shows is in
[contracts/ui.md](contracts/ui.md); the calls are in [contracts/monica-api.md](contracts/monica-api.md).

## Prerequisites

- `mise install` (XcodeGen, SwiftFormat, SwiftLint), Xcode 27.2 with the iOS 26.1 iPhone 17
  simulator (the default "iPhone 17").
- For the manual checks: a Monica instance (the official one or `../monica` running locally) with
  an account you can sign in to, and a second account that holds no vault.

## Automated

```sh
xcodegen generate && swiftformat . && swiftlint --strict
rm -rf build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MonicaTests \
  -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MonicaUITests/VaultsScreenUITests -only-testing:MonicaUITests/VaultScreenUITests \
  -only-testing:MonicaUITests/NewVaultScreenUITests -only-testing:MonicaUITests/AccountSheetUITests \
  -only-testing:MonicaUITests/SignInJourneyUITests
```

Expected: everything green, coverage at least 80%, the accessibility audit passing in every state.

## Manual scenarios

| # | Do | Expect | Spec |
|---|---|---|---|
| 1 | Log in with an account holding several vaults | "All your vaults", the vaults in the web's order, counts, one "Default" | US1 |
| 2 | Quit and reopen the app | The list again, no sign-in | US1 |
| 3 | Rename a vault on the web, pull the list down | The new name | US1.5 |
| 4 | Tap a vault, then Back | Its name and description; back at the same scroll position | US1.6 |
| 5 | Log in with the account holding no vault | Empty state; "New vault" opens the form | US2 |
| 6 | Create a vault from the empty state | Back on the list, the vault marked "Default" | US2.3 |
| 7 | Type a name, tap Cancel; then swipe the sheet down | Cancel asks; the swipe does not close it | US3.6 |
| 8 | On a free-plan account at its ceiling, create a vault | The instance's message under Name, values kept | US3.4 |
| 9 | Airplane mode, pull the list | List kept, "Your vaults could not be updated." | Edge cases |
| 10 | Tap the initials, Log out, confirm | Welcome screen | US4 |
| 11 | Dark mode; Reduce Transparency; Increase Contrast | Night blue palette; account button and "New vault" solid; everything readable | US5 |
| 12 | Largest accessibility text size | Cards grow, "Default" moves under the name, the last card clears "New vault" | FR-023 |
| 13 | VoiceOver: reach a vault, create one, log out | Each card read "Name, N contacts, Default"; Refresh in the actions; colours read by name and "Selected" | SC-005 |
| 14 | Phone in French | No English text | SC-006 |

The pull request states how 11–13 were checked (constitution VII) and includes screenshots of the
list, the empty state and the form in light and dark (`take-screenshot` skill).
