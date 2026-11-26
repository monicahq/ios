---
name: take-screenshot
description: Take a screenshot of the app running on an iOS simulator. Use whenever a task requires taking, inspecting or validating a screenshot of the app, in particular for a pull request that changes anything visible.
---

# Take a screenshot

Screenshots are temporary review artifacts. They MUST stay outside the repository: write them to
`/tmp/<feature>.png` and attach them to the pull request (see the `commits` skill).

## 1. Have a simulator

```bash
xcrun simctl list devices available | grep iPhone
xcrun simctl boot "iPhone 17"
open -a Simulator
```

When `iPhone 17` names several devices (one per installed iOS version), use its UDID instead.

## 2. Install the branch's build

```bash
xcodegen generate
xcodebuild build -project Monica.xcodeproj -scheme Monica \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Monica.app
xcrun simctl launch booted com.monicahq.ios
```

The screenshot MUST show the screen as the branch draws it. Never capture the screen as it was
before the change: reviewers read the diff for that.

## 3. Capture

Navigate to the screen and state to show, then:

```bash
xcrun simctl io booted screenshot /tmp/<feature>.png
```

- Capture one shot per screen or per state (empty, loading, content, error) the change touches.
- When the change affects dark mode, also capture it:
  `xcrun simctl ui booted appearance dark`, capture, then `xcrun simctl ui booted appearance light`.
- For another language, relaunch with
  `xcrun simctl launch booted com.monicahq.ios -AppleLanguages '(fr)' -AppleLocale fr_FR`.
- Open the image with the Read tool to check it shows what you expect before using it.
