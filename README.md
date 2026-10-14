# 小梅信号灯 · XiaomeiSignal

<p align="center"><img src="docs/screenshot.png" alt="小梅信号灯 screenshot (green lit)" width="160"></p>

**中文** | [English](#english)

为 Grok Bot 做的跨平台状态信号：`green` / `yellow` / `red`。macOS 有像素风桌面灯 + 菜单栏图标；**Linux / Windows 提供同一套 `status.json` + `set-status` CLI**，以及终端监视与可选系统托盘。

AI 助手干活时用一条命令把灯切到 绿 / 黄 / 红，你瞄一眼就知道它是在推进、在等你，还是卡住了。

> **给 Grok Bot 读的安装说明（可直接把链接丢给助手）：** [FOR-GROK-BOT.md](./FOR-GROK-BOT.md)

## 状态协议（三平台共用）

写入同一语义的 `status.json`：

| 字段 | 说明 |
|------|------|
| `state` | `green` / `yellow` / `red`（也接受 `g` / `y` / `wait` / `r` / `block`） |
| `label` | 中文标签：推进中 / 等你 / 卡住 |
| `detail` | 说明文字；若带 agent 名则形如 `【agent】内容` |
| `updatedAt` | 本机本地时间字符串 |

**状态目录（可用环境变量 `XIAOMEI_SIGNAL_DIR` 覆盖）：**

| 平台 | 默认路径 |
|------|----------|
| macOS | `~/Library/Application Support/XiaomeiSignal/` |
| Linux | `~/.local/share/XiaomeiSignal/`（或 `$XDG_DATA_HOME/XiaomeiSignal`） |
| Windows | `%LOCALAPPDATA%\XiaomeiSignal\` |

---

## macOS（像素桌面灯）

### 功能（以代码实际行为为准）

- **悬浮像素灯**：无边框、透明背景，置顶显示（status bar 层级），在所有桌面空间可见，可直接拖动位置；不占 Dock（`LSUIElement`）。
- **菜单栏小图标**：菜单栏里同时有一个迷你红黄绿灯，显示同样的状态。
- **三种状态**：`green` 推进中 / `yellow` 等你 / `red` 卡住。当前亮着的灯每约 4.8 秒短暂闪灭一次（约 0.28 秒）。
- **状态文字与来源 agent**：鼠标悬停在灯或菜单栏图标上，提示框显示 状态标签、内容（带 `【agent 名】` 前缀）和更新时间。文字不直接画在灯上。
- **影子随时间变化**：按本机本地时间计算地面投影的方向、长度和深浅（早/午/晚/夜）。
- **单击灯**（轻点，不是拖动）：把 Grok Bot 切到前台，弹通知，并更新 `current-task.md`、`user-ack.json`。
- **右键灯**：回到当前任务、显示/隐藏、复制状态、我已知晓、需支援、退出。
- 读不到 `status.json` 时显示红灯“读不到状态”。App 每秒读取一次状态文件。

### 环境要求

- macOS（在 macOS 26 / Apple Silicon 上使用过）
- Xcode Command Line Tools（`swiftc`、`python3`）：`xcode-select --install`
- Grok Bot 桌面 App 在 `/Applications/Grok Bot.app`（监视脚本按此路径识别主进程）

### 安装

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

`install.sh` 会编译 `XiaomeiSignal.swift` → `~/Applications/小梅信号灯.app`，安装脚本与 LaunchAgent。只影响当前用户，不需要 sudo。

### 切换状态

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" <green|yellow|red> "<内容>" "<agent 名>"
```

### 卸载

```bash
bash uninstall.sh          # 保留状态文件夹
bash uninstall.sh --purge  # 连状态目录一起删
```

---

## Linux（CLI + 可选托盘）

### 环境要求

- Python 3.8+
- （可选托盘）`pip install --user pystray pillow`，以及系统托盘 / AppIndicator 支持

### 安装

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install-linux.sh
```

会把脚本装到 `~/.local/share/XiaomeiSignal/`，并在 `~/.local/bin/` 建符号链接：`xiaomei-set-status`、`xiaomei-show-status`、`xiaomei-tray`。

### 使用

```bash
# 切换状态（PATH 已含 ~/.local/bin 时）
xiaomei-set-status green  "正在改代码" "开发"
xiaomei-set-status yellow "等你确认"   "开发"
xiaomei-set-status red    "测试失败"   "开发"

# 或直接
bash "$HOME/.local/share/XiaomeiSignal/set-status" yellow "等你" "小梅"
python3 "$HOME/.local/share/XiaomeiSignal/set-status.py" green "推进中" "小梅"

# 终端监视（状态变化时打印一行）
xiaomei-show-status -w

# 可选：系统托盘
python3 -m pip install --user pystray pillow
xiaomei-tray
```

### 怎么测

```bash
bash install-linux.sh
xiaomei-set-status yellow "安装完成，等你看一眼" "小梅"
xiaomei-show-status          # 应看到 yellow
cat ~/.local/share/XiaomeiSignal/status.json
xiaomei-set-status green "推进中" "小梅"
```

### 卸载

```bash
bash uninstall-linux.sh          # 保留 status.json
bash uninstall-linux.sh --purge  # 删除整个数据目录
```

---

## Windows（CLI + 可选托盘）

### 环境要求

- Python 3.8+（安装时勾选 Add to PATH）
- （可选托盘）`python -m pip install --user pystray pillow`

### 安装

在 PowerShell：

```powershell
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

脚本复制到 `%LOCALAPPDATA%\XiaomeiSignal\`。

### 使用

```powershell
$dir = "$env:LOCALAPPDATA\XiaomeiSignal"
& "$dir\set-status.cmd" yellow "等你确认" "小梅"
python "$dir\set-status.py" green "推进中" "小梅"
python "$dir\show-status.py" -w

# 可选托盘
python -m pip install --user pystray pillow
python "$dir\tray.py"
```

### 怎么测

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
$dir = "$env:LOCALAPPDATA\XiaomeiSignal"
& "$dir\set-status.cmd" yellow "安装完成" "小梅"
python "$dir\show-status.py"
Get-Content "$dir\status.json"
& "$dir\set-status.cmd" green "推进中" "小梅"
```

> 本仓库的 CI / 云端 Linux 环境无法打开真实 Windows GUI；Windows 托盘需在本机验证。CLI（`set-status.py` / `show-status.py`）与 macOS/Linux 共用同一 Python 逻辑，语义一致。

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
# 或彻底删除：
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 --purge
```

---

## 仓库里直接跑（不安装）

三平台都可以在 clone 目录下：

```bash
python3 set-status.py green "试一下" "小梅"
python3 show-status.py -w
```

Windows 把 `python3` 换成 `python` 即可。

---

## 作者与许可

作者：Mayrian · [MIT License](LICENSE)

---

<a id="english"></a>

## English

Cross-platform status signal for Grok Bot: `green` / `yellow` / `red`. **macOS** ships a pixel desktop lamp + menu bar icon; **Linux / Windows** share the same `status.json` + `set-status` CLI, plus a terminal watcher and an optional system tray.

### Shared protocol

Status file fields: `state`, `label`, `detail`, `updatedAt`. Directories:

- macOS: `~/Library/Application Support/XiaomeiSignal/`
- Linux: `~/.local/share/XiaomeiSignal/`
- Windows: `%LOCALAPPDATA%\XiaomeiSignal\`
- Override: `XIAOMEI_SIGNAL_DIR`

### macOS

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git && cd xiaomei-signal && bash install.sh
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green|yellow|red "<text>" "<agent>"
```

### Linux

```bash
bash install-linux.sh
xiaomei-set-status yellow "Waiting for you" "Xiaomei"
xiaomei-show-status -w
# optional: pip install --user pystray pillow && xiaomei-tray
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
& "$env:LOCALAPPDATA\XiaomeiSignal\set-status.cmd" yellow "Waiting" "Xiaomei"
python "$env:LOCALAPPDATA\XiaomeiSignal\show-status.py" -w
```

### Author & license

Author: Mayrian · [MIT License](LICENSE)
