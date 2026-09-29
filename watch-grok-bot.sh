#!/bin/bash
APP="$HOME/Applications/小梅信号灯.app"
BIN="$APP/Contents/MacOS/XiaomeiSignal"
LOG="$HOME/Library/Application Support/XiaomeiSignal/watch.log"

# Only the main app process — Helper can linger after quit and would keep the light up.
is_grok_running() {
  pgrep -f "/Applications/Grok Bot.app/Contents/MacOS/Grok Bot" >/dev/null 2>&1 && return 0
  pgrep -x "Grok Bot" >/dev/null 2>&1 && return 0
  return 1
}

is_signal_running() {
  pgrep -f "$BIN" >/dev/null 2>&1
}

quit_signal() {
  # Prefer graceful quit, then force
  pkill -f "$BIN" 2>/dev/null || true
}

echo "$(date '+%F %T') watcher start" >> "$LOG"
while true; do
  if is_grok_running; then
    if ! is_signal_running; then
      echo "$(date '+%F %T') Grok Bot up -> open signal" >> "$LOG"
      open "$APP" >/dev/null 2>&1 || "$BIN" >/dev/null 2>&1 &
    fi
  else
    if is_signal_running; then
      echo "$(date '+%F %T') Grok Bot down -> quit signal" >> "$LOG"
      quit_signal
    fi
  fi
  sleep 5
done
