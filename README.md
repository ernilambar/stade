# Stayman

A small macOS app to add, edit, remove, start and stop background scripts (dev
servers such as `glot serve` or `uplet serve`). Scripts run as launch agents, so
they start at login and keep running after the app quits.

## Requirements

- macOS 13 or later
- Xcode 15 or later (Swift 5.9+)
- No third-party dependencies

## Build

```sh
open Stayman.xcodeproj
```

Run the `Stayman` scheme. Or from the command line:

```sh
xcodebuild -project Stayman.xcodeproj -scheme Stayman -configuration Release build
```

Tests:

```sh
xcodebuild test -project Stayman.xcodeproj -scheme Stayman
```

## Naming

The app name and bundle ID are defined once in `Config/App.xcconfig`. Swift code
reads them from the bundle, so renaming the app does not require code changes.

## Author

Nilambar Sharma — <https://nilambar.net/>

## Repository

<https://github.com/ernilambar/stayman>

## License

MIT. See [LICENSE](LICENSE).
