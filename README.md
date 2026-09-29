# 小梅信号灯 · XiaomeiSignal

<p align="center"><img src="docs/screenshot.png" alt="小梅信号灯 screenshot (green lit)" width="160"></p>

**中文** | [English](#english)

为 Grok Bot 桌面 App 做的像素风 macOS 桌面信号灯。**灯下的影子会随一天中的时间变换方向**——像阳光在移动：早上影子朝左拉长，中午缩到脚下，下午转向右边，夜里只剩淡淡一小块；灯罩上的高光和机身亮/暗边也跟着“太阳”一起换边。

AI 助手干活时用一条命令把灯切到 绿 / 黄 / 红，你瞄一眼桌面就知道它是在推进、在等你，还是卡住了。

## 功能（以代码实际行为为准）

- **悬浮像素灯**：无边框、透明背景，置顶显示（status bar 层级），在所有桌面空间可见，可直接拖动位置；不占 Dock（`LSUIElement`）。
- **菜单栏小图标**：菜单栏里同时有一个迷你红黄绿灯，显示同样的状态。
- **三种状态**：`green` 推进中 / `yellow` 等你 / `red` 卡住。当前亮着的灯每约 4.8 秒短暂闪灭一次（约 0.28 秒）。
- **状态文字与来源 agent**：鼠标悬停在灯或菜单栏图标上，提示框显示 状态标签、内容（带 `【agent 名】` 前缀）和更新时间。文字不直接画在灯上。
- **影子随时间变化**：按本机本地时间计算地面投影的方向、长度和深浅：
  - 20:00–05:30 夜间：短而淡的影子
  - 05:30–07:00 清晨：影子朝左、较长
  - 07:00–11:00 上午：影子从左侧逐渐移向脚下
  - 11:00–13:00 正午：短影子基本在正下方
  - 13:00–17:00 下午：影子逐渐转向右侧并变长
  - 17:00–20:00 傍晚：影子在右侧，逐渐变淡

  亮灯上的白色高光位于“光源”一侧（与影子相反），机身左右边缘的亮/暗面也随之互换。
- **单击灯**（轻点，不是拖动）：把 Grok Bot 切到前台（`open -a "Grok Bot"`），弹一条系统通知，并更新 `current-task.md`、`user-ack.json`。
- **右键灯**：弹出菜单——回到当前任务、显示/隐藏、复制状态、我已知晓、需支援、退出。“我已知晓”“需支援”会写入 `user-ack.json`（留给 agent 读取，App 本身不读它）。
- 读不到 `status.json` 时显示红灯“读不到状态”。App 每秒读取一次状态文件。

## 环境要求

- macOS（在 macOS 26 / Apple Silicon 上使用过）
- Xcode Command Line Tools（提供 `swiftc` 和 `python3`）：`xcode-select --install`
- Grok Bot 桌面 App 安装在 `/Applications/Grok Bot.app`（监视脚本按这个路径识别主进程）

## 安装

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

`install.sh` 会：

1. 用 `swiftc` 编译 `XiaomeiSignal.swift`，生成 `~/Applications/小梅信号灯.app`
2. 把 `set-status`、`set-status.py`、`watch-grok-bot.sh` 复制到 `~/Library/Application Support/XiaomeiSignal/`
3. 用模板 `local.xiaomei.signal.watch.plist.template` 生成 `~/Library/LaunchAgents/local.xiaomei.signal.watch.plist`（把占位符替换成你自己的路径）并加载

只影响当前用户，不需要 sudo。

## 使用：切换状态

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" <green|yellow|red> "<内容>" "<agent 名>"
```

例子：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green  "正在写 README" "小梅"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" yellow "等你确认发布"  "小梅"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" red    "编译失败"      "小梅"
```

- 也接受简写：`g` / `y` / `wait` / `r` / `block`
- 第三个参数（agent 名）可省略；填了会以 `【agent 名】内容` 的形式显示
- 状态写入 `~/Library/Application Support/XiaomeiSignal/status.json`，灯在 1 秒内刷新

可以把这条命令写进 Grok Bot 的指令/记忆里，让 agent 在开始、等待你、卡住时自动调用。

## Grok Bot 监视器如何工作

LaunchAgent `local.xiaomei.signal.watch`（`RunAtLoad` + `KeepAlive`）在登录后常驻运行 `watch-grok-bot.sh`，每 5 秒检查一次：

- Grok Bot **主进程**在运行（`/Applications/Grok Bot.app/Contents/MacOS/Grok Bot`，或进程名正好是 `Grok Bot`），而信号灯没开 → 打开信号灯
- Grok Bot 主进程不在了，而信号灯还开着 → 结束信号灯（`pkill`）

所以 Grok Bot 退出后，灯最多约 5 秒内消失。只看主进程，不看 Helper 进程（Helper 退出较慢，会让灯一直亮着）。注意：Grok Bot 运行期间如果从菜单“退出”信号灯，监视器会在 5 秒内把它重新打开；想暂时收起请用“显示/隐藏”。日志写在 `~/Library/Application Support/XiaomeiSignal/watch.log`。

## 卸载

```bash
bash uninstall.sh          # 停止监视器、删除 LaunchAgent 和 App，保留状态文件夹
bash uninstall.sh --purge  # 同时删除 ~/Library/Application Support/XiaomeiSignal
```

## 作者与许可

作者：Mayrian · [MIT License](LICENSE)

---

<a id="english"></a>

## English

A pixel-art macOS desktop status light for the Grok Bot desktop app. **The lamp's ground shadow moves with the time of day**, like sunlight: long and to the left in the morning, short and underneath at noon, swinging to the right in the afternoon, faint and short at night. The specular highlight on the lit lamp and the light/dark edges of the housing switch sides along with the "sun".

Your AI agent flips the light to green / yellow / red with a single command, so a glance at the desktop tells you whether it's working, waiting for you, or stuck.

### Features (as the code actually behaves)

- **Floating pixel lamp**: borderless, transparent, always on top (status-bar level), visible on all Spaces, draggable; no Dock icon (`LSUIElement`).
- **Menu bar icon**: a mini traffic light in the menu bar mirrors the same state.
- **Three states**: `green` 推进中 (in progress) / `yellow` 等你 (waiting for you) / `red` 卡住 (blocked). The lit lamp blinks off briefly (~0.28 s) about every 4.8 s.
- **Status text and agent name**: hover over the lamp or the menu bar icon to see a tooltip with the label, the detail text (prefixed with `【agent】`), and the update time. The text is not drawn on the lamp itself.
- **Time-of-day shadow**: direction, length and darkness of the ground shadow are computed from the Mac's local time:
  - 20:00–05:30 night: short, faint shadow
  - 05:30–07:00 early morning: long shadow to the left
  - 07:00–11:00 morning: shadow moves from the left toward the base
  - 11:00–13:00 noon: short shadow roughly underneath
  - 13:00–17:00 afternoon: shadow swings right and grows longer
  - 17:00–20:00 evening: shadow on the right, fading

  The white highlight on the lit lamp sits on the light-source side (opposite the shadow), and the housing's lit/shaded edges swap accordingly.
- **Left-click** (a short click, not a drag): brings Grok Bot to the front (`open -a "Grok Bot"`), shows a macOS notification, and updates `current-task.md` and `user-ack.json`.
- **Right-click**: opens the menu — 回到当前任务 (return to current task), 显示/隐藏 (show/hide), 复制状态 (copy status), 我已知晓 (acknowledge), 需支援 (need help), 退出 (quit). "Acknowledge" and "need help" write to `user-ack.json` (for an agent to read; the app itself doesn't read it).
- If `status.json` can't be read, the lamp shows red "读不到状态" (can't read status). The app re-reads the status file every second.

### Requirements

- macOS (used on macOS 26, Apple Silicon)
- Xcode Command Line Tools (for `swiftc` and `python3`): `xcode-select --install`
- Grok Bot desktop app at `/Applications/Grok Bot.app` (the watcher matches the main process by this path)

### Install

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

`install.sh`:

1. compiles `XiaomeiSignal.swift` with `swiftc` into `~/Applications/小梅信号灯.app`
2. copies `set-status`, `set-status.py` and `watch-grok-bot.sh` to `~/Library/Application Support/XiaomeiSignal/`
3. renders `local.xiaomei.signal.watch.plist.template` (placeholder → your own path) into `~/Library/LaunchAgents/local.xiaomei.signal.watch.plist` and loads it

Current user only; no sudo needed.

### Usage: set the status

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" <green|yellow|red> "<text>" "<agent>"
```

Examples:

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green  "Writing the README"      "Xiaomei"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" yellow "Waiting for your OK"    "Xiaomei"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" red    "Build failed"           "Xiaomei"
```

- Short forms also work: `g` / `y` / `wait` / `r` / `block`
- The agent name is optional; when given, the detail is shown as `【agent】text`
- The status is written to `~/Library/Application Support/XiaomeiSignal/status.json`; the lamp picks it up within a second

Put this command in your Grok Bot instructions/memory so agents call it when they start, need you, or get stuck.

### How the Grok Bot watcher works

The LaunchAgent `local.xiaomei.signal.watch` (`RunAtLoad` + `KeepAlive`) keeps `watch-grok-bot.sh` running after login. Every 5 seconds it checks:

- Grok Bot's **main process** is running (`/Applications/Grok Bot.app/Contents/MacOS/Grok Bot`, or a process named exactly `Grok Bot`) and the light isn't → open the light
- Grok Bot's main process is gone and the light is still running → stop the light (`pkill`)

So the light disappears within about 5 seconds after Grok Bot quits. Only the main process counts, not Helper processes (they can linger and would keep the light up). Note: if you choose 退出 (quit) from the menu while Grok Bot is running, the watcher reopens the light within 5 seconds; use 显示/隐藏 (show/hide) to tuck it away instead. The log is at `~/Library/Application Support/XiaomeiSignal/watch.log`.

### Uninstall

```bash
bash uninstall.sh          # stop the watcher, remove the LaunchAgent and the app; keep the status folder
bash uninstall.sh --purge  # also delete ~/Library/Application Support/XiaomeiSignal
```

### Author & license

Author: Mayrian · [MIT License](LICENSE)
