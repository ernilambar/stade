# Stayman

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

macOS 13 or later on Apple Silicon (M1 or newer).

## Install

Install with the install script:

```sh
curl -fsSL https://raw.githubusercontent.com/ernilambar/stayman/main/scripts/install.sh | sh
```

This downloads the latest release and installs it into `/Applications`.

## Docs

- [Install options](docs/install.md) — manual download, first launch, updating,
  and uninstalling

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
to build it from source.

## License

[MIT](LICENSE) © Nilambar Sharma ([nilambar.net](https://nilambar.net/))
