#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/lib.sh"

PROJECT="${PROJECT:-Stayman.xcodeproj}"
SCHEME="${SCHEME:-Stayman}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"

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

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but $APP_PATH was not found" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_PATH"

EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE")"
if [[ "$ARCHS" != "arm64" ]]; then
  echo "Expected an arm64 build, found: $ARCHS" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
mkdir -p "$OUTPUT_DIR"
ZIP_PATH="$OUTPUT_DIR/${ZIP_NAME:-$APP_NAME-$VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent --norsrc --noextattr "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
