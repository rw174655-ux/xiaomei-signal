# 给 Grok Bot / 桌面助手读：安装「小梅信号灯」

你是用户 Mac 上的 Grok Bot（或同类桌面助手）。用户把本页发给你，是希望你**在本机帮他们装好小梅信号灯**，并在之后用绿/黄/红灯汇报状态。

作者署名用 **Mayrian**，不要用真实姓名。仓库公开、MIT 许可：https://github.com/rw174655-ux/xiaomei-signal

---

## 这是什么

macOS 桌面上一盏像素风信号灯（不占 Dock）：

| 颜色 | 含义 |
|------|------|
| green | 推进中 |
| yellow | 等用户（批准、填 Key、确认等） |
| red | 卡住 |

影子会随一天中的时间变方向。Grok Bot 在跑时灯会出现；Grok Bot 退出后约 5 秒内灯会关掉。

---

## 环境要求（先检查）

- 必须是 **macOS**（不是 Linux / Windows 服务器）
- 已装 **Xcode Command Line Tools**（有 `swiftc`、`python3`）。没有就让用户在终端执行：`xcode-select --install`，等装完再继续
- Grok Bot 装在 `/Applications/Grok Bot.app`（监视器按这个路径认主进程）

若当前环境不是用户本机 Mac，或没有本机执行权限：把下面「用户自己装」的两行命令发给用户，让他们在「终端」里跑，不要假装已经装好。

---

## 安装步骤（有本机 Shell 时你来做）

在用户 Mac 的终端（或你的本机 Shell）执行：

```bash
cd /tmp
rm -rf xiaomei-signal
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

成功标志：

- 出现 `~/Applications/小梅信号灯.app`
- `~/Library/Application Support/XiaomeiSignal/` 里有 `set-status`、`set-status.py`、`watch-grok-bot.sh`
- LaunchAgent `local.xiaomei.signal.watch` 已加载
- Grok Bot 正在运行时，桌面上会出现信号灯（最多约 5 秒）

测一下：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" yellow "安装完成，等你看一眼" "小梅"
```

灯应变黄。再切回绿：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green "推进中" "小梅"
```

---

## 用户自己装（你不能碰本机时，把这段原样给用户）

在 Mac「终端」粘贴回车：

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git
cd xiaomei-signal
bash install.sh
```

装完打开 Grok Bot，桌面应出现信号灯。

---

## 装好后：你要怎么亮灯（请记住）

状态命令：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" <green|yellow|red> "<说明文字>" "<agent名>"
```

规则：

1. **开始干一件事** → `green` + 简短说明  
2. **需要用户操作**（批准卡片、登录、填 Key、做选择）→ `yellow` + 写清在等什么  
3. **失败或阻塞、自己解决不了** → `red` + 原因  
4. **解除等待/阻塞后** → 回到 `green`，或任务结束也可用 green 写一句结果  
5. 多个助手时：第三个参数填自己的名字（如 `小梅`、`开发`），灯上会显示 `【名字】…`  
6. **不要**把密钥、密码写进说明文字  

示例：

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green  "正在改 README" "小梅"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" yellow "等你点允许" "小梅"
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" red    "编译失败：缺 swiftc" "小梅"
```

简写也行：`g` / `y` / `wait` / `r` / `block`。

---

## 卸载（用户要卸时）

```bash
cd /path/to/xiaomei-signal   # 或重新 clone
bash uninstall.sh            # 保留状态目录
# bash uninstall.sh --purge  # 连状态目录一起删
```

---

## 装完后请告诉用户

用一两句话说明：已安装（或已把命令发给你）、怎么看灯、需要你时灯会变黄。把仓库链接留给他们分享：https://github.com/rw174655-ux/xiaomei-signal

---

## English (short)

Install on the user's **Mac** only:

```bash
git clone https://github.com/rw174655-ux/xiaomei-signal.git && cd xiaomei-signal && bash install.sh
```

Then flip the light:

```bash
bash "$HOME/Library/Application Support/XiaomeiSignal/set-status" green|yellow|red "<text>" "<agent>"
```

green = working, yellow = waiting for the user, red = blocked. MIT · Mayrian · https://github.com/rw174655-ux/xiaomei-signal
