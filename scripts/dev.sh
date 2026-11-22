#!/usr/bin/env bash
# Build the app, install it into /Applications, and relaunch it.
#
#   ./scripts/dev.sh [--release]
#
# Use this for behaviour that only exists in an installed bundle: the Login
# Items registration, the launch agent prefix shown in System Settings, and
# starting scripts at login. The running /Applications copy is replaced, so
# quit it first if it has unsaved edits.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
. "$ROOT/scripts/lib.sh"

CONFIGURATION="Debug"
if [ "${1:-}" = "--release" ]; then
    CONFIGURATION="Release"
    shift
fi

PROJECT="${PROJECT:-Stayman.xcodeproj}"
SCHEME="${SCHEME:-Stayman}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"

APP_NAME="$(config_value APP_NAME)"
if [ -z "$APP_NAME" ]; then
    echo "APP_NAME is missing from Config/App.xcconfig" >&2
    exit 1
fi

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    build

SRC="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DEST="${DEST:-/Applications/$APP_NAME.app}"
LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"

if [ ! -d "$SRC" ]; then
    echo "Build succeeded but $SRC was not found" >&2
    exit 1
fi

codesign --verify --deep --strict "$SRC"

# The binary lives at <bundle>/Contents/MacOS/<executable name>; signalling it
# by path avoids matching unrelated processes that share the app name.
STOP_PATTERN="$DEST/Contents/MacOS/"
if pgrep -f "$STOP_PATTERN" >/dev/null; then
    pkill -f "$STOP_PATTERN" || true
    for _ in {1..50}; do
        pgrep -f "$STOP_PATTERN" >/dev/null || break
        sleep 0.1
    done
    pkill -9 -f "$STOP_PATTERN" 2>/dev/null || true
fi

rm -rf "$DEST"
ditto "$SRC" "$DEST"
"$LSREGISTER" -f "$DEST"

echo "Installed $CONFIGURATION build to $DEST"
open "$DEST"
