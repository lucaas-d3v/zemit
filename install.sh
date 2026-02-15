#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

DEST_DIR="/usr/local/bin"
DEST_BIN="$DEST_DIR/zemit"
BIN_SRC="$SCRIPT_DIR/zig-out/bin/zemit"

if ! command -v zig &> /dev/null; then
  echo "Zig is not installed or could not be found."
  echo "Zig 0.13.0 is recommended."
  exit 1
fi

echo "Compiling zemit..."
cd "$SCRIPT_DIR"
zig build -Doptimize=ReleaseSmall #-Dstrip=true
echo "Binary compiled: $BIN_SRC"

echo "Installing to $DEST_BIN"
sudo install -m 0755 "$BIN_SRC" "$DEST_BIN"

if ! "$DEST_BIN" --version &> /dev/null; then
  echo "An error occurred while executing '$DEST_BIN --version'"
  exit 1
fi

echo "Installation completed successfully!"