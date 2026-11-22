# AGENTS.md

## Overview

A macOS SwiftUI app that manages background scripts as launch agents: add,
edit, remove, start, stop, and read logs without an external process manager.
Swift 5.9+, SwiftUI/AppKit, macOS 13+ on Apple Silicon, no third-party
dependencies.

## Setup

Xcode 15 or later is required; the Command Line Tools alone cannot build this
SwiftUI app (the SwiftUI macro plugin lives in Xcode).

```sh
xcode-select -p
open Stayman.xcodeproj
```

No dependencies to install. Release packaging is done by `make build`; the
`Release` workflow publishes `Stayman-macos-arm64.zip` from a `v*` tag.

## Commands

- Build: `xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Debug build`
- Test: `xcodebuild test -project Stayman.xcodeproj -scheme Stayman`
- Lint: none configured; compiler warnings are the lint gate.
- Format: none configured; match the surrounding file's style.
- Typecheck: `xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Debug build`
- Release package: `make build` (`ZIP_NAME`, `OUTPUT_DIR`, and `CONFIGURATION`
  override the zip name, output directory, and configuration)
- Install and relaunch: `./scripts/dev.sh` (Debug; `--release` for Release)
- Latest release installer: `./scripts/install.sh`
- Project file check: `plutil -lint Stayman.xcodeproj/project.pbxproj`
- Script check: `bash -n scripts/*.sh`

## Release

Version lives only in the Xcode build settings; there is no `Info.plist` file
(plists are generated with `GENERATE_INFOPLIST_FILE = YES`).

- Bump version: set `MARKETING_VERSION` in `Stayman.xcodeproj/project.pbxproj`
  to the release version. There are four occurrences (app and test targets,
  Debug and Release); keep all of them identical.
- Build number: bump `CURRENT_PROJECT_VERSION` in the same file if needed; all
  four occurrences must match.
- Do not add or hardcode a version in Swift sources, scripts, or
  `Config/App.xcconfig`.
- Tag: the user creates and pushes `v<MARKETING_VERSION>` (for example
  `v0.2.0`). Never commit, tag, or push yourself, and never create, move, or
  delete tags. The `Release` workflow's `verify` job fails when the tag and
  `MARKETING_VERSION` differ, then `build` publishes
  `Stayman-macos-arm64.zip` to the GitHub release.
- Rebuild an existing release: the user runs the `Release` workflow manually
  with its `tag` input; it replaces the asset without retagging.
- Local package: `make build` (or `./scripts/build.sh`) writes
  `build/Stayman-<version>.zip`; the workflow sets `ZIP_NAME` and `OUTPUT_DIR`
  as shown in `CONTRIBUTING.md`.

## Conventions

- App identity lives only in `Config/App.xcconfig` (`APP_NAME`, `APP_BUNDLE_ID`,
  `APP_MODULE_NAME`). Swift code reads the name and bundle ID from `Bundle` via
  `AppInfo`; never hardcode the product name or slug in sources. Keep plist keys
  vendor-neutral (for example `AppCommand`), not app-named.
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
- Keep the app sandbox off, ad-hoc signing, deployment target 13.0, arm64-only
  builds (`ARCHS = arm64`), and zero third-party dependencies. UI text that
  needs the product name uses `AppInfo.name`; plist and log paths come from
  `LaunchAgentStore`/`AppInfo`.
- Do not commit generated artifacts: `build/`, `dist/`, `DerivedData/`, and
  `xcuserdata/` are ignored. Run `plutil -lint` after editing the project file
  by hand.

## Quality gate

Run from the repository root. Every command must exit 0 before a task is done:

```sh
xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Debug build
xcodebuild test -project Stayman.xcodeproj -scheme Stayman
```

Also run when the related file changed:

```sh
plutil -lint Stayman.xcodeproj/project.pbxproj
bash -n scripts/*.sh
```

If Xcode is unavailable, state that the gate could not be run; never report it
as passing.
