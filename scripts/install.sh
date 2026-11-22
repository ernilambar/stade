#!/bin/sh
# Install the latest Stayman release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/ernilambar/stayman/main/scripts/install.sh | sh
#
# Files fetched with curl carry no quarantine flag, so the ad-hoc signed app
# opens without a Gatekeeper prompt of its own.
set -eu

URL="https://github.com/ernilambar/stayman/releases/latest/download/Stayman-macos-arm64.zip"
DEST="${DEST:-/Applications/Stayman.app}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Stayman requires macOS." >&2
    exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
    echo "Stayman requires macOS on Apple Silicon." >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Stayman..."
curl -fsSL "$URL" -o "$tmp/Stayman.zip"
ditto -x -k "$tmp/Stayman.zip" "$tmp"

if pgrep -f "$DEST/Contents/MacOS/" >/dev/null; then
    pkill -f "$DEST/Contents/MacOS/" || true
    while pgrep -f "$DEST/Contents/MacOS/" >/dev/null; do
        sleep 0.1
    done
fi

rm -rf "$DEST"
ditto "$tmp/Stayman.app" "$DEST"

echo "Installed $DEST"
echo "Open it with: open \"$DEST\""
