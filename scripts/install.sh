#!/bin/sh
# Install the latest Stade release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/ernilambar/stade/main/scripts/install.sh | sh
#
# Files fetched with curl carry no quarantine flag, so the ad-hoc signed app
# opens without a Gatekeeper prompt of its own.
set -eu

URL="https://github.com/ernilambar/stade/releases/latest/download/Stade-macos-arm64.zip"
DEST="${DEST:-/Applications/Stade.app}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Stade requires macOS." >&2
    exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
    echo "Stade requires macOS on Apple Silicon." >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Stade..."
curl -fsSL "$URL" -o "$tmp/Stade.zip"
ditto -x -k "$tmp/Stade.zip" "$tmp"

if pgrep -f "$DEST/Contents/MacOS/" >/dev/null; then
    pkill -f "$DEST/Contents/MacOS/" || true
    while pgrep -f "$DEST/Contents/MacOS/" >/dev/null; do
        sleep 0.1
    done
fi

rm -rf "$DEST"
ditto "$tmp/Stade.app" "$DEST"

echo "Installed $DEST"
echo "Open it with: open \"$DEST\""
