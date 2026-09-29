#!/bin/bash
# Build 小梅信号灯 and install the Grok Bot watcher LaunchAgent (current user only).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/XiaomeiSignal"
APP="$HOME/Applications/小梅信号灯.app"
LABEL="local.xiaomei.signal.watch"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST="$AGENT_DIR/$LABEL.plist"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This app only runs on macOS." >&2
  exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found (needed by set-status). Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

echo "==> Building app bundle: $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$REPO_DIR/Info.plist" "$APP/Contents/Info.plist"
swiftc -O -parse-as-library -framework Cocoa \
  "$REPO_DIR/XiaomeiSignal.swift" \
  -o "$APP/Contents/MacOS/XiaomeiSignal"

echo "==> Installing scripts into: $SUPPORT_DIR"
mkdir -p "$SUPPORT_DIR"
for f in set-status set-status.py watch-grok-bot.sh; do
  cp "$REPO_DIR/$f" "$SUPPORT_DIR/$f"
  chmod +x "$SUPPORT_DIR/$f"
done

if [ ! -f "$SUPPORT_DIR/status.json" ]; then
  bash "$SUPPORT_DIR/set-status" green "已安装" >/dev/null
fi

echo "==> Installing LaunchAgent: $PLIST"
mkdir -p "$AGENT_DIR"
# Escape characters that are special for sed replacement / XML.
esc_dir=$(printf '%s' "$SUPPORT_DIR" | sed -e 's/[&|\\]/\\&/g')
sed "s|__SUPPORT_DIR__|$esc_dir|g" "$REPO_DIR/$LABEL.plist.template" > "$PLIST"
plutil -lint "$PLIST" >/dev/null

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
if ! launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load -w "$PLIST"
fi

echo "==> Done."
echo "The light appears while Grok Bot is running (checked every 5 seconds)."
echo "Try: bash \"\$HOME/Library/Application Support/XiaomeiSignal/set-status\" yellow \"等你确认\" \"小梅\""
