# Installing

The [README](../README.md#install) covers the install script. This page covers
the manual download, first launch, updating, and uninstalling.

## Manual download

Download `Stayman-macos-arm64.zip` from the
[latest release](https://github.com/ernilambar/stayman/releases/latest), unzip
it, and move `Stayman.app` to `/Applications`.

## First launch

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

## Update

Run the install script again. It replaces `/Applications/Stayman.app` with the
latest release and leaves your scripts and logs in place.

## Uninstall

Use “Remove All Scripts & Quit…” from the app menu while the app is open.

Manual cleanup, for each script name:

```sh
launchctl bootout gui/$(id -u)/net.nilambar.stayman.<name>
rm ~/Library/LaunchAgents/net.nilambar.stayman.*.plist
```

Then remove the app:

```sh
rm -rf /Applications/Stayman.app
```

Log files in `~/Library/Logs/Stayman/` are kept. Deleting only the app leaves
the agents running at every login.
