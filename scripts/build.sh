#!/bin/bash
# Build a Release bundle and zip it: build/<APP_NAME>-<version>.zip.
# ZIP_NAME and OUTPUT_DIR override the zip name and directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-build}"

APP_PATH="$(CONFIGURATION="${CONFIGURATION:-release}" ./scripts/bundle.sh | tail -n 1)"
APP_NAME="$(config_value APP_NAME)"
VERSION="$(config_value APP_VERSION)"

mkdir -p "$OUTPUT_DIR"
ZIP_PATH="$OUTPUT_DIR/${ZIP_NAME:-$APP_NAME-$VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent --norsrc --noextattr "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
