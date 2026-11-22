# Stade

A native macOS app that runs background scripts as launch agents, with
add/edit/start/stop/remove controls and login-time startup.

## Features

- Add, edit, remove, start, stop, and restart scripts from one window
- Runs each script as a launch agent, so it starts at login and survives
  quitting the app
- Optional restart-on-crash; a clean exit stays stopped
- Live status per script, with a built-in log viewer
- No third-party dependencies

## Requirements

macOS 15 or later on Apple Silicon (M1 or newer).

## Install

With Homebrew:

```sh
brew install --cask ernilambar/tap/stade
```

Or with the install script:

```sh
curl -fsSL https://raw.githubusercontent.com/ernilambar/stade/main/scripts/install.sh | sh
```

Both install into `/Applications`; the script downloads the latest release, the
cask also removes the quarantine flag so Gatekeeper does not block the first
launch.

## Docs

- [Install options](docs/install.md) — Homebrew, manual download, first launch,
  updating, and uninstalling
- [Usage](docs/usage.md) — how scripts run, with PHP server and background
  worker use cases

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
to build it from source.

## License

[MIT](LICENSE) © Nilambar Sharma ([nilambar.net](https://nilambar.net/))
