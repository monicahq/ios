# Monica for iOS

The iOS version of [Monica](https://github.com/monicahq/monica), the open source personal CRM.
It aims to offer every feature of the web app, plus what only makes sense on a phone, and talks to
any Monica instance through its public API. Written in Swift with SwiftUI.

## Requirements

- Xcode (latest stable) with an iOS 18 or later simulator
- [mise](https://mise.jdx.dev), which installs the pinned XcodeGen, SwiftFormat and SwiftLint
  (`mise install`)

The Xcode project is generated from `project.yml` and is not committed. Generate it after cloning,
after pulling, and whenever `project.yml` changes:

```sh
mise install
xcodegen generate
open Monica.xcodeproj
```

## Common commands

```sh
DEST='platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project Monica.xcodeproj -scheme Monica -destination "$DEST"   # build
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" \
  -only-testing:MonicaTests                                                       # unit tests
xcodebuild test -project Monica.xcodeproj -scheme Monica -destination "$DEST" \
  -only-testing:MonicaUITests                                                     # UI tests
swiftlint --strict                                                                # lint
swiftformat .                                                                     # format
```

## Principles

The project rules are in the [constitution](.specify/memory/constitution.md). In short: simple code,
official Apple best practices, everything unit tested, every screen UI tested, native iOS only.

- [Architecture](docs/architecture.md): how screens, view models and repositories fit together
- [Testing](docs/testing.md): what to test and how
- [Accessibility](docs/accessibility.md): mandatory rules and checks for every screen

## Spec-driven development

This repo uses [Spec Kit](https://github.com/github/spec-kit):

1. `/speckit-constitution`: project principles (once)
2. `/speckit-specify`: describe a feature (it first updates `main` and creates a dated branch from it)
3. `/speckit-clarify` (optional), then `/speckit-plan`
4. `/speckit-tasks`, then `/speckit-implement`

Specs live in `specs/`, the constitution in `.specify/memory/constitution.md`.
