# Quickstart: validate the Welcome Screen

## Prerequisites

- Xcode (latest stable) with an iOS 18 or later iPhone simulator
- `mise install`, then `xcodegen generate`

## Automated checks

```bash
DEST='platform=iOS Simulator,name=iPhone 17'
swiftformat --lint . && swiftlint --strict
rm -rf build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" \
  -only-testing:MonicaTests -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" -only-testing:MonicaUITests
```

Expected: everything passes, including the string-parity test, the coverage gate and the
accessibility audits of `WelcomeScreenUITests`.

## Manual checks

1. Run the app (Xcode, or the `take-screenshot` skill's commands): the welcome screen matches the
   design (see [contracts/welcome-screen.md](contracts/welcome-screen.md) for the element order).
2. Tap every control: nothing happens, the screen stays.
3. Dark mode (`xcrun simctl ui booted appearance dark`): the screen uses the dark palette and stays
   readable.
4. French: Settings > Apps > Monica > Language > Français, or set the device to French. Every text
   is French, including "Instance : app.monicahq.com".
5. An unsupported language (German): every text is English.
6. VoiceOver (or the Accessibility Inspector): swipe through the screen; order and announcements
   follow the contract table; the logo is skipped; the title is announced as a heading.
7. Largest text size with accessibility sizes, then landscape: nothing is cut or overlapping, the
   buttons are reachable by scrolling.
8. Compare with the design, light and dark (`take-screenshot` skill).
