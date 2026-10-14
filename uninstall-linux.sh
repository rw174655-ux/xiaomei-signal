#!/bin/bash
set -uo pipefail
SUPPORT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/XiaomeiSignal"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

echo "==> Removing symlinks"
rm -f "$BIN_DIR/xiaomei-set-status" "$BIN_DIR/xiaomei-show-status" "$BIN_DIR/xiaomei-tray"

if [ "${1:-}" = "--purge" ]; then
  echo "==> Removing $SUPPORT_DIR"
  rm -rf "$SUPPORT_DIR"
else
  echo "==> Removing scripts, keeping status.json"
  rm -f "$SUPPORT_DIR"/xiaomei_signal.py \
        "$SUPPORT_DIR"/set-status.py \
        "$SUPPORT_DIR"/set-status \
        "$SUPPORT_DIR"/show-status.py \
        "$SUPPORT_DIR"/tray.py
  echo "Kept $SUPPORT_DIR (run with --purge to delete it)."
fi
echo "==> Done."
