#!/usr/bin/env python3
"""Print or watch status.json in the terminal (Linux / Windows / macOS)."""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from xiaomei_signal import read_status, status_path, support_dir  # noqa: E402

# ANSI (disabled when not a TTY or NO_COLOR is set)
_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
_COLORS = {
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
}
_RESET = "\033[0m"
_DOT = {"green": "●", "yellow": "●", "red": "●"}


def format_line(s: dict) -> str:
    state = s.get("state", "green")
    dot = _DOT.get(state, "●")
    label = s.get("label") or state
    detail = s.get("detail") or ""
    updated = s.get("updatedAt") or ""
    body = f"{dot} {state} {label}"
    if detail:
        body += f"  {detail}"
    if updated:
        body += f"  ({updated})"
    if _USE_COLOR and state in _COLORS:
        return f"{_COLORS[state]}{body}{_RESET}"
    return body


def once() -> int:
    s = read_status()
    print(format_line(s))
    print(f"file: {status_path()}", file=sys.stderr)
    return 0 if s.get("detail") != "读不到状态" else 2


def watch(interval: float) -> None:
    print(f"watching {status_path()} (Ctrl+C to stop)", file=sys.stderr)
    last = None
    try:
        while True:
            s = read_status()
            key = (s.get("state"), s.get("detail"), s.get("updatedAt"))
            if key != last:
                # Clear line + print
                if sys.stdout.isatty():
                    sys.stdout.write("\r\033[K")
                print(format_line(s), flush=True)
                last = key
            time.sleep(interval)
    except KeyboardInterrupt:
        print(file=sys.stderr)


def main() -> None:
    p = argparse.ArgumentParser(description="Show 小梅信号灯 status in the terminal")
    p.add_argument(
        "-w",
        "--watch",
        action="store_true",
        help="poll and print when status changes",
    )
    p.add_argument(
        "-i",
        "--interval",
        type=float,
        default=1.0,
        help="poll interval seconds (default 1)",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="print raw status.json fields as one line JSON",
    )
    args = p.parse_args()
    support_dir().mkdir(parents=True, exist_ok=True)
    if args.json:
        import json

        print(json.dumps(read_status(), ensure_ascii=False))
        return
    if args.watch:
        watch(args.interval)
    else:
        raise SystemExit(once())


if __name__ == "__main__":
    main()
