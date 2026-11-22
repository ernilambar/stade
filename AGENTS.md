# AGENTS.md

## Overview

A macOS SwiftUI app that manages background scripts as launch agents: add,
edit, remove, start, stop, and read logs without an external process manager.
Swift 5.9+, SwiftUI/AppKit, macOS 15+ on Apple Silicon, no third-party
dependencies.

## Setup

Swift Package Manager builds the app with the Command Line Tools alone; Xcode
is not needed. There is no Xcode project.

```sh
xcode-select --install   # once, if `swift --version` fails
swift test
./scripts/dev.sh
```

No dependencies to install. `swift build` produces a bare binary;
`scripts/bundle.sh` wraps it into `build/<config>/<APP_NAME>.app` (icon via
`iconutil`, `Info.plist` written from `Config/App.xcconfig`, ad-hoc signed).
The `Release` workflow publishes `Stade-macos-arm64.zip` from a `v*` tag.

## Commands

- Build: `swift build`
- Test: `swift test` (swift-testing; XCTest is unavailable without Xcode)
- Lint: `shellcheck scripts/*.sh`; Swift warnings fail CI (`-warnings-as-errors`).
- Format: none configured; match the surrounding file's style.
- Typecheck: `swift build`
- App bundle: `./scripts/bundle.sh` (`--release` for an optimized build)
- Release package: `make build` (`ZIP_NAME` and `OUTPUT_DIR` override the zip
  name and output directory)
- Install and relaunch: `./scripts/dev.sh` (Debug; `--release` for Release)
- Latest release installer: `./scripts/install.sh`
- Script check: `bash -n scripts/*.sh`

## Release

Version lives only in `Config/App.xcconfig` (`APP_VERSION`, `APP_BUILD`);
`scripts/bundle.sh` writes them into the generated `Info.plist`.

- Bump version: set `APP_VERSION` to the release version; bump `APP_BUILD` if
  needed.
- Do not add or hardcode a version in Swift sources or scripts.
- Tag: the user creates and pushes `v<APP_VERSION>` (for example `v0.2.0`).
  Never commit, tag, or push yourself, and never create, move, or delete tags.
  The `Release` workflow's `verify` job fails when the tag and `APP_VERSION`
  differ, then `build` publishes `Stade-macos-arm64.zip` to the GitHub
  release.
- Rebuild an existing release: the user runs the `Release` workflow manually
  with its `tag` input; it replaces the asset without retagging.
- Local package: `make build` (or `./scripts/build.sh`) writes
  `build/Stade-<version>.zip`; the workflow sets `ZIP_NAME` and `OUTPUT_DIR`
  as shown in `CONTRIBUTING.md`.

## Conventions

- App identity lives only in `Config/App.xcconfig` (`APP_NAME`,
  `APP_BUNDLE_ID`); the Swift module is always `AppCore`. Swift code reads the
  name and bundle ID from `Bundle` via `AppInfo`; never hardcode the product name or slug in sources. Keep plist keys
  vendor-neutral (for example `AppCommand`), not app-named.
- `KeepAlive.SuccessfulExit` implies `RunAtLoad`, so "Start at login: off" is
  implemented by `launchctl disable` after `Launchctl.start`; a disabled job
  keeps its crash restarts but is not loaded at login.
- The plists in `~/Library/LaunchAgents/` are the only source of truth; there is
  no database. Labels are `AppInfo.agentLabelPrefix + name`, logs live under
  `AppInfo.logDirectory`, and removing a script keeps its log.
- All launchd access goes through `Launchctl` and its injectable `Runner`; views
  never shell out. Run launchctl and file I/O off the main actor and publish
  results on it. Treat "already loaded" bootstrap and "not loaded" bootout as
  success.
- Commands run as `/bin/zsh -l -i -c <command>`. Prepend `exec ` only to simple
  commands (no `&&`, `||`, `;`, `|`, `&`, or newlines), and read the user's
  command back from `AppCommand`, never from `ProgramArguments`.
- Write `@StateBox`, never `@State`. In the macOS 27 SDK `@State` is a macro
  whose plugin ships only with Xcode; the `StateBox` alias selects the
  property wrapper so the Command Line Tools build keeps working. Avoid other
  SwiftUI macros (`#Preview`, `@Entry`) for the same reason.
- `Info.plist` keys are added in `scripts/bundle.sh`; there is no plist file.
  The icon is `Resources/AppIcon.iconset` (no asset catalog: `actool` needs
  Xcode). Bundle resources are copied by `bundle.sh`, not by SwiftPM.
- Under `swift test` there is no app bundle, so `AppInfo.bundleID` is empty;
  tests must not assume a real bundle ID.
- Keep the app sandbox off, ad-hoc signing, deployment target 15.0, arm64-only
  builds (`--arch arm64`), and zero third-party dependencies. UI text that
  needs the product name uses `AppInfo.name`; plist and log paths come from
  `LaunchAgentStore`/`AppInfo`.
- Do not commit generated artifacts: `build/`, `.build/`, and `dist/` are
  ignored.

## Quality gate

GitHub Actions is the gate. `CI` runs on every push to `main` and every
non-draft pull request (also manually via `workflow_dispatch`):

- `lint` (ubuntu): `bash -n scripts/*.sh` and `shellcheck scripts/*.sh`.
- `build-and-test` (macos-26): `swift build -Xswiftc -warnings-as-errors`,
  `swift test`, `./scripts/bundle.sh --release`.

`Release` runs `swift test` before packaging. A task is done only when CI
passes; Claude never pushes, so ask the user to push and report the CI result.

Before handing off, run locally from the repository root:

```sh
swift build -Xswiftc -warnings-as-errors
./scripts/bundle.sh
bash -n scripts/*.sh && shellcheck scripts/*.sh
```

`swift test` works locally but, with Command Line Tools 6.4, a run sometimes
fails with `plugin for module 'TestingMacros' not found`; rerun it. That
error is a toolchain bug, not a test failure. Never report tests as passing
from a run that hit it; rely on CI.
