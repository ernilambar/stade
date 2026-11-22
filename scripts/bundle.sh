#!/bin/bash
# Build <APP_NAME>.app with SwiftPM and the Command Line Tools (no Xcode).
#
#   ./scripts/bundle.sh [--release]
#
# Prints the bundle path on the last line. SwiftPM compiles the binary,
# iconutil builds the icon, and Info.plist is written from Config/App.xcconfig.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/lib.sh"

CONFIGURATION="${CONFIGURATION:-debug}"
if [ "${1:-}" = "--release" ]; then
  CONFIGURATION="release"
fi
CONFIGURATION="$(echo "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"

OUTPUT_DIR="${BUNDLE_DIR:-build/$CONFIGURATION}"
MIN_MACOS="15.0"
CATEGORY="public.app-category.developer-tools"
COPYRIGHT="© 2026 Nilambar Sharma"

APP_NAME="$(config_value APP_NAME)"
BUNDLE_ID="$(config_value APP_BUNDLE_ID)"
VERSION="$(config_value APP_VERSION)"
BUILD_NUMBER="$(config_value APP_BUILD)"
for var in APP_NAME BUNDLE_ID VERSION BUILD_NUMBER; do
  if [ -z "${!var}" ]; then
    echo "$var is missing from Config/App.xcconfig" >&2
    exit 1
  fi
done

swift build -c "$CONFIGURATION" --arch arm64 >&2
BIN_DIR="$(swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"

APP="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AppCore" "$APP/Contents/MacOS/$APP_NAME"

iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

PLIST="$APP/Contents/Info.plist"
plist_set() {
  /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST" >/dev/null
}
plist_set CFBundleDevelopmentRegion en
plist_set CFBundleExecutable "$APP_NAME"
plist_set CFBundleIdentifier "$BUNDLE_ID"
plist_set CFBundleInfoDictionaryVersion 6.0
plist_set CFBundleName "$APP_NAME"
plist_set CFBundleDisplayName "$APP_NAME"
plist_set CFBundlePackageType APPL
plist_set CFBundleShortVersionString "$VERSION"
plist_set CFBundleVersion "$BUILD_NUMBER"
plist_set CFBundleIconFile AppIcon
plist_set LSMinimumSystemVersion "$MIN_MACOS"
plist_set LSApplicationCategoryType "$CATEGORY"
plist_set NSHumanReadableCopyright "$COPYRIGHT"
plist_set NSPrincipalClass NSApplication
plutil -lint "$PLIST" >/dev/null

codesign --force --sign - "$APP" 2>/dev/null
codesign --verify --deep --strict "$APP"

ARCHS="$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
if [ "$ARCHS" != "arm64" ]; then
  echo "Expected an arm64 build, found: $ARCHS" >&2
  exit 1
fi

echo "$APP"
