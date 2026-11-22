# Installing

The [README](../README.md#install) covers the install script and Homebrew. This
page covers the manual download, first launch, updating, and uninstalling.

## Homebrew

```sh
brew install --cask ernilambar/tap/stade
```

The cask removes the quarantine flag after installing, so the Gatekeeper step
below only applies to a manual download.

## Manual download

Download `Stade-macos-arm64.zip` from the
[latest release](https://github.com/ernilambar/stade/releases/latest), unzip
it, and move `Stade.app` to `/Applications`.

## First launch

Release builds are ad-hoc signed, not notarized. On macOS 15 and later,
right-click → Open no longer bypasses Gatekeeper for downloaded apps. Open the
app once, then go to System Settings → Privacy & Security and click
“Open Anyway”. Alternatively:

```sh
xattr -dr com.apple.quarantine /Applications/Stade.app
```

macOS may show a “Background item added” notice; this is normal. Keep Stade
allowed under System Settings → General → Login Items → Allow in the
Background.

## Update

Run the install script again. It replaces `/Applications/Stade.app` with the
latest release and leaves your scripts and logs in place.

## Uninstall

Remove each script in the app before deleting it.

Manual cleanup, for each script name:

```sh
launchctl bootout gui/$(id -u)/net.nilambar.stade.<name>
rm ~/Library/LaunchAgents/net.nilambar.stade.*.plist
```

Then remove the app:

```sh
rm -rf /Applications/Stade.app
```

Log files in `~/Library/Logs/Stade/` are kept. Deleting only the app leaves
the agents running at every login.
