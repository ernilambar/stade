# Stayman

A small, native macOS app to add, edit, remove, start, and stop background
scripts (dev servers such as `glot serve` or `uplet serve`). Each script runs as
a launch agent, so it starts at login and keeps running after the app quits.

## Features

- Add, edit, remove, start, stop, and restart scripts from one window
- Runs each script as a launch agent, so it starts at login and survives
  quitting the app
- Optional restart-on-crash; a clean exit stays stopped
- Live status per script, with a built-in log viewer
- “Remove All Scripts & Quit…” stops and deletes every agent, keeping logs
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
