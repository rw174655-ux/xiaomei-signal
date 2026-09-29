#!/bin/bash
# Remove the watcher LaunchAgent and the app bundle.
# Pass --purge to also delete ~/Library/Application Support/XiaomeiSignal (scripts, status, logs).
set -uo pipefail

SUPPORT_DIR="$HOME/Library/Application Support/XiaomeiSignal"
APP="$HOME/Applications/小梅信号灯.app"
LABEL="local.xiaomei.signal.watch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> Stopping watcher"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "==> Quitting and removing app"
pkill -f "$APP/Contents/MacOS/XiaomeiSignal" 2>/dev/null || true
rm -rf "$APP"

if [ "${1:-}" = "--purge" ]; then
  echo "==> Removing $SUPPORT_DIR"
  rm -rf "$SUPPORT_DIR"
else
  echo "Kept $SUPPORT_DIR (run with --purge to delete it)."
fi
echo "==> Done."
