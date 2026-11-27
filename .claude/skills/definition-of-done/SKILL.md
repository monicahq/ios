---
name: definition-of-done
description: The checklist a change passes before it is committed or put in a pull request. Formatting, SwiftLint, unit tests, builds, documentation and the features list. Use before every commit, before every pull request, and when asked whether a change is finished.
---

# Definition of done

CI runs every check below on each pull request. A change that passes its own tests alone can still
land a red pull request, so run the whole list.

Run this before every commit and before every pull request. Work through the items in order. When a
check fails, fix it, then start again from that check.

```bash
DEST='platform=iOS Simulator,name=iPhone 17'
```

## 1. Find what changed

```bash
git diff --name-only main...HEAD
git status --short
```

When `project.yml` changed, or files were added or removed, regenerate the project first:
`xcodegen generate`.

## 2. Unit tests

Every changed view model, repository, mapper or non-UI type has a Swift Testing suite in
`MonicaTests`, in the matching folder, following the `tests` skill and `docs/testing.md`. A changed
type with no test fails this step.

```bash
rm -rf build/unit-tests.xcresult
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" -only-testing:MonicaTests \
  -resultBundlePath build/unit-tests.xcresult
scripts/check-coverage.sh build/unit-tests.xcresult
```

`check-coverage.sh` fails when non-UI line coverage drops below 80%. Keep logic out of
`*Screen.swift` files (they are excluded from the measure) and unit test it.

## 3. Screens

There are no UI tests (never add any). Every changed screen is stateless: each state it draws comes
from a `UiState` a view model test asserts, and it has `#Preview`s of its states in light and dark.
Check it by hand on a simulator against a real instance (the `take-screenshot` skill). When you cannot, say so explicitly in the summary of the change.

Skip this step when the change touches no Swift under `Monica/` and no resource.

## 4. Formatting

```bash
swiftformat .
```

Commit the formatting changes with the change itself.

## 5. SwiftLint

```bash
swiftlint --strict
```

No warning. A new warning is fixed rather than disabled; a `swiftlint:disable` carries a comment
saying why.

## 6. Builds

```bash
xcodebuild build -project Monica.xcodeproj -scheme Monica -configuration Debug \
  -destination 'generic/platform=iOS Simulator'
xcodebuild build -project Monica.xcodeproj -scheme Monica -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

The release build runs with optimisations and without testability: code that only compiles thanks
to `@testable` or `DEBUG` shows up here, not in debug. Delete `DerivedData` before running tests
again afterwards: the unsigned build leaves products the simulator refuses to load.

## 7. Strings and accessibility

Every user-visible text is in `Monica/Resources/Localizable.xcstrings` and translated in every
supported language (constitution, principle VI).

Accessibility is mandatory (principle VII). Follow the `accessibility` skill: the
`accessibility-reviewer` agent has reviewed the change and its
confirmed findings are fixed, and the manual checks of `docs/accessibility.md` are done or
explicitly reported as not done.

## 8. Documentation

- `docs/FEATURES.md` has a line for each feature or improvement a person will notice, following the
  `feature-documentator` skill.
- `README.md` and `docs/` are updated when the change alters how the app is built, configured or
  used. Public types and non-obvious functions have `///` comments saying *why*.

## 9. Constitution

The change respects `.specify/memory/constitution.md`: simplest solution, official Apple
architecture, unit tests and no UI tests, native only. A deviation is justified in the feature's `plan.md`.

## 10. Commit

Follow the `commits` skill: Conventional Commits with a scope, on a dated branch, and no mention of
Claude anywhere.
