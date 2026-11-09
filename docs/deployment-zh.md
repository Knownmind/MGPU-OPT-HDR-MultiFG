# 部署说明

> 作者：电子羊羊尾（小黑盒 ID 38096711）｜**免费分享，禁止倒卖/付费售卖**（付费购得请退款并举报）

> **HDR 用户注意**：先开 Windows「设置→系统→显示→HDR」并确认显示器 HDR 模式，再用 `first-run.ps1` 选 HDR/写 `ChainColorSpace=12`；否则画面会整幅发灰。

> 部署前请先填好 **README.md 顶部的「部署前必答清单」** 并发给 AI；不确定的项按括号默认值处理。

> **🤖 推荐使用 AI 部署**：把本包交给 AI 助手（如 WorkBuddy），按 `README.md` 的步骤执行与排障，通常比手工试快。
> **WorkBuddy 邀请链接（注册双方得积分）**：<https://www.workbuddy.cn/events/invite?inviteCode=5x802lsf20kj54>


> 本文件是**部署与排障说明**；包内最新版本号、文件校验值与相对上游的增量清单以同目录 **`README.md`** 为准。

> 一份文档搞定：先看 §1 的 30 秒版；跑不通再按 §6 排查。

---

## 1. 30 秒版

### 前置
| 条件 | 说明 |
|---|---|
| **一张 RTX 50 系** | DLSS 5 NR 只在 Blackwell 第五代 Tensor Core 上跑，硬门槛 |
| **第二张卡跑游戏** | AMD / NVIDIA 都行，只要不是同一张 |
| **显示器接在 RTX 50 那张卡上** | 桥默认 `DcompOverlay=1`，神经输出直接画在游戏窗口上 |
| **跑游戏的卡不接显示器** | 单屏也不行（除非 `DcompOverlay=0` 的双屏模式） |
| Windows 11 + DX12 游戏 | 不支持 Vulkan |
| ReShade 6.8.0+（**add-on 版**） | effects-only 版加载不了 `.addon64`；包内已带 |

### 三步
1. 退出游戏。
2. 把 `Win64/` 的**全部内容**（含 `mgpu\`、`reshade-shaders\` 两个子目录）复制进游戏 exe 同目录。
3. 启动游戏 → 进主菜单后按一次 Enter（或跑 `tools/进游戏-自动继续.ps1`）。

### 验收：日志里三行
```
[H1]   … SetColorSpace1 hr=0x00000000            → PQ 链声明生效（HDR 正确）
[FG]   ARMED: 1 intermediate frame(s) (2x)       → 插帧起来
[NVOF] armed: … grid=2 perf=20 … negate=1        → 光流前馈起来（否则插帧会拉扯）
```
日志：游戏 exe 同目录 `ReShade.log`。也可跑
`tools/selfcheck.ps1 -GameDir <游戏目录> -Log <ReShade.log>`。

---

## 2. 文件放对位置（最常见的跑不通原因）

```
游戏目录\
├── dxgi.dll                        ← ReShade（add-on 版）
├── ReShade.ini                     ← 检查 EffectSearchPaths
├── ReShade2.ini / gpu1.ini         ← 桥自己的 runtime 配置（别删）
├── renodx-jedisurvivor.addon64     ← RenoDX（可选，HDR 调色）
├── nvngx.dll_mgpu_bridge.addon64   ← 文件名必须含字面量 "nvngx.dll"
├── mgpu.ini                        ← 配置
├── mgpu\
│   ├── nvngx_dlssnr.dll            ← ★ 必须在 mgpu\ 里，不能放 exe 旁
│   ├── nvngx_dlssg.dll             ← 帧生成（可选但本包已带）
│   ├── vendor_gpu.dll              ← 真 NvAPI
│   └── vendor_dlss.dll             ← 私有 DLSS 运行时
└── reshade-shaders\Shaders\
    └── mgpu_depth_tap.fx           ← ★ 放这里，否则永远等深度
```

### 三个最常见的错误

**① `nvngx_dlssnr.dll` 放错位置** —— 放 exe 旁边会被游戏自己加载 → 神经阶段崩溃。

**② `mgpu_depth_tap.fx` 没生效** —— 文件放对还不够，`ReShade.ini` 的
`EffectSearchPaths` 必须能找到它。验证：日志 `[MGPU][P1.6] GAME runtime` 的
technique 数**非零**；是 0 就一直等深度、永不 arm。

**③ `ReShade.ini` 的 `[DEPTH] DepthCopyBeforeClears` 必须是 `1`** ——
写成 2 会抓到已清空的缓冲，`[R244]` 变成 `at 0.0=100.0%` 的空图，NR 遮挡判断全废。

---

## 3. 配置里最容易写错的五个键

```ini
ChainColorSpace=12       ; 游戏 HDR 开 → 12（ST.2084 PQ）；HDR 关 → 0
;MVecUnits=              ; 不要写死！注释掉，让 arm 自己判定（第 5 条）
Style=0.00               ; 只能用 0（A 档），B/C 必闪
;NRSteady=               ; 不必写：本机已排除它是闪烁根因（见第 4 条）
```

- **`ChainColorSpace` 写错** = 整幅偏色（发灰或过曝）。判据：日志有
  `[H1] … support=0x1 -> SetColorSpace1 hr=0` 才算生效。
- **`MVecUnits` 写死 = 静态闪砂（2026-11-02 16:14 单变量定案）**：它必须留空，由 arm 按 R280
  判定单位（`uv`/`uvhalf`/`px`）并在每次启动按本次尺寸推导 scale。写死成 `uv` 后历史帧会被投到
  错误的亚像素位置 —— **静止时**灯下 / 中远距细纹理 / 屋顶阴影处逐帧跳砂，动起来更重。
  判据：`[R87] MVEC FRAME ALIGNMENT … at 1` 低于 95%（干净基线上实测 93.9%→ 已对齐；写死时 87.2%）。
  `uv` 时 scale=宽/高比（3440/1440≈2.39），`px` 时 scale=1.0。
- **`Style` 必须 0**：B/C 档对时域状态依赖更高，拿不到真 jitter 时必闪。
- **`NRSteady` 不是本机元凶（2026-11-02 16:12 更正，已排除）**：它被 `NRInput16=4` 门控，
  复现态的 ini 里根本没开（10-31 日志里只有 `[R208] FP16 INPUT PATH ON`，无 `NRSteady ON`）。
  早前"`NRSteady=0` 修好了闪烁"是把"换回基线 ini"与"加这个键"混在了一起。排障请先看第 5 条。

---

## 4. 本包与上游默认的差异（都已写进 `mgpu.ini`）

| 键 | 上游默认 | 本包 | 为什么 |
|---|---|---|---|
| `ChainColorSpace` | 无生效行 | `12` | 不写就是 DXGI 默认 SDR 解释 → HDR 下灰白 |
| `NVOF` 块 | 无 | `NVOF=1 Grid=2 Perf=20 Negate=1 ScaleX/Y=1.0 Probe=1 Log=300` | 没有光流前馈时裸 DLSS-G 会**拉扯/边缘错位** |
| `TemporalRequireTuple` | — | `1` | 不绑定属于另一帧的矢量 |
| `TemporalResetK` | — | `3` | 跨 3 帧没对上就重置 NR 历史（治"明暗呼吸"） |
| `FGCount` / `FGTargetHz` | — | `1` / `0` | 2x 插帧；`0` = 不按固定帧率节流 |
| `AntiFlicker` | 0 | 0 | 上游自注"实测无效且与 FG 冲突"，别开 |
| `MVecUnits` | 写了就会生效 | ⚠️ 模板里保持注释 | **写死 = 静态闪砂**（历史投影错位）；留空让 arm 判定 |
| `NRSteady` | 未写=**开**（仅含 R360 的构建） | 不写 | 已被排除为闪烁根因（见 §3 第 5 条）；若要关就写 `0` |

**关于插帧**：上游 README 明说 *"Frame generation: Not recommended. It still flickers, as in 0.3.x."*。
本包补上 `NVOF` 块后实测 **拉扯消失**（`HEARTBEAT generated=18,600 shown=18,599 failed=0`），
但插帧的时域闪烁仍是已知弱项 —— 要稳就先 `CTRL+ALT+F12` 关掉插帧，只留 NR。

## 5. 热键

| 键 | 作用 |
|---|---|
| `CTRL+ALT+F10` | 手动布防（游戏中） |
| `CTRL+ALT+F12` | 光流插帧 开/关 |
| `CTRL+ALT+F7` | 视图：NR 输出 → 输入 → 左右分割 |
| `CTRL+ALT+← / →` | 移动分割线（SHIFT 粗调） |
| `CTRL+ALT+F9 / F11` | NR 强度 −/+（0.05 一档，0–2.00） |
| `CTRL+ALT+F8` | 切换强度目标（all / p1 / p2 …） |
| `CTRL+ALT+F6` | 隐藏/恢复桥画面（让位给游戏自己的 ReShade 面板） |
| `CTRL+ALT+F5` | OSD（显示的是**插帧前**帧率） |
| `CTRL+ALT+END` | 标记当前这一档（sweep 诊断用） |
| `CTRL+ALT+S` | **同帧截图**：把同一帧的 NR 输入 / NR 输出各导出一张 24 位 BMP（R40x，2026-11-09 实证） |
| `CTRL+ALT+L` | Look 调色 开/关（实时 A/B；写回 `mgpu.ini` 的 `LookPresent`） |
| `Home` | ReShade 面板（**R41x8 起自动落在 `MGPU Bridge` 页**；想回到 ReShade 的 Home 页就设 `PanelFocusOnOpen=0`） |

**以上热键都可以改**（R41x 起）：打开 MGPU 面板（Home）→ 面板最下面的 `HOTKEYS` 段 → 点某个动作右边的 `Change` → 按新的组合键（Esc 取消）。绑定写进 `mgpu.ini` 的 `Hotkey*` 键（例如 `HotkeyScreenshot=Ctrl+Alt+S`；写 `none` 表示禁用），**立即生效**；与其它动作冲突会被拒绝并提示。截图键就是其中的 `Screenshot (NR pair)`。

**改键的两条硬性提醒**：① 默认**必须带 Ctrl / Alt / Shift 之一**——“裸键”我们无法从游戏手里抢走，实测按 F11 就把游戏切成了窗口模式（F11 是游戏自己的全屏切换）；确实要用裸键（如 F11 截图）就在同一段勾选 **`Allow bare keys`**（写 `mgpu.ini` 的 `HotkeyAllowBare=1`），代价是游戏也会收到这个键。② 被其它程序占用的组合（Steam 的 F12、系统 Alt+Tab、显卡驱动的旋转屏幕 Ctrl+Alt+←/→ 等）注册不上，面板状态列会显示红色 **`claimed`**，换一个即可——这也正是"两个键行高异常"的来源，已在 R41x4 修掉（改用短状态列）。

### 同帧截图（`CTRL+ALT+S`，R40z：**截图始终是 SDR**）

- 按一次导出一对**同一帧**的图（不是两次按键对齐）：`YYYYMMDD-HHMMSS_nr_before.<ext>` = 交给 NR 的输入帧，`YYYYMMDD-HHMMSS_nr_after.<ext>` = NR 输出帧；时间戳前缀相同，天然配对，且**按文件名排序就是按截图时间排序**（同秒冲突自动加 `-2`）。两张是记进**同一条 present 命令列表**的拷贝。
- **输出永远是 8-bit SDR（sRGB）**，不管游戏本身是 HDR 还是 SDR：
  - HDR10（`ChainColorSpace=12`，PQ/BT.2020）→ PQ 解码 → **BT.2020→BT.709 色域** → ACES 肩 → sRGB，纸白按 BT.2408 的 203 nit；
  - SDR（`ChainColorSpace` 不是 12）→ **直通**（只是 8-bit 化），观感与游戏内一致；
  - 帧格式支持 `R10G10B10A2` / `RGBA16F` / `R8G8B8A8` / `B8G8R8A8` / `B8G8R8X8`（SDR 游戏常见 8-bit 帧也能截了）。
- **色彩（R41x7，默认自动、每个游戏通用）**：`CaptureAutoSdr=1` 时，截图按**游戏链的格式 + 该显示器是否处于 HDR 模式**判定源类型，再按**本帧亮度统计**用 BT.2390 风格 EETF 转到 SDR（纸白 203 nits）：
  · 8-bit 链 → SDR 直通；· 10-bit 且显示器 HDR 开 → HDR10 PQ/BT.2020；· 10-bit 且显示器 HDR 关 → SDR 直通；· FP16 链 → scRGB 线性。
  SDR 游戏会**强制直通**，不会再被 `ChainColorSpace=12` 带偏。手动档仍保留：`CaptureAutoSdr=0` 后用 `CaptureToneMode`（1 逐通道 / 2 保亮度）与 `CaptureSaturation`（百分比）。面板 `SCREENSHOT` 段有 `Auto SDR` 勾选与手动控件，下一次截图生效。
- 输出格式：`CaptureFormat=png`（默认，无损，3440×1440 约 3–6MB）/ `jpg`（`CaptureJpegQuality=92`，约 1MB，分享用）/ `bmp`（旧路径，14.9MB）。PNG/JPEG 走 WIC；R41x3 之前 `CreateEncoder` 传错 GUID 会静默回退 BMP（日志有 `WIC ... encode failed: hr=0x88982F50` + `written as BMP instead`），现已修复。
- **面板里也能改**（R41x5）：MGPU 面板最下面新增 `SCREENSHOT` 段——`CaptureDir` 输入框 + `Apply` + `Open`（打开目录）、`Format` 下拉（png/jpg/bmp）、`Min interval (ms)`，全部**下一次截图生效**。
- **保存位置**（`CaptureDir=`）：**留空 = Windows「图片」文件夹下的 `MGPU`**（用已知文件夹 API，重定向/OneDrive 的图片库也认）；填 `ini` = `mgpu.ini` 同目录的 `mgpu_captures\`；填路径 = 自定义（绝对路径、`%USERPROFILE%` 这类环境变量、`~`、或相对 `mgpu.ini` 目录的相对路径，**路径带空格也没问题**）。目录不存在会自动逐级建；建不出来会自动回退 `mgpu_captures` 并打 warn。启动日志会打印最终目录：`[MGPU][R40x] screenshot folder: …`。
  **改 `CaptureDir` 热生效**：每次截图重新读 ini，改完下一次按键就生效，不用重启游戏。
- 只影响 HDR 路径的两个键：`CaptureTonemap=2` 保留 BT.2020 原色（旧的更艳观感，A/B 用）；`=0` 线性诊断。`CaptureExposure=1.0` 嫌暗可调到 1.3–1.6。
- **限频防卡死**：`CaptureMinIntervalMs=1500`（默认；0=不限）。一次截图要占 present 线程做「等本帧围栏 + 两张整帧编码」，连按/长按会把画面卡住，所以两次之间至少隔 1.5 秒；间隔内的按键被丢弃并打一条限频 warn（5 秒最多一条）。同一时刻只允许一张在写。
- 按得太早（未 arm / 无真实画面）会打 warn 并丢弃该次。
- 截图键也可以改（面板最下面 `HOTKEYS` → `Screenshot (NR pair)` → `Change`）。
- 日志确认（`mode` 告诉你走的哪条路：1=HDR10 PQ，0=SDR 直通，2=FP16 HDR，3=FP16 SDR）：
  `[MGPU][R40x] screenshot written: … | … (3440x1440, fmt=24, exposure=1.00, tonemap=1, file=png, mode=1, chain_cs=12, took=NNNms)`（`took` 是这次截图占用 present 线程的毫秒数）
- 历史实测（2026-11-09 09:26 局，BMP 版）：两张 14,860,854 B 成对出图；NR 输出 vs 输入平均绝对差 4.95/255，89.5% 像素有变化、28.7% 变化 >8 码；8× 放大差分图显示差异集中在棱边/细节，平坦区 ≈0 ⇒ **NR 在真实重建而不是旁路**。

---

- **2026-11-08 11:44 R401d**：MGPU 面板顶部新增 `FRAME RATE & LATENCY (live)` 段——上屏 FPS/帧时间/p99/1% low、游戏与 GPU1 帧率、桥内延迟、插帧状态（倍数/active/shown）。平时不显示；独立屏幕 OSD 仍为可选（`OSDFps=1` / CTRL+ALT+F5）。
- **2026-11-08 11:57 R401e**：MGPU 面板整体换行 + 两条可拖分隔条（`PanelSplitX`/`PanelBoxH` 写回 mgpu.ini；默认布局不变）。
- **2026-11-08 12:23 R401f**：面板 FG 行显示真实模式（FULL/CADENCE-ONLY/OFF 三色）、基帧绿/上屏蓝；新增 `FGStartDelayMs`（ms，默认 0=关闭；现场 3000=启动 3 秒后自动启用帧生成）。
- **2026-11-08 12:26 R401g**：MGPU 面板帧数区新增 `Frame generation` 开关（立刻生效，等效 CTRL+ALT+F12 的 FULL/OFF，并写 `FGCount` 供下次启动）。
- **2026-11-08 13:05 R401h**：present 循环在“有欠帧且无新帧”时先上屏再 poll（缓解复杂场景上屏掉到 60）；addon `9ef475e0…`，包待同步。

## 6. 跑不通就按这个顺序查

| # | 检查 | 怎么看 |
|---|---|---|
| 1 | 两张不同的卡被识别到了吗 | 日志 `[MGPU][T2]` 有没有 `REFUSING`（`no hardware adapter differs` = 核显+独显或显示器接错卡） |
| 2 | ReShade 是 add-on 版吗 | 游戏里按 `Home` 能否看到 MGPU Bridge 页签 |
| 3 | 深度拿到了吗 | `[R244] depth probe` 是 `REVERSED-Z` 还是 `at 0.0=100.0%`（后者=空图） |
| 4 | 桥 arm 了吗 | 有没有 `[MGPU][P4.0] stream arm` / `[R63] … BOUND` |
| 5 | 画面灰白 / 过曝 | `ChainColorSpace` 与游戏 HDR 状态不匹配 |
| 6 | 黑屏 / `ERROR 204` | 缺 `reshade-shaders\Shaders\mgpu_depth_tap.fx` |
| 7 | 插帧拉扯 / 边缘错位 | `NVOF` 没开或没起来（看有没有 `[NVOF] armed`） |
| 8 | 明暗呼吸 / 闪 | `TemporalRequireTuple=1` + `TemporalResetK=3`；排查时 `TemporalDiag=1` |
| 9 | 帧生成开太多 | 先 `FGCount=0` 排除 |
| 10 | 有没有别的 NGX 代理 | Prism NR / OptiScaler 会和桥抢 NGX，先卸 |

**注意：从别人机器上搬 `mgpu.ini` 是不行的** —— `ChainColorSpace`、`MVecUnits`、`Depth`
这三项每个游戏都不同，必须自己试。

**改完 ini 必须重启游戏** —— 桥在 arm 时读全部键，没有热重载。

---

## 7. 想改源码

- 整个项目是 C++ 编译成 `.addon64`；`src\fg.cpp`(75KB) 只是帧生成模块的一部分，
  依赖 `fgx.cpp`、`gpu1_context.cpp`、`nr16.cpp`、`residual.cpp` 等一整套，**单独拿走无用**。
- 源码在 `02-源码\mgpu-fork-repo\`（229 文件，已剔除 build 产物与二进制）。
- 配置项含义见上游 `README.md`(30KB) 的 `## Limitations` / `## Configuration` / `## Display setup`，
  以及 `docs/CONTRIBUTED_KEYS.md`。
- 上游：https://github.com/maohgad-web/Neural-coprocessor （MIT，© 2026 Marcelo Guibout，分发需保留版权声明）

---

## 8. 本包内其它文档

| 文件 | 内容 |
|---|---|
| `项目文档.md` | 组件清单 / 技术架构 / 关键配置 / 验收判据 / 实测记录 / 评价 / 已知问题 / 回滚 |
| `改进清单-漏洞补全与NR闪烁-20261102.md` | 12 条漏洞补全 + 7 条 NR 闪烁改进 |
| `改进方案-对照经验总结-20261102.md` | P0–P3 分阶段方案，与《经验总结》17 篇逐条对照 |
| `实测物证\` | 正确 HDR 截帧、错误 SDR 截帧、闪烁基线 CSV |
| 上级目录 `13/15/16/19-*.md`（另 17/18 为 DLSS/AntiLag 分析线） | 专题文档：13 OPT 共存配方、15 DLSS 注入可行性分析、16 实施方案与 Phase 0、**19 截图与热键的实现与验收** |
| 上级目录 **`21-KCD1-D3D11移植记录-20261109.md`** | **KCD1（D3D11）移植记录**：`DX11=1` 实验性 D3D11 producer 通路、KCD1 换件 R41x8 的现状与验收清单、OPT 在 DX11 上的判断 |

## 附：NR 模型版本说明（2026-11-07 更新）

本包内 mgpu\nvngx_dlssnr.dll 为 **310.9.16**（NVIDIA DLSSNR）：

| 项 | 值 |
|---|---|
| 文件大小 | 276,162,560 字节 |
| SHA-256 前 16 位 | CDFA6C1EC7848671 |
| 版本 | 310,9,16,0 |

**2026-11-07 回退原因（重要）**：11-04 曾把模型换成 310.8.0.0「50 系性能提升版」（165,840,496 / 24F2D48E83EE636C），实测画面差异明显但有代价——**灯光/高光区出现约 1 码/帧的时域微抖**（暗部与体积雾尤其明显）。11-07 换回 310.9.16 后微抖立即消失。旧版保留在 mgpu\nvngx_dlssnr.dll.bak-310.8.0.0（包内）与 <研究目录>\_旧模型备份-310.9.16\（本包旧版备份）。

**判据**：换模型后若灯光区出现"沸腾感"，先查模型版本，再查 ReShade.log 的 [R78] stream arm HELD 与 [P4.0] stream arm 之间 15–20 秒启动窗口（那段时间深度未绑定，属已知现象）。

## 附：桥 addon 版本说明（2026-11-07，批 2 B13）

本包内 `nvngx.dll_mgpu_bridge.addon64` 当前为 **R298（2026-11-08 10:20）**：1,287,680 字节 / SHA-256 前 16 位 `1ba375616bfe770e`（R401c + 面板输入修复；详见文末“R401 Look 实验版”附录）；此前的 R401c（1,282,048 / `f3ca609377682CB1`）与批 2 B13（1,247,232 / `E2CF483E38A8DD80`）分别备份为 `.bak-20261108-R298`、`.bak-20261107-B13`。演进链：批 2 pre（`8B35FE63`，1,228,800）→ B7（`29C0A9BD`，1,245,184）→ B9（`FADDCA5F`）→ B10（`090460F8`，1,246,208）→ B11（`B439B289`，1,246,208）→ B12（`B27600BF`，1,246,720）→ **B13（`E2CF483E`，1,247,232）** → **R401c（`f3ca6093`，1,282,048）** → **R298（`1ba37561`，1,287,680）**；更早是 10-30 认证版（2,001,408 / `1FDCD7EB`）。

B12 相对 B7 的实质变化（全部为批 2 antiFlicker 模块的修复）：

| 项 | 说明 |
|---|---|
| 描述符表绑定修复 | `antiflicker` 的 `apply()` 原来从未调用 `SetComputeRootDescriptorTable(1,…)`，shader 读到的全是 0 ⇒ 只要 `AntiFlickerPresent=1` 就会输出黑屏。B6 起修复。 |
| NVOF 时序修复 | 原来 `record()` 在 `nvof::frame()` 之前被调（读未写入的 luma）⇒ `mode 2` 首帧即崩。B7 起改为块内 frame→record→apply 顺序 + `frame_done()` 防重。 |
| 探针 readback Layout | READBACK 堆 buffer 的 `Layout` 必须为 `ROW_MAJOR`（原来留 `UNKNOWN` ⇒ E_INVALIDARG，探针永远出不了数）。B9 起 `[R360] PROBE #` 每 120 帧上线。 |
| luma 编码 UAV 类型 | 原来 `RWTexture2D<uint>` 写 `B8G8R8A8_UNORM` UAV ⇒ store 被静默丢弃 ⇒ NVOF 两槽 luma 全黑 ⇒ 流场恒 0.5 px（运动补偿形同虚设）。B11 起改 `float4`，流场真实（转视角 30–60 px）。 |
| 历史存储 bug | 原来 `stored = corr + d`（= 2·corr − current）⇒ 递推增益 2w，权重 ≥0.5 必发散（灾难级拖影）。B12 起改 `current + d`，权重安全上限从 0.29 提升为 <1.0。 |
| 验收 | mode 1 / mode 2 均无崩溃；绝地实机：权重 0.57 稳定无拖影，但体感改善不明显——**画质目标已关闭**（E30：`d/corr=4.8%`、相邻帧亮度差仅约 1 码，闪烁随输入帧进入，滤镜按定义不可见）。antiFlicker 作为稳定层保留。 |

### B13（2026-11-07 13:23）新增：面板紧急关闭热键

**问题**：游戏内（鼠标被捕获时）按 Home 呼出 ReShade 的 MGPU 面板后，第二次 Home / Esc 可能到不了 ReShade 的输入链（游戏窗口在该状态下不转发按键），面板卡死只能重启游戏。日志实证：一整局 26 次开合中唯一异常段卡了 3 分 18 秒，期间桥持续正常呈现。

**修法**：桥自带一条**带外**通道——注册全局热键 CTRL+ALT+HOME（全模式，与 CTRL+ALT+F5~F12 家族同构，ReShade 只占裸 Home，不冲突）。按下后桥在自己（游戏链）的 present 线程上直接调用 open_overlay(false) 关闭游戏 runtime 的 overlay，不依赖游戏输入链。

**验证**：日志出现 [MGPU][R3xx] overlay force-close: the bridge closed the game overlay via the emergency hotkey，约 2 ms 后紧跟 [V53] overlay closed。面板没开时按它为空操作，安全。
包内 `mgpu.ini` 随附 `AntiFlicker=2`、`AntiFlickerPresent=1`、`AntiFlickerView=0`、`AntiFlickerMs=8`、`AntiFlickerStabilize=0.35`（与绝地现网一致，B12 验证稳定）。**要彻底关闭只需 `AntiFlicker=0`**。调参注意：档位（AntiFlicker）只在 arm 时读（需重启），`AntiFlickerPresent/View/Ms/Stabilize` 每 240 帧热重载（约 4 秒生效）。

详细试验记录（E01–E30）见包根目录 `08-批2变更-时域与antiFlicker-20261106.md` 与 `09-试验记录-批2-参数与结果-20261106.md`。

## 附：R401 Look 实验版（2026-11-08，尚未入部署包）

2026-11-08 修复了 R401 调色 pass 的阻塞缺陷（`look.cpp` 的 `g_fmt` 未赋值 ⇒ 写回 CopyResource 格式不匹配被静默丢弃），现场 addon 已升级为 build `20261108-A`：

- addon `nvngx.dll_mgpu_bridge.addon64`：1,282,048B，sha256 `f3ca609377682cb1c3ec7f7d874ceb7d63c97dbbc7b7ecb2f2094f19bd3aca87`（备份 `.bak-20261108-0345-B-magenta`）。
- `mgpu.ini` 新增：`Look=1`、`LookPresent=1`、`PresentTintPct` 等调色键；`PanelOverPicture=1`（面板开在跨卡画面上，HOME 打开时游戏输入被接管，卡住用 CTRL+ALT+HOME）。
- 判断调色是否生效：日志 `[R401] Look armed (build 20261108-A): … out_fmt=24 g_fmt=24`；`PresentFill=1` 应整屏洋红；中性参数时 `Look` 整级跳过。
- 回滚：`Look=0` 即零开销关闭；或换回 addon/ini 备份。
- **已同步**（2026-11-08 10:20，R298）：`Win64/` 现为——addon 1,287,680B / sha256 `1ba37561…`、`mgpu.ini` 39,623B / `0fa63127…`（含 Look 全段、`PanelOverPicture=1`、`PanelFreeCursor=1`、`PanelGameOverlay=0`，调色参数全中性）、`check-deploy.ps1` 期望尺寸 1,287,680、`自检-selfcheck.ps1` 期望 1,287,680 并校验三把面板键；旧包文件备份为 `*.bak-20261107-B13` / `*.bak-20261108-R298`。
- **R298 面板输入修复（2026-11-08 10:20）**：gameplay 下按 HOME 面板可用鼠标、游戏不被带动；机制=面板 live 时摘除游戏注册的鼠标 raw input（`RIDEV_REMOVE`），关闭时恢复，每帧复查（游戏会自己注册回来）。判据日志：`[MGPU][R297] guard target: hwnd=… class=UnrealWindow`、`raw input suspended while the panel is live: 1 device(s) [page=0x1 usage=0x2 flags=0x30 …]`、`raw input restored when the panel closed`。

## 附：R403 动态帧生成（实验版，尚未入部署包）

2026-11-08 起在实验 addon 中加入动态倍率与手动锁帧（现场 addon 已从 R401c/R298 演进到 M3.2；`01-部署包` 仍为 R298 时代文件，以下为实验版说明，验收通过后再同步包）。

- 新键（写进 `mgpu.ini` 才生效）：
  - `FGDynamic=1`：动态倍率开关（0=关，固定用 `FGCount`）。
  - `FGTargetHz=144`：动态目标（默认 144；缺失/0 时按 144 处理）。规则：`k = floor(target/渲染fps) - 1`，钳 1..6（本机 MultiFrameCountMax=5），±2% 死区；60fps→2x(120)、48→3x(144)。
  - `FGCount=0..5`：固定/初始中间帧数（`FGCount=n` 即 (n+1)x）。
  - `FrameCap=0|N`：N=20..500 时锁**游戏渲染**帧率（在游戏 present 线程 sleep），上屏 = N×(k+1)。
- 面板（HOME → MGPU Bridge）：
  - 顶部 `FRAME RATE & LATENCY (live)`：上屏 fps、帧时间 p50/p99、1% low、渲染/GPU1 完成帧率、桥内延迟、插帧状态（FULL / CADENCE-ONLY / OFF）。
  - `Frame cap` 复选框 + 30–90 fps 滑条（即时生效、松手写 `FrameCap`）；旁边显示 `cap × 倍率 = Hz`，超过目标变橙色。
  - 动态倍率开启时倍率/目标滑条置灰，显示当前 k 与 render fps。
- 日志判据：`[MGPU][FG] dynamic (no overshoot): render=… target=… -> FGCount=… (…x)`；heartbeat 行含 `order_bad=`/`dropped=`；`[MGPU][R403M] cadence: presents/s=…`。
- 回退：`FGDynamic=0`、`FGCount=1`、`FrameCap=0`（或换回 `.bak-*` addon）。

## 附：可选模块 · 超分升级（OptiScaler + FSR4）

> **默认不参与核心部署**：复制完 `Win64/` 就能 NR+插帧；本模块只给"游戏自带超分不够、想用 A 卡 FSR4"的人。

**是什么**：OptiScaler 以 `dxgi.dll` 身份加载（托管 `ReShade64.dll`），接管游戏 DLSS/FSR2/FSR3 调用，实际由 **A 卡跑 AMD FSR4**；桥的 NR/NVOF/插帧/HDR 上屏不变。两层关系：

```
游戏 → dxgi.dll（OPT 超分）→ ReShade64.dll（桥：NR + NVOF + FG + 上屏）
```

| 项 | 内容 |
|---|---|
| 位置 | `optional-OPT-FSR4/`（payload 约 206MB；`apply.ps1` / `undo.ps1` / `check-optional.ps1` / `README.md` / `PROVENANCE.txt`） |
| 安装 | 游戏未运行；`powershell -ExecutionPolicy Bypass -File optional-OPT-FSR4\apply.ps1 -GameDir "<游戏 exe 目录>"`；游戏内超分选 **FSR2** |
| 状态 | 已实机验证（OPT FSR 4.1.2 + 桥 NR + 桥 FG 同时工作）；`UseFakenvapi=false`、桥私有 `_nvngx.dll`、R242-OPT 取核为共存要点 |
| 验证 | MGPU 面板底部 `OPT (optional)` 段 `● OPT: RUNNING`（绿）+ backend 行；或 `OptiScaler.log` 的 `OptiScaler v10.0.0-dev`/`Loading ReShade64.dll`/`D3D12 | FSR 4.x | Input: FSR2`；桥侧仍 `[R240]` 私有核、`[P4.1] Success`、`[V53] ROOTED`、`[R189]` A/N 门禁、`[FG]` generated 增长 |
| 档位 | 游戏内 FSR2 档位（Quality/Balanced/…，`Fsr4Preset=auto` 跟随）；或改 `OptiScaler.ini` 的 `[FSR4] Fsr4Preset=0..5`（改完重启）；自定义比例见 `[QualityOverrides]`。详见 `README.md` §14 |
| 注意 | **OPT 自身 overlay 必须保持关闭**（`OverlayMenu=false`，开它会与桥冲突，且屏幕上没有 OPT 标识是正常的）；仅 DX12；多一层代理，排障多看 `OptiScaler.log` |
| 回滚 | `undo.ps1 -GameDir "<游戏 exe 目录>"`（删 OPT 代理与 `OptiScaler\`；不动桥/`mgpu.ini`） |
