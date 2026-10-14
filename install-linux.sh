#!/bin/bash
# Install CLI + desktop pixel light (+ optional tray) for Linux.
# Does not touch the macOS Swift app.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPPORT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/XiaomeiSignal"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Install python3 and re-run." >&2
  exit 1
fi

echo "==> Installing into: $SUPPORT_DIR"
mkdir -p "$SUPPORT_DIR"
for f in xiaomei_signal.py set-status.py set-status show-status.py tray.py desktop_light.py; do
  cp "$REPO_DIR/$f" "$SUPPORT_DIR/$f"
  chmod +x "$SUPPORT_DIR/$f"
done

echo "==> Symlinks in: $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$SUPPORT_DIR/set-status" "$BIN_DIR/xiaomei-set-status"
ln -sf "$SUPPORT_DIR/show-status.py" "$BIN_DIR/xiaomei-show-status"
ln -sf "$SUPPORT_DIR/tray.py" "$BIN_DIR/xiaomei-tray"
ln -sf "$SUPPORT_DIR/desktop_light.py" "$BIN_DIR/xiaomei-light"

if [ ! -f "$SUPPORT_DIR/status.json" ]; then
  python3 "$SUPPORT_DIR/set-status.py" green "已安装 (Linux)" >/dev/null
fi

echo "==> Done."
echo "Data dir: $SUPPORT_DIR"
echo "Set status:  xiaomei-set-status green|yellow|red \"说明\" \"agent\""
echo "            or: bash \"$SUPPORT_DIR/set-status\" yellow \"等你\" \"小梅\""
echo "Watch CLI:  xiaomei-show-status -w"
echo "Desktop light (pixel悬浮灯):"
echo "  needs pygame →  sudo apt install python3-pygame   # or: pip install pygame"
echo "  then:         xiaomei-light"
echo "Tray (opt): python3 -m pip install --user pystray pillow && xiaomei-tray"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: add to PATH →  export PATH=\"$BIN_DIR:\$PATH\""
fi
