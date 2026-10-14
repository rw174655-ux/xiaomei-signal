#!/usr/bin/env python3
"""
Cross-platform pixel floating traffic light for Linux / Windows.

Visual behavior aligned with macOS XiaomeiSignal.swift:
  - green / yellow / red lamps, blink (~4.8s on / ~0.28s off)
  - ground shadow direction follows local clock
  - borderless always-on-top window, draggable
  - skips taskbar when the WM cooperates (Linux utility + SKIP_TASKBAR;
    Windows TOPMOST + no-activate)

Reads the same status.json as set-status / tray / the Swift app.
Requires pygame:  apt install python3-pygame  |  pip install pygame
"""
from __future__ import annotations

import argparse
import os
import platform
import sys
import time
from datetime import datetime
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from xiaomei_signal import read_status  # noqa: E402

GRID_W, GRID_H = 30, 42
DEFAULT_SCALE = 4
KEY = (255, 0, 255)  # chroma key / clear fill

CIRCLE7 = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
]


def _rgba(r: float, g: float, b: float, a: float = 1.0) -> tuple[int, int, int, int]:
    return (
        max(0, min(255, int(round(r * 255)))),
        max(0, min(255, int(round(g * 255)))),
        max(0, min(255, int(round(b * 255)))),
        max(0, min(255, int(round(a * 255)))),
    )


def shadow_params(now: datetime | None = None) -> tuple[float, float, int, float]:
    """Port of Swift shadowParams(): local time → (dx, dy, steps, alpha)."""
    now = now or datetime.now()
    t = now.hour + now.minute / 60.0
    if t < 5.5 or t >= 20.0:
        return (0.85, 0.4, 5, 0.10)
    if t < 7:
        return (-1.35, 0.85, 7, 0.14)
    if t < 11:
        k = (t - 7) / 4.0
        return (-1.35 + k * 1.15, 0.9 - k * 0.25, max(5, 8 - int(k * 2)), 0.15 - k * 0.03)
    if t < 13:
        return (0.15, 0.55, 5, 0.10)
    if t < 17:
        k = (t - 13) / 4.0
        return (0.55 + k * 0.85, 0.55 + k * 0.35, min(9, 5 + int(k * 3)), 0.12 + k * 0.04)
    k = (t - 17) / 3.0
    return (1.3 - k * 0.25, 0.85 - k * 0.2, 7, 0.14 - k * 0.04)


def specular_offset(now: datetime | None = None) -> tuple[int, int]:
    dx, dy, _, _ = shadow_params(now)
    if dx > 0.35:
        ox = -1
    elif dx < -0.35:
        ox = 1
    else:
        ox = 0
    return (ox, 2 if dy > 0.75 else 1)


class PixelLight:
    """Renders in Swift bottom-left coords, flips to top-left for pygame."""

    def __init__(self, scale: int = DEFAULT_SCALE) -> None:
        self.scale = scale
        self.state = "green"
        self.blink_on = True
        self._grid = [[KEY + (255,) for _ in range(GRID_W)] for _ in range(GRID_H)]

    def redraw(self, now: datetime | None = None) -> None:
        now = now or datetime.now()
        swift = [[KEY + (255,) for _ in range(GRID_W)] for _ in range(GRID_H)]

        def spx(x: int, y: int, c: tuple[int, int, int, int]) -> None:
            if not (0 <= x < GRID_W and 0 <= y < GRID_H):
                return
            a = c[3] / 255.0
            if a <= 0:
                return
            if a >= 0.98:
                swift[y][x] = (c[0], c[1], c[2], 255)
                return
            prev = swift[y][x]
            if prev[:3] == KEY:
                swift[y][x] = (int(c[0] * a), int(c[1] * a), int(c[2] * a), 255)
            else:
                swift[y][x] = (
                    int(prev[0] * (1 - a) + c[0] * a),
                    int(prev[1] * (1 - a) + c[1] * a),
                    int(prev[2] * (1 - a) + c[2] * a),
                    255,
                )

        def sfill(x: int, y: int, w: int, h: int, c: tuple[int, int, int, int]) -> None:
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    spx(xx, yy, c)

        def stroke_round(x: int, y: int, w: int, h: int, c: tuple[int, int, int, int]) -> None:
            for yy in range(y + 2, y + h - 2):
                spx(x, yy, c)
                spx(x + w - 1, yy, c)
            for xx in range(x + 2, x + w - 2):
                spx(xx, y, c)
                spx(xx, y + h - 1, c)
            for cx, cy in (
                (x + 1, y + 1),
                (x + 2, y),
                (x, y + 2),
                (x + w - 2, y + 1),
                (x + w - 3, y),
                (x + w - 1, y + 2),
                (x + 1, y + h - 2),
                (x + 2, y + h - 1),
                (x, y + h - 3),
                (x + w - 2, y + h - 2),
                (x + w - 3, y + h - 1),
                (x + w - 1, y + h - 3),
            ):
                spx(cx, cy, c)

        def draw_shadow(ox: int, oy: int) -> None:
            dx, dy, steps, alpha = shadow_params(now)
            for i in range(steps):
                fade = 1.0 - i / max(1, steps)
                a = alpha * (0.35 + 0.65 * fade)
                x = ox + int(round(dx * i))
                y = oy + int(round(dy * i))
                core = max(2, 3 - i // 3)
                soft = core + 2
                sfill(x - soft, y, soft * 2 + 1, 1, _rgba(0, 0, 0, a * 0.28))
                sfill(x - soft + 1, y - 1, max(1, soft * 2 - 1), 1, _rgba(0, 0, 0, a * 0.28))
                sfill(x - soft + 1, y + 1, max(1, soft * 2 - 1), 1, _rgba(0, 0, 0, a * 0.28))
                sfill(x - core - 1, y, (core + 1) * 2 + 1, 1, _rgba(0, 0, 0, a * 0.45))
                sfill(x - core, y, core * 2 + 1, 1, _rgba(0, 0, 0, a * 0.7))

        def draw_lamp(cx: int, cy: int, key: str, slot: tuple[int, int, int, int]) -> None:
            on = (key == self.state) and self.blink_on
            sfill(cx - 3, cy + 4, 7, 1, _rgba(0.06, 0.06, 0.06))
            sfill(cx - 3, cy - 3, 7, 7, slot)
            if key == "red":
                off, on_c, hi = _rgba(0.48, 0.16, 0.18), _rgba(1.00, 0.30, 0.34), _rgba(1.00, 0.72, 0.74)
            elif key == "yellow":
                off, on_c, hi = _rgba(0.48, 0.36, 0.10), _rgba(1.00, 0.86, 0.16), _rgba(1.00, 0.95, 0.55)
            else:
                off, on_c, hi = _rgba(0.14, 0.40, 0.22), _rgba(0.34, 0.96, 0.48), _rgba(0.72, 1.00, 0.80)
            base = on_c if on else off
            for row in range(7):
                for col in range(7):
                    if CIRCLE7[row][col] == 1:
                        spx(cx - 3 + col, cy - 3 + row, base)
            if on:
                ox, oy = specular_offset(now)
                sx, sy = cx + ox, cy + oy
                spx(sx, sy, _rgba(1, 1, 1))
                spx(sx + (1 if ox == 0 else 0), sy, _rgba(1, 1, 1, 0.85))
                if oy >= 1:
                    spx(sx, sy + 1, _rgba(1, 1, 1, 0.55))
                rim_x = cx + (1 if ox == 0 else ox)
                spx(rim_x, sy, (*hi[:3], int(0.65 * 255)))

        ink = _rgba(0, 0, 0)
        body = _rgba(0.18, 0.19, 0.22)
        body_hi = _rgba(0.48, 0.50, 0.55)
        body_lo = _rgba(0.10, 0.11, 0.13)
        slot = _rgba(0.07, 0.07, 0.09)
        dx, _, _, _ = shadow_params(now)
        lit_left = dx >= 0
        edge_lit = body_hi if lit_left else body_lo
        edge_shade = body_lo if lit_left else body_hi

        hx, hy, hw, hh = 9, 10, 11, 26
        cx = hx + hw // 2

        draw_shadow(cx + 1, 3)
        sfill(cx - 5, 3, 11, 1, ink)
        sfill(cx - 4, 4, 9, 1, body_lo)
        sfill(cx - 4, 4, 1, 1, _rgba(0.62, 0.62, 0.62))
        sfill(cx - 3, 5, 7, 1, ink)
        sfill(cx - 1, 6, 3, 4, body_lo)
        sfill(cx - 1, 6, 1, 4, edge_lit)
        sfill(cx + 1, 6, 1, 4, edge_shade)
        sfill(cx - 2, 9, 5, 1, ink)
        sfill(hx + 2, hy - 1, hw - 3, 1, _rgba(0, 0, 0, 0.14))
        stroke_round(hx, hy, hw, hh, ink)
        sfill(hx + 1, hy + 1, hw - 2, hh - 2, body)
        for yy in range(hy + 3, hy + hh - 3):
            spx(hx + 1, yy, edge_lit)
            spx(hx + hw - 2, yy, edge_shade)
        sfill(hx + 2, hy + 9, hw - 4, 1, ink)
        sfill(hx + 2, hy + 17, hw - 4, 1, ink)
        draw_lamp(cx, hy + 21, "red", slot)
        draw_lamp(cx, hy + 13, "yellow", slot)
        draw_lamp(cx, hy + 5, "green", slot)

        for y in range(GRID_H):
            self._grid[y] = list(swift[GRID_H - 1 - y])

    def blit(self, surf) -> None:
        import pygame

        s = self.scale
        for y in range(GRID_H):
            row = self._grid[y]
            for x in range(GRID_W):
                c = row[x]
                if c[:3] == KEY:
                    continue
                pygame.draw.rect(surf, c[:3], (x * s, y * s, s, s))


def _window_id(pygame_mod):
    try:
        info = pygame_mod.display.get_wm_info()
        return info.get("window")
    except Exception:
        return None


def _set_always_on_top(pygame_mod) -> None:
    """Best-effort always-on-top / skip-taskbar. Never crash the light."""
    system = platform.system()
    wid = _window_id(pygame_mod)
    if not wid:
        return
    if system == "Windows":
        try:
            import ctypes

            ctypes.windll.user32.SetWindowPos(
                int(wid), -1, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010
            )
        except Exception:
            pass
        return
    # Linux / X11 via xprop (subprocess, ignore failures)
    try:
        import subprocess

        subprocess.run(
            [
                "xprop",
                "-id",
                str(int(wid)),
                "-f",
                "_NET_WM_STATE",
                "32a",
                "-set",
                "_NET_WM_STATE",
                "_NET_WM_STATE_ABOVE,_NET_WM_STATE_SKIP_TASKBAR",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
        subprocess.run(
            [
                "xprop",
                "-id",
                str(int(wid)),
                "-f",
                "_NET_WM_WINDOW_TYPE",
                "32a",
                "-set",
                "_NET_WM_WINDOW_TYPE",
                "_NET_WM_WINDOW_TYPE_UTILITY",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
    except Exception:
        pass


def _move_window(pygame_mod, dx: int, dy: int) -> None:
    """Move borderless window by delta. Prefer SDL2; fall back to xdotool."""
    if dx == 0 and dy == 0:
        return
    try:
        from pygame._sdl2.video import Window

        win = Window.from_display_module()
        wx, wy = win.position
        win.position = (wx + dx, wy + dy)
        return
    except Exception:
        pass
    wid = _window_id(pygame_mod)
    if not wid:
        return
    try:
        import subprocess

        subprocess.run(
            ["xdotool", "windowmove", "--relative", str(int(wid)), str(dx), str(dy)],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
    except Exception:
        pass


def _apply_chrome(pygame_mod) -> None:
    # NOFRAME already set; avoid touching pygame._sdl2 Window here — it can
    # SIGSEGV on some X11 setups. Title via display.set_caption is enough.
    _set_always_on_top(pygame_mod)


def run_light(
    scale: int = DEFAULT_SCALE,
    pos: tuple[int, int] | None = None,
    screenshot_dir: str | None = None,
    screenshot_once: bool = False,
) -> int:
    try:
        import pygame
    except ImportError:
        print(
            "desktop light needs pygame.\n"
            "  Linux:   sudo apt install python3-pygame\n"
            "           (or: python3 -m pip install pygame)\n"
            "  Windows: python -m pip install pygame\n"
            "Then: python3 desktop_light.py",
            file=sys.stderr,
        )
        return 1

    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    if platform.system() == "Linux" and not os.environ.get("SDL_VIDEODRIVER"):
        os.environ.setdefault("SDL_VIDEODRIVER", "x11")

    pygame.init()
    pygame.display.set_caption("小梅信号灯")

    w, h = GRID_W * scale, GRID_H * scale
    if pos is None:
        pos = (40, 120)
    os.environ["SDL_VIDEO_WINDOW_POS"] = f"{pos[0]},{pos[1]}"

    screen = pygame.display.set_mode((w, h), pygame.NOFRAME)
    try:
        screen.set_colorkey(KEY)
    except Exception:
        pass
    _apply_chrome(pygame)

    light = PixelLight(scale=scale)
    status = read_status()
    light.state = status.get("state", "green")

    clock = pygame.time.Clock()
    dragging = False
    last_poll = 0.0
    blink_phase = 0
    next_blink = time.monotonic() + 4.8
    shots: set[str] = set()
    frame = pygame.Surface((w, h))
    running = True

    print(f"desktop light on; watching status (scale={scale})", file=sys.stderr)

    while running:
        now_m = time.monotonic()
        if now_m >= next_blink:
            if blink_phase == 0:
                light.blink_on = False
                blink_phase = 1
                next_blink = now_m + 0.28
            else:
                light.blink_on = True
                blink_phase = 0
                next_blink = now_m + 4.8

        if now_m - last_poll >= 1.0:
            status = read_status()
            light.state = status.get("state", "green")
            tip = " | ".join(
                x
                for x in (
                    status.get("label", ""),
                    status.get("detail", ""),
                    status.get("updatedAt", ""),
                )
                if x
            )
            try:
                pygame.display.set_caption(f"小梅 · {tip}" if tip else "小梅信号灯")
            except Exception:
                pass
            last_poll = now_m

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN and event.key in (pygame.K_ESCAPE, pygame.K_q):
                running = False
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                dragging = True
            elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
                dragging = False
            elif event.type == pygame.MOUSEMOTION and dragging:
                _move_window(pygame, event.rel[0], event.rel[1])

        frame.fill(KEY)
        light.redraw()
        light.blit(frame)
        screen.fill(KEY)
        screen.blit(frame, (0, 0))
        pygame.display.flip()

        if screenshot_dir and light.state not in shots and light.blink_on:
            Path(screenshot_dir).mkdir(parents=True, exist_ok=True)
            out = Path(screenshot_dir) / f"linux-desktop-light-{light.state}.png"
            pygame.image.save(frame, str(out))
            shots.add(light.state)
            print(f"saved {out}", file=sys.stderr)
            want = os.environ.get("XIAOMEI_SHOT_STATES", "")
            if screenshot_once:
                running = False
            elif want and len(shots) >= len([x for x in want.split(",") if x.strip()]):
                running = False

        clock.tick(30)

    pygame.quit()
    return 0


def main() -> None:
    p = argparse.ArgumentParser(description="小梅信号灯 desktop pixel light (Linux/Windows)")
    p.add_argument("--scale", type=int, default=DEFAULT_SCALE)
    p.add_argument("--x", type=int, default=40)
    p.add_argument("--y", type=int, default=120)
    p.add_argument("--screenshot-dir", default=None)
    p.add_argument("--screenshot-once", action="store_true")
    args = p.parse_args()
    raise SystemExit(
        run_light(
            scale=max(2, args.scale),
            pos=(args.x, args.y),
            screenshot_dir=args.screenshot_dir,
            screenshot_once=args.screenshot_once,
        )
    )


if __name__ == "__main__":
    main()
