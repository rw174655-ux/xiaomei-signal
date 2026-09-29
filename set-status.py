#!/usr/bin/env python3
import json, sys
from datetime import datetime
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("usage: set-status.py green|yellow|red detail [source-agent]")
        sys.exit(1)
    raw = sys.argv[1].lower()
    detail = sys.argv[2] if len(sys.argv) > 2 else ""
    source = sys.argv[3] if len(sys.argv) > 3 else ""
    mapping = {
        "green": ("green", "推进中"),
        "g": ("green", "推进中"),
        "yellow": ("yellow", "等你"),
        "y": ("yellow", "等你"),
        "wait": ("yellow", "等你"),
        "red": ("red", "卡住"),
        "r": ("red", "卡住"),
        "block": ("red", "卡住"),
    }
    if raw not in mapping:
        print("usage: set-status.py green|yellow|red detail [source-agent]")
        sys.exit(1)
    state, label = mapping[raw]
    if source:
        detail = f"【{source}】{detail}"
    now = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    d = Path.home() / "Library/Application Support/XiaomeiSignal"
    d.mkdir(parents=True, exist_ok=True)
    status = {"state": state, "label": label, "detail": detail, "updatedAt": now}
    (d / "status.json").write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    task = (
        f"# 当前任务\n\n"
        f"- 状态：**{label}**\n"
        f"- 更新：{now}\n\n"
        f"## 内容\n\n{detail}\n\n"
        f"---\n点击信号灯可回到此任务（会打开 Grok Bot）。\n"
    )
    (d / "current-task.md").write_text(task, encoding="utf-8")
    print("OK", state, label)

if __name__ == "__main__":
    main()
