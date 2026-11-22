#!/bin/sh
# Shared helpers for the scripts in this directory.
# Source it; never run it directly. Callers set ROOT to the repository root.

# config_value KEY: read a value from Config/App.xcconfig, without the
# trailing whitespace and without the comment lines.
config_value() {
  sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$ROOT/Config/App.xcconfig" \
    | head -n 1 \
    | sed -e 's/[[:space:]]*$//'
}
