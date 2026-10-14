#!/usr/bin/env python3
"""Shared paths and status.json I/O for 小梅信号灯 (macOS / Linux / Windows)."""
from __future__ import annotations

import json
import os
import platform
from datetime import datetime
from pathlib import Path
from typing import Any

STATE_MAP = {
    "green": ("green", "推进中"),
    "g": ("green", "推进中"),
    "yellow": ("yellow", "等你"),
    "y": ("yellow", "等你"),
    "wait": ("yellow", "等你"),
    "red": ("red", "卡住"),
    "r": ("red", "卡住"),
    "block": ("red", "卡住"),
}

DEFAULT_LABELS = {"green": "推进中", "yellow": "等你", "red": "卡住"}


def support_dir() -> Path:
    """Platform data directory. Override with env XIAOMEI_SIGNAL_DIR."""
    override = os.environ.get("XIAOMEI_SIGNAL_DIR")
    if override:
        return Path(override).expanduser()
    system = platform.system()
    if system == "Darwin":
        return Path.home() / "Library/Application Support/XiaomeiSignal"
    if system == "Windows":
        base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
        return Path(base) / "XiaomeiSignal"
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return Path(xdg) / "XiaomeiSignal"
    return Path.home() / ".local/share/XiaomeiSignal"


def status_path() -> Path:
    return support_dir() / "status.json"


def normalize_state(raw: str) -> str:
    key = raw.lower().strip()
    if key in STATE_MAP:
        return STATE_MAP[key][0]
    if key in ("green", "yellow", "red"):
        return key
    return "green"


def write_status(raw_state: str, detail: str = "", source: str = "") -> dict[str, Any]:
    raw = raw_state.lower().strip()
    if raw not in STATE_MAP:
        raise ValueError(f"unknown state: {raw_state}")
    state, label = STATE_MAP[raw]
    if source:
        detail = f"【{source}】{detail}"
    now = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    d = support_dir()
    d.mkdir(parents=True, exist_ok=True)
    status = {"state": state, "label": label, "detail": detail, "updatedAt": now}
    (d / "status.json").write_text(
        json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    task = (
        f"# 当前任务\n\n"
        f"- 状态：**{label}**\n"
        f"- 更新：{now}\n\n"
        f"## 内容\n\n{detail}\n\n"
        f"---\n点击信号灯可回到此任务（会打开 Grok Bot）。\n"
    )
    (d / "current-task.md").write_text(task, encoding="utf-8")
    return status


def read_status() -> dict[str, Any]:
    path = status_path()
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(obj, dict):
            raise ValueError("not a dict")
    except (OSError, json.JSONDecodeError, ValueError):
        return {
            "state": "red",
            "label": "卡住",
            "detail": "读不到状态",
            "updatedAt": "",
        }
    state = normalize_state(str(obj.get("state", "green")))
    label = obj.get("label") or DEFAULT_LABELS.get(state, state)
    return {
        "state": state,
        "label": str(label),
        "detail": str(obj.get("detail") or ""),
        "updatedAt": str(obj.get("updatedAt") or ""),
    }


def platform_name() -> str:
    return platform.system()
