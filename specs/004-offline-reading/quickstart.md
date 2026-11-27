# Quickstart: validating Offline Reading

## Automated

```sh
xcodegen generate && swiftformat . && swiftlint --strict
rm -rf build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MonicaTests \
  -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult
```

Expected: the suites listed in [research.md](research.md) R10 pass; coverage stays at 80% or more.

## By hand (simulator, signed in to a test instance with a few vaults)

| # | Steps | Expected |
|---|---|---|
| 1 | Open the list online. Quit the app from the app switcher. Turn the Mac's network off (simulator has no Airplane Mode). Reopen. | Same vaults at once; "Not up to date. Last updated 1 minute ago." under the title |
| 2 | Turn the network back on, pull the list down. | List refreshed, the line disappears |
| 3 | Offline again, pull down. | Copy stays, "Your vaults could not be updated." and the line |
| 4 | Offline, open a vault never opened before. | Its name, colour, description, and the line |
| 5 | Online, rename a vault on the web, reopen the app. | Old name at once, then the new one, no spinner |
| 6 | Delete a vault on the web, open it from the list copy online. | "This vault no longer exists.", gone from the list |
| 7 | Log out, go offline, reopen; sign in to another account. | Welcome screen; then nothing of the first account |
| 8 | Online, then set the Mac's clock 31 days ahead, offline, reopen. | No copy: the connection error |
| 9 | Fresh sign-in, go offline before the list loads. | The connection error with "Try again", as before |
| 10 | Largest accessibility text size, dark mode, French. | The line wraps, reads "Pas à jour. Mis à jour il y a …" |
| 11 | VoiceOver on: open offline, then go online and pull down. | Line read with the screen; "appears"/"disappears" announced |
| 12 | Accessibility Inspector audit on the list and vault screens, stale state, light and dark. | No issue |

## On a device (Data Protection, backups)

| # | Steps | Expected |
|---|---|---|
| 13 | Load the list, restart the phone, do not unlock, wait for a background launch (or check with Console) | The app reads no copy and erases nothing; after unlocking, the copy is there |
| 14 | Make an encrypted Finder backup, browse it (e.g. with a backup explorer) | No `OfflineCopy` folder |
| 15 | In Xcode's Devices window, download the app container; look into `Library/Application Support/OfflineCopy` | Store present; its protection class is `NSFileProtectionCompleteUntilFirstUserAuthentication` (`FileManager.attributesOfItem`, checked from a debug build) |
