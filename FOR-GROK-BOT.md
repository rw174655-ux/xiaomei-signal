# 给 Grok Bot / 桌面助手读：安装「小梅信号灯」

你是用户机器上的 Grok Bot（或同类助手）。用户把本页发给你，是希望你**在本机帮他们装好小梅信号灯**，并在之后用绿/黄/红灯汇报状态。

作者署名用 **Mayrian**，不要用真实姓名。仓库公开、MIT 许可：https://github.com/rw174655-ux/xiaomei-signal

---

## 这是什么

| 颜色 | 含义 |
|------|------|
| green | 推进中 |
| yellow | 等用户（批准、填 Key、确认等） |
| red | 卡住 |

- **macOS**：桌面像素灯 + 菜单栏图标（Swift App）。Grok Bot 在跑时灯会出现；退出后约 5 秒内关掉。
- **Linux / Windows**：同一套 `status.json` + `set-status`；用终端 `show-status -w` 或可选系统托盘看状态。

**状态目录：**

| 平台 | 路径 |
|------|------|
| macOS | `~/Library/Application Support/XiaomeiSignal/` |
| Linux | `~/.local/share/XiaomeiSignal/` |
| Windows | `%LOCALAPPDATA%\XiaomeiSignal\` |

可用环境变量 `XIAOMEI_SIGNAL_DIR` 覆盖。

---

## 先判断平台

用 `uname -s`（或 Windows 上 `$env:OS`）判断，再走对应章节。**不要**在 Linux/Windows 上跑 `install.sh`（那是 macOS Swift 安装器）；**不要**改/删 `XiaomeiSignal.swift`。

---

## macOS

### 环境

- 必须是用户本机 **macOS**
- 已装 Xcode Command Line Tools（`swiftc`、`python3`）；没有就让用户执行：`xcode-select --install`
- Grok Bot 在 `/Applications/Grok Bot.app`

### 你来装

```bash
cd /tmp
rm -rf xiaomei-signal
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

测一下：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" yellow "安装完成，等你看一眼" "小梅"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green "推进中" "小梅"
```

### 用户自己装（你不能碰本机时，原样发给用户）

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

### 卸载

```bash
bash uninstall.sh            # 保留状态目录
# bash uninstall.sh --purge  # 连状态目录一起删
```

---

## Linux

### 环境

- `python3`（3.8+）
- 可选托盘：`python3 -m pip install --user pystray pillow`

### 你来装

```bash
cd /tmp
rm -rf xiaomei-signal
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install-linux.sh
```

确保 `~/.local/bin` 在 PATH 里（没有就 `export PATH="$HOME/.local/bin:$PATH"`）。

测一下：

```bash
xiaomei-set-status yellow "安装完成，等你看一眼" "小梅"
xiaomei-show-status
# 持续监视：
xiaomei-show-status -w
# 可选托盘：
# python3 -m pip install --user pystray pillow && xiaomei-tray
```

或不用 symlink：

```bash
bash "$HOME/.local/share/XiaomeiSignal/set-status" green "推进中" "小梅"
python3 "$HOME/.local/share/XiaomeiSignal/show-status.py"
```

### 卸载

```bash
bash uninstall-linux.sh
# bash uninstall-linux.sh --purge
```

---

## Windows

### 环境

- Python 3（已加入 PATH）
- 可选托盘：`python -m pip install --user pystray pillow`

### 你来装（PowerShell）

```powershell
cd $env:TEMP
if (Test-Path xiaomei-signal) { Remove-Item -Recurse -Force xiaomei-signal }
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

测一下：

```powershell
$dir = "$env:LOCALAPPDATA\XiaomeiSignal"
& "$dir\set-status.cmd" yellow "安装完成，等你看一眼" "小梅"
python "$dir\show-status.py"
& "$dir\set-status.cmd" green "推进中" "小梅"
python "$dir\show-status.py" -w
```

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1
# powershell -ExecutionPolicy Bypass -File .\uninstall-windows.ps1 --purge
```

---

## 装好后：你要怎么亮灯（请记住）

按平台选一条（语义相同）：

**macOS**

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" <green|yellow|red> "<说明>" "<agent名>"
```

**Linux**

```bash
xiaomei-set-status <green|yellow|red> "<说明>" "<agent名>"
# 或
bash "$HOME/.local/share/XiaomeiSignal/set-status" <green|yellow|red> "<说明>" "<agent名>"
```

**Windows**

```powershell
& "$env:LOCALAPPDATA\XiaomeiSignal\set-status.cmd" <green|yellow|red> "<说明>" "<agent名>"
```

**任意平台（在仓库目录或不安装时）**

```bash
python3 set-status.py green|yellow|red "<说明>" "<agent名>"
```

规则：

1. **开始干一件事** → `green` + 简短说明  
2. **需要用户操作** → `yellow` + 写清在等什么  
3. **失败或阻塞** → `red` + 原因  
4. **解除等待/阻塞后** → 回到 `green`  
5. 多个助手时：第三个参数填自己的名字（如 `小梅`、`开发`）  
6. **不要**把密钥、密码写进说明文字  
7. 消息里可带标记：`【信号灯】yellow` / `green` / `red`（给人看的；真正亮灯仍要跑上面的命令）

简写：`g` / `y` / `wait` / `r` / `block`。

---

## 装完后请告诉用户

用一两句话说明：已按哪一平台安装、怎么看状态（macOS 看桌面灯；Linux/Windows 看终端 `show-status -w` 或托盘）、需要你时会变黄。仓库链接：https://github.com/rw174655-ux/xiaomei-signal

---

## English (short)

| Platform | Install | Set status |
|----------|---------|------------|
| macOS | `bash install.sh` | `bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green\|yellow\|red "<text>" "<agent>"` |
| Linux | `bash install-linux.sh` | `xiaomei-set-status green\|yellow\|red "<text>" "<agent>"` |
| Windows | `install-windows.ps1` | `& "$env:LOCALAPPDATA\XiaomeiSignal\set-status.cmd" ...` |

green = working, yellow = waiting for the user, red = blocked. MIT · Mayrian · https://github.com/rw174655-ux/xiaomei-signal
