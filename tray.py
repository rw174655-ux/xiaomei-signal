#!/usr/bin/env python3
"""
Optional system tray for Linux / Windows (and macOS if desired).
Requires: pip install pystray pillow
Falls back to printing an install hint if deps are missing.
Uses the same status.json as set-status / the macOS Swift app.
"""
from __future__ import annotations

import argparse
import sys
import threading
import time
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from xiaomei_signal import read_status, status_path, write_status  # noqa: E402

COLORS = {
    "green": (0x35, 0xF0, 0x50, 255),
    "yellow": (0xFF, 0xD9, 0x26, 255),
    "red": (0xFF, 0x4D, 0x59, 255),
    "off": (0x40, 0x40, 0x40, 255),
}


def _make_icon_image(active: str):
    from PIL import Image, ImageDraw

    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # housing
    draw.rounded_rectangle([8, 4, 56, 60], radius=8, fill=(30, 30, 30, 255))
    lamps = [("red", 14), ("yellow", 28), ("green", 42)]
    for name, y in lamps:
        color = COLORS[name] if name == active else COLORS["off"]
        draw.ellipse([20, y, 44, y + 14], fill=color)
    return img


def run_tray() -> None:
    try:
        import pystray
        from PIL import Image  # noqa: F401
    except ImportError:
        print(
            "tray needs optional deps. Install once:\n"
            "  python3 -m pip install --user pystray pillow\n"
            "Then re-run: python3 tray.py\n"
            "Or use the terminal viewer: python3 show-status.py -w",
            file=sys.stderr,
        )
        sys.exit(1)

    import pystray

    state_holder = {"state": "green", "tip": "小梅信号灯"}

    def refresh_tip():
        s = read_status()
        state_holder["state"] = s["state"]
        tip = "\n".join(
            x for x in [s.get("label", ""), s.get("detail", ""), s.get("updatedAt", "")] if x
        )
        state_holder["tip"] = tip or "小梅信号灯"
        return s

    def update_icon(icon: "pystray.Icon") -> None:
        while icon.visible:
            s = refresh_tip()
            icon.icon = _make_icon_image(s["state"])
            icon.title = state_holder["tip"]
            time.sleep(1.0)

    def on_quit(icon, _item):
        icon.stop()

    def set_color(color: str):
        def _inner(icon, _item):
            write_status(color, f"手动切到 {color}", "tray")
            icon.icon = _make_icon_image(color)

        return _inner

    refresh_tip()
    menu = pystray.Menu(
        pystray.MenuItem("green 推进中", set_color("green")),
        pystray.MenuItem("yellow 等你", set_color("yellow")),
        pystray.MenuItem("red 卡住", set_color("red")),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem(
            "打开 status 目录",
            lambda icon, item: _open_dir(status_path().parent),
        ),
        pystray.MenuItem("退出", on_quit),
    )
    icon = pystray.Icon(
        "xiaomei-signal",
        _make_icon_image(state_holder["state"]),
        state_holder["tip"],
        menu,
    )
    threading.Thread(target=update_icon, args=(icon,), daemon=True).start()
    print(f"tray watching {status_path()}", file=sys.stderr)
    icon.run()


def _open_dir(path: Path) -> None:
    import platform
    import subprocess

    path.mkdir(parents=True, exist_ok=True)
    system = platform.system()
    try:
        if system == "Darwin":
            subprocess.Popen(["open", str(path)])
        elif system == "Windows":
            subprocess.Popen(["explorer", str(path)])
        else:
            subprocess.Popen(["xdg-open", str(path)])
    except OSError:
        pass


def main() -> None:
    p = argparse.ArgumentParser(description="小梅信号灯 system tray (optional)")
    p.parse_args()
    run_tray()


if __name__ == "__main__":
    main()
