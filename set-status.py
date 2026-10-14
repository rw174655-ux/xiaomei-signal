#!/usr/bin/env python3
"""CLI: set green|yellow|red into status.json (cross-platform)."""
import sys
from pathlib import Path

# Allow running from install dir or repo root
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from xiaomei_signal import write_status  # noqa: E402


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: set-status.py green|yellow|red detail [source-agent]")
        sys.exit(1)
    detail = sys.argv[2] if len(sys.argv) > 2 else ""
    source = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        status = write_status(sys.argv[1], detail, source)
    except ValueError:
        print("usage: set-status.py green|yellow|red detail [source-agent]")
        sys.exit(1)
    print("OK", status["state"], status["label"])


if __name__ == "__main__":
    main()
