# Contributing

## Requirements

- macOS 13 or later
- Xcode 15 or later (Swift 5.9+)
- No third-party dependencies

## Setup

```sh
xcode-select -p
open Stayman.xcodeproj
```

`xcode-select -p` must point inside `Xcode.app`; the Command Line Tools alone
cannot build the SwiftUI app. Run the `Stayman` scheme, or build from the
terminal:

```sh
xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Debug build
```

## Tests

```sh
xcodebuild test -project Stayman.xcodeproj -scheme Stayman
```

## Checks before a pull request

```sh
xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Debug build
xcodebuild test -project Stayman.xcodeproj -scheme Stayman
plutil -lint Stayman.xcodeproj/project.pbxproj
bash -n scripts/build.sh
```

Both `xcodebuild` commands must exit 0. If Xcode is unavailable, say so rather
than claiming a pass.

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
| `Config/App.xcconfig` | App name, bundle ID, module name |

App identity is defined only in `Config/App.xcconfig`; Swift code reads it from
the bundle via `AppInfo`. See [AGENTS.md](AGENTS.md) for the full conventions.

## Release

```sh
./scripts/build.sh
```

This builds a Release app, verifies its signature, and writes
`build/Stayman-<version>.zip`.

1. Build and verify the zip.
2. Tag `v<version>` matching `MARKETING_VERSION` in the project.
3. Attach the zip to a GitHub release.
4. Never commit `build/`.

## Manual test checklist

- Add, start, stop, restart, edit, and remove a script.
- Quit the app; running services keep running.
- Log out and back in; started services run, stopped services stay stopped.
- `kill -9 <pid>` restarts when “Restart on crash” is on.
- A clean exit (code 0) is not restarted.
- Login Items shows scripts under Stayman, not several “zsh” entries.
- The log view shows output; a bad command shows “command not found”.
- “Remove All Scripts & Quit…” leaves no `net.nilambar.stayman.*.plist`.
