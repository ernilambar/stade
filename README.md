# Stayman

A small macOS app to add, edit, remove, start and stop background scripts (dev
servers such as `glot serve` or `uplet serve`). Scripts run as launch agents, so
they start at login and keep running after the app quits.

## Requirements

- macOS 13 or later
- Xcode 15 or later to build (Swift 5.9+)
- No third-party dependencies

## Install

1. Download `Stayman-<version>.zip` from the GitHub releases page.
2. Unzip it and move `Stayman.app` to `/Applications`.
3. Open the app from `/Applications`.

### First launch

Release builds are ad-hoc signed, not notarized. On macOS 15 and later,
right-click → Open no longer bypasses Gatekeeper for downloaded apps. Open the
app once, then go to System Settings → Privacy & Security and click
“Open Anyway”. Alternatively:

```sh
xattr -dr com.apple.quarantine /Applications/Stayman.app
```

macOS may show a “Background item added” notice; this is normal. Keep Stayman
allowed under System Settings → General → Login Items → Allow in the
Background.

## Build

```sh
open Stayman.xcodeproj
```

Run the `Stayman` scheme.

Release build and zip:

```sh
./scripts/build.sh
```

The zip is written to `build/Stayman-<version>.zip`. `make build` does the same.
Tests:

```sh
xcodebuild test -project Stayman.xcodeproj -scheme Stayman
```

or `make test`.

## Release

```sh
./scripts/build.sh
git tag v<version>
# attach build/Stayman-<version>.zip to a GitHub release
```

## Uninstall

Use “Remove All Scripts & Quit…” from the app menu while the app is open.

Manual cleanup, for each script name:

```sh
launchctl bootout gui/$(id -u)/net.nilambar.stayman.<name>
rm ~/Library/LaunchAgents/net.nilambar.stayman.*.plist
```

Log files in `~/Library/Logs/Stayman/` are kept; delete them manually if
desired. Deleting only the app leaves the agents running at every login.

## Naming

The app name and bundle ID are defined once in `Config/App.xcconfig`. Swift code
reads them from the bundle, so renaming the app does not require code changes.

## Author

Nilambar Sharma — <https://nilambar.net/>

## Repository

<https://github.com/ernilambar/stayman>

## License

MIT. See [LICENSE](LICENSE).
