# Contributing

## Requirements

- macOS 13 or later on Apple Silicon (M1 or newer)
- Command Line Tools (`xcode-select --install`) or Xcode, with Swift 5.9+
- No third-party dependencies

## Setup

The app is a Swift package; there is no Xcode project. Build and run it from
the terminal:

```sh
swift build                       # compile only
./scripts/bundle.sh               # build/debug/Stade.app
./scripts/bundle.sh --release     # build/release/Stade.app
```

Use `@StateBox` instead of `@State` in views; the macOS 27 SDK's `@State`
macro needs a plugin that only Xcode provides.

To test login items and relaunch behaviour, install a Debug build into
`/Applications` and open it:

```sh
./scripts/dev.sh
```

Pass `--release` to install a Release build instead.

## Tests

```sh
swift test
```

Tests use swift-testing (`@Test`, `#expect`); XCTest ships only with Xcode.
With Command Line Tools 6.4 a run can fail with `plugin for module
'TestingMacros' not found`; that is a toolchain bug, so rerun it. CI is the
source of truth.

## Checks before a pull request

```sh
swift build -Xswiftc -warnings-as-errors
./scripts/bundle.sh
bash -n scripts/*.sh && shellcheck scripts/*.sh
```

The `CI` workflow runs the same checks plus `swift test` on every push to
`main` and every non-draft pull request; it must pass before merging.

## Code layout

| Path | Purpose |
| --- | --- |
| `Sources/Script.swift` | Script model, plist encode/decode, command wrapping |
| `Sources/LaunchAgentStore.swift` | Plist read, write, delete |
| `Sources/Launchctl.swift` | launchctl calls, actions, status parsing |
| `Sources/ScriptListModel.swift` | Main-actor view model |
| `Sources/ContentView.swift` | Main window, list, actions |
| `Sources/EditScriptView.swift` | Add and edit sheet |
| `Sources/LogView.swift`, `Sources/LogFile.swift` | Log viewer, tail, compaction |
| `Tests/` | Unit tests |
| `Resources/AppIcon.iconset` | App icon |
| `Package.swift` | SwiftPM targets |
| `scripts/bundle.sh` | Builds the `.app` and its `Info.plist` |
| `Config/App.xcconfig` | App name, bundle ID, version |

App identity is defined only in `Config/App.xcconfig`; Swift code reads it from
the bundle via `AppInfo`. See [AGENTS.md](AGENTS.md) for the full conventions.

## Release

```sh
./scripts/build.sh
```

This builds a Release app, verifies its signature, and writes
`build/Stade-<version>.zip`. Set `ZIP_NAME` to override the zip name, as the
release workflow does:

```sh
ZIP_NAME=Stade-macos-arm64 OUTPUT_DIR=dist ./scripts/build.sh
```

1. Bump `APP_VERSION` in `Config/App.xcconfig`.
2. Tag `v<version>` matching `APP_VERSION` and push the tag.
3. The `Release` workflow verifies the tag, builds the arm64 bundle, and
   publishes `Stade-macos-arm64.zip` to the GitHub release.
4. Re-run the workflow from the Actions tab with an existing tag to rebuild
   its asset. Never commit `build/` or `dist/`.

## Manual test checklist

- Add, start, stop, restart, edit, and remove a script.
- Quit the app; running services keep running.
- Log out and back in; started services run, stopped services stay stopped.
- `kill -9 <pid>` restarts when “Restart on crash” is on.
- A clean exit (code 0) is not restarted.
- Login Items shows scripts under Stade, not several “zsh” entries.
- The log view shows output; a bad command shows “command not found”.
