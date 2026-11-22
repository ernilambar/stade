# Stayman

A small macOS app to add, edit, remove, start and stop background scripts (dev
servers such as `glot serve` or `uplet serve`). Scripts run as launch agents, so
they start at login and keep running after the app quits.

## Requirements

- macOS 13 or later

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

## Uninstall

Use “Remove All Scripts & Quit…” from the app menu while the app is open.

Manual cleanup, for each script name:

```sh
launchctl bootout gui/$(id -u)/net.nilambar.stayman.<name>
rm ~/Library/LaunchAgents/net.nilambar.stayman.*.plist
```

Log files in `~/Library/Logs/Stayman/` are kept. Deleting only the app leaves
the agents running at every login.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Author

Nilambar Sharma — <https://nilambar.net/>

## Repository

<https://github.com/ernilambar/stayman>

## License

MIT. See [LICENSE](LICENSE).
