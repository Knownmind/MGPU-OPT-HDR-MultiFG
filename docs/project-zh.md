# 基于 MGPU 的 A+N 成品帧跨卡 NR + NVOF 光流插帧整合包 11.2

> 本文件是**项目文档**（11.2 起的组件/实测/回滚记录，按时间追加）；包内最新版本与增量以同目录 **`README.md`** 为准。

| 项 | 值 |
|---|---|
| 版本 | 11.2（2026-11-02 定版） |
| 内核 | MGPU Bridge 0.4.0 fork，`built Oct 29 2026 20:21:45` |
| 包大小 | 部署包 327 MB + 源码 62.8 MB |
| 本机验证环境 | AMD RX 9070 XT（跑游戏、无输出）+ NVIDIA RTX 5070 Ti（接显示器）；3440×1440；HDR10/PQ；Win11 25H2 |
| 验证游戏 | 星球大战 绝地：幸存者（D3D12）、影之刃零（此前在旧版包上验证过） |
| 许可 | 桥本体 MIT（上游 `github.com/maohgad-web/Neural-coprocessor`，作者 Marcelo Guibout）；ReShade BSD-3；RenoDX MIT；NVIDIA 运行时受 NVIDIA 许可约束，不随包再分发条款见 §11 |

---

## 1. 这是什么

一句话：**让 A 卡继续跑游戏、把"已经画完的成品帧"搬到 N 卡上跑神经渲染（DLSS-NR），再用 NvOF 硬件光流喂给 DLSS-G 插帧，最后由 N 卡直接上屏（PQ/HDR10）**。

与上游首发包（`MGPU-Bridge-0.4.0-fork-20261030.zip`）的差别，只有三处，全部在 `mgpu.ini`：

1. **补上 `ChainColorSpace=12`** —— 上游模板只在注释里提这个键，没有生效行。缺它时桥用 DXGI 默认的 sRGB gamma 2.2 解释 `R10G10B10A2`，HDR 游戏会发灰、SDR 游戏会过亮。
2. **显式打开 NVOF**（`NVOF=1` 及配套 6 个键）—— 上游模板一条 `NVOF*` 都没有，等于光流从不启动；没有光流前馈时 DLSS-G 只能吃未修正的引擎向量，快速转视角会出现画面拉扯/边缘错位（本机实测症状见 §8.4）。
3. **帧生成计数显式化**（`FGCount=1`、`FGTargetHz=0`）—— 上游模板没有 `FGCount`，默认 0 = 每帧插 0 帧 = 关。

内核二进制与上游完全一致（`1FDCD7EB3574EA5C…`），**没有改一行代码**。

---

## 2. 组件清单

### 2.1 部署包（`Win64/` → 复制到游戏 exe 同目录）

| 文件 | 大小 | sha256（前 16） | 作用 | 来源 |
|---|---|---|---|---|
| `dxgi.dll` | 5,592,064 | `0CEE63F9C9…` | ReShade 6.x（add-on 版），游戏通过它加载桥 | ReShade 官方 |
| `nvngx.dll_mgpu_bridge.addon64` | 1,348,608 | `c70767bcf26cc9c3…` | **桥本体**：跨卡搬运 + NR + NVOF + DLSS-G + 上屏 + 批2 antiFlicker + R401 Look 调色 + 面板紧急关闭热键（2026-11-08 10:20 同步为 R298；演进：10-30 认证版 2,001,408 / `1FDCD7EB` → 批2 pre `8B35FE63` 1,228,800 → B7 `29C0A9BD` 1,245,184 → B9 `FADDCA5F` → B10/B11 `090460F8`/`B439B289` 1,246,208 → B12 `B27600BF` 1,246,720 → B13 `E2CF483E` 1,247,232 → **R401c `f3ca6093` 1,282,048** → **R298 `1ba37561` 1,287,680** → **R403/OPT 共存 `c6510740` 1,303,040** → **R40x 同帧截图版 `bbe6beab` 1,318,400**（2026-11-08 23:09 build，+`CTRL+ALT+S`）→ **R40y `dd2905ff` 1,320,960**（2026-11-09，+自动 SDR 转换 + PNG/JPEG 输出）→ **R40z `00d41704` 1,321,472**（2026-11-09，截图始终 SDR：HDR 转换 / SDR 直通）→ **R40z2 `fedefc89` 1,322,496**（2026-11-09，+限频 1500ms 防连按卡死）→ **R40z3 `9851365d` 1,325,568**（2026-11-09，+默认存 Windows 图片\MGPU / 自定义路径）→ **R41x `1715c3df` 1,337,344**（2026-11-09，+面板底部 HOTKEYS 改绑全部热键）→ **R41x2 `429c32a4` 1,338,368**（2026-11-09，改绑必须带修饰键/占用标红）→ **R41x3 `f020e73c` 1,338,368**（2026-11-09，修复 PNG/JPEG 编码 GUID，BMP 回退不再静默）→ **R41x4 `d1910488` 1,339,392**（2026-11-09，裸键可勾选放开 + 热键表状态列）→ **R41x5 `058a2c43` 1,341,440**（2026-11-09，时间前缀命名 + 面板 SCREENSHOT 段）→ **R41x6 `55ccac5f` 1,342,976**（2026-11-09，+截图色调模式/饱和度调节）→ **R41x7 `9df61214` 1,348,096**（2026-11-09，+截图自动 SDR：按游戏链+显示器判定，每游戏通用）→ **R41x8 `6b9bf034` 1,348,608**（2026-11-09，+HOME 直接落在 MGPU Bridge 页）→ **R41x9 `c70767bc` 1,348,608**（2026-11-09，+D3D11 通路关闭适配器 spoof：修 KCD1 启动失败）） | 上游 fork 构建 + 批2 + R401 |
| `mgpu.ini` | 39,721 | `18d4ab4b1eb8fc81…` | 桥的全部开关（含本项目改动、R401 Look 全段、`PanelOverPicture=1`、`PanelFreeCursor=1`、`PanelGameOverlay=0`；调色参数全中性） | 本项目 |
| `ReShade.ini` | 4,602 | — | 游戏侧 ReShade 配置（`DepthCopyBeforeClears=1`、`EffectSearchPaths=.\reshade-shaders\Shaders\**`） | 本项目 |
| `ReShade2.ini` | 1,990 | — | **桥自己 runtime** 的 ReShade 配置（`PresetPath=.\gpu1.ini`、`AutoSavePreset=0`） | 上游 |
| `gpu1.ini` | 30 | — | 桥 runtime 的空预设（不加载任何 effect） | 上游 |
| `renodx-jedisurvivor.addon64` | 2,061,312 | `BFF1BED3…` | RenoDX（游戏内 HDR 色调映射替换），与本包共存 | RenoDX / clshortfuse |
| `reshade-shaders\Shaders\mgpu_depth_tap.fx` | 8,227 | — | 深度抓取 effect；**缺它会报 `ERROR 204`** | 上游 |
| `mgpu\nvngx_dlssnr.dll` | 276,162,560 | `CDFA6C1EC7848671` | **DLSS 神经渲染模型**（310.9.16；2026-11-07 回退——310.8「50系性能版」在灯光/高光区产生帧间微抖，实测换回即消失）。必须放在 `mgpu\` 子目录，放 exe 旁会被游戏自己加载并崩溃 | NVIDIA |
| `mgpu\nvngx_dlssg.dll` | 7,506,544 | `CADEE1AA6DB3907B` | **DLSS-G 帧生成**（310.9.16.0），桥私有加载 | NVIDIA |
| `mgpu\vendor_gpu.dll` | 560,200 | — | 真 NvAPI（32.0.16.2101），用于跨卡设备枚举 | NVIDIA |
| `mgpu\vendor_dlss.dll` | 35,400,248 | — | 私有 DLSS 运行时（供游戏开 DLSS 时用） | NVIDIA |

### 2.2 源码（`02-源码\mgpu-fork-repo\`）

229 文件 / 62.8 MB，**不含 build 目录与二进制产物**。关键文件：

| 文件 | 大小 | 内容 |
|---|---|---|
| `src\gpu1_context.cpp` | 1,562,481 | 副卡设备/交换链/呈现链、`[H1]` 色彩空间声明、PQ 传输 |
| `src\worker.cpp` | 98,196 | 主循环、AutoArm、present loop、z-order 门 |
| `src\nvof.cpp` | 80,735 | NvOF D3D12 光流会话（网格外推、negate、probe） |
| `src\fg.cpp` | 75,174 | DLSS-G 帧生成（CreateFeature/EvaluateFeature、HEARTBEAT） |
| `src\fg_map.cpp` | 31,362 | 帧生成向量对接（`NRFrameFilter`/`NRFrameKeep`） |
| `src\nr16.cpp` | 46,857 | 神经渲染 pass 与编解码/时域稳定 |
| `CMakeLists.txt` | 17,108 | 构建（`MGPU_HAVE_IMGUI`、`ext\` 依赖） |

### 2.3 工具（`tools/`）

| 脚本 | 用途 |
|---|---|
| `自检-selfcheck.ps1` | 查部署文件/关键键，可选 `-GameDir` 查日志判据；退出码 0/1 |
| `测量-闪烁.ps1` | 抓桌面按步长下采样，算帧间 `mean|ΔY|`/p95/max/大跳，出 CSV |
| `进游戏-自动继续.ps1` | 主菜单自动按 Enter（`AttachThreadInput` 绕前台锁），支持 `-Key/-Times` |

---

## 3. 数据流

```
             ┌───────────────────────────── A 卡（RX 9070 XT，无输出）─────────────────────────────┐
 游戏 D3D12 → │ ReShade(dxgi.dll) → 桥 addon：抓成品帧（present 后缓冲，含 HUD）+ 深度 + 矢量         │
             └───────────────────────────────┬──────────────────────────────────────────────────────┘
                                             │ 共享堆 + 跨卡围栏（46 MB/帧 ≈1.8 ms）
             ┌───────────────────────────────▼─────────────── N 卡（RTX 5070 Ti，接显示器）────────┐
             │ ① DLSS-NR（feature 18，mgpu\nvngx_dlssnr.dll）在成品帧上编辑                          │
             │ ② NvOF 硬件光流：量出相邻成品帧的真实像素流动（BGRA8，2×2 网格外推，negate=1）          │
             │ ③ DLSS-G 插帧（FrameGeneration）：吃成品帧 + 光流/引擎向量 + 深度，每渲染帧插 1 帧(2x)  │
             │ ④ 上屏：DComp overlay 全屏窗口，R10G10B10A2 + SetColorSpace1(ST.2084/PQ, BT.2020)      │
             └───────────────────────────────────────────────────────────────────────────────────────┘
                                             ▼
                                     显示器（HDR10/PQ，1405 nits 峰值）
```

要点：**NR 在"成品帧"上做，而不是在超分前的调用点**。这带来三个好处——UI/HUD 天然正确、不需要复现引擎的 tonemap、不需要跨卡回填；代价是 NR 工作在显示分辨率（4K 级），所以只能吃 N 卡的算力。

---

## 4. 关键技术点（本包用到的插件与技术）

| # | 技术 | 实现位置 | 作用 | 判据 |
|---|---|---|---|---|
| 1 | 跨卡共享堆 + 围栏 | `src\gpu1_context.cpp` | 纹理不能跨适配器共享（`E_INVALIDARG`），只能走 buffer/heap | 日志 `exec: copies closed and executed cleanly` |
| 2 | 成品帧 NR（DLSS-NR，feature 18） | `src\nr16.cpp` | 在现成画面上做神经编辑 | `[MGPU][NR…] EvaluateFeature … 0x00000001` |
| 3 | **NvOF 硬件光流** | `src\nvof.cpp` | 量真实流动，给插帧当向量前馈 | `[MGPU][NVOF] armed: … grid=2 perf=20 … negate=1` |
| 4 | **DLSS-G 2x 插帧** | `src\fg.cpp` | 每渲染帧插 1 帧 | `[MGPU][FG] ARMED: 1 intermediate frame(s) (2x)` + `HEARTBEAT … failed=0` |
| 5 | PQ/HDR10 链声明 | `src\gpu1_context.cpp` `[H1]` | 让 DWM 按 ST.2084/BT.2020 解释，而不是 sRGB | `[H1] … SetColorSpace1 hr=0x00000000` |
| 6 | DComp overlay 上屏 | `DcompOverlay=1` | 桥不建可见窗口逻辑，用合成覆盖层贴到游戏窗口上 | `[V55] DcompOverlay 1 requested … ACCEPTED` |
| 7 | AutoArm 自动布防 | `src\worker.cpp` | 进游戏第 600 帧自动开始搬运（菜单期无深度，会自动等） | `[P7.10] AutoArm firing at frame 600` |
| 8 | 时域三键 | `TemporalRequireTuple=1` / `TemporalResetK=3` / `TemporalDiag=0` | 禁止把别的帧的向量绑进来；跨帧后重置历史 | `[R300a4] TEMPORAL T1.9 CONFIG: …` |
| 9 | 深度/矢量契约 | `Depth=1` `MVec=3` `MVecUnits=uv` `DepthInverted=1` | 让桥用游戏自己的深度与矢量（而不是自造） | `[R63] DEPTH TRANSPORT … BOUND`、`[R78] MVEC TRANSPORT mode=3 REAL` |
| 10 | RenoDX 共存 | 第二个 ReShade add-on | 游戏内 HDR 色调映射替换，桥只做搬运 | `Registered add-on "RenoDX" … using ReShade API version 18` |

---

## 5. 关键配置（`mgpu.ini`）

只列会改变行为的键（模板里同名键会出现两次，**以最后一次为准**，本包的补丁块在文件末尾）：

| 键 | 值 | 作用 | 备注 |
|---|---|---|---|
| `Display` | `\\.\DISPLAY1` | 上屏目标 | 必须是接在 N 卡上的那块 |
| `Neural` | 1 | 开神经渲染 | 关掉=纯搬运上屏 |
| `Passes` | 1 | NR 遍数 | 1..3，遍数越多越强也越慢 |
| `Intensity` | 1.00 | NR 强度 | 0.00–2.00，**调低不是修复闪烁的手段** |
| `Present` | `nr` | 上屏内容：NR 输出 | `in` = 喂给模型的帧；`split` = 左右分屏 |
| `DcompOverlay` | 1 | 用合成覆盖层上屏 | 单显示器 + 渲染卡无输出才成立 |
| `Depth` / `DepthInverted` | 1 / 1 | 用游戏深度 | 反转 Z（本作是 reverse-Z） |
| `MVec` / `MVecUnits` | 3 / **留空** | 用游戏矢量；**单位不要写死**，让 arm 判定 | 写死 ⇒ 历史投影错位 ⇒ 静态闪砂 |
| **`ChainColorSpace`** | **12** | 声明 ST.2084/BT.2020 | **SDR 内容要改 0**；12 是 HDR10 |
| `NRFrameFilter` | 0 | NR 不读 FG 的向量图 | 与 FG 同时开时才考虑设 1 |
| `NRFrameKeep` | 2 | 每 2 帧保留 1 帧生成帧 | 2..8 |
| `TemporalRequireTuple` | 1 | 要求同帧对（防错帧向量） | 闪烁治理第一键 |
| `TemporalResetK` | 3 | 跨 3 个游戏帧后重置历史 | 治"明暗呼吸" |
| `AntiFlicker` | 0 | R360 抗闪模块 | 上游实测无效且与 FG 冲突 |
| **`FGCount`** | **1** | 每渲染帧插 1 帧（2x） | 0=关；上限 5 |
| **`FGTargetHz`** | **0** | 关自适应节拍，FGCount 当固定倍数 | 本机无高精度时钟 |
| **`NVOF`** | **1** | 开 NvOF 光流 | **没这行就没有向量前馈** |
| `NVOFGrid` / `NVOFPerf` | 2 / 20 | 2×2 网格外推 / 性能档 | 沿用 10-31 有效配置 |
| `NVOFNegate` | 1 | 光流方向取反 | 与本作矢量方向匹配 |
| `NVOFScaleX/Y` | 1.0 / 1.0 | 光流缩放到矢量场 | 与 `MVecScale` 同量级时才正确 |
| `NVOFProbe` / `NVOFLog` | 1 / 300 | 打点探测 / 每 300 帧一行 | 排障用 |

---

## 6. 部署步骤

1. 退出游戏。
2. 备份游戏目录现有的 `dxgi.dll`、`*.addon64`、`mgpu.ini`、`ReShade*.ini`、`mgpu\`。
3. 把 `Win64/` 下**所有内容**（含 `mgpu\` 与 `reshade-shaders\`）复制进游戏 exe 同目录。
4. 打开游戏设置，**把 HDR 打开**（`bUseHDRDisplayOutput=True`、亮度 1000）；若坚持 SDR，则把 `mgpu.ini` 的 `ChainColorSpace` 改成 `0`。
5. 确认 `mgpu.ini` 里 `ChainColorSpace=12`、`FGCount=1`、`NVOF=1`。
6. 启动游戏；进主菜单后若需要，跑 `tools/进游戏-自动继续.ps1` 按一次 Enter。
7. 运行 `tools/selfcheck.ps1 -GameDir "<游戏Win64目录>" -Log "<ReShade.log>"`。
8. 按 §7 的三行日志验收。

---

## 7. 验收判据（缺一不可）

```
[H1] bridge chain colour space: requested 12 … SetColorSpace1 hr=0x00000000. ST.2084 PQ at BT.2020
[FG] ARMED: 1 intermediate frame(s) per rendered frame (2x) … 
[NVOF] armed: 3440x1440 grid=2 perf=20 … negate=1 scale=(1.000,1.000) …
```

- `[H1]` 缺失 ⇒ 颜色一定不对（灰白或过亮）。
- `[FG] ARMED` 缺失且 `FGCount\=1` ⇒ 私有 `mgpu\nvngx_dlssg.dll` 没找到/版本不符。
- `[NVOF] armed` 缺失 ⇒ 插帧会拉扯（向量未修正）。
- OSD（`CTRL+ALT+F5`）显示的是**插帧前**的渲染帧率，不是上屏帧率；判定插帧要看 `HEARTBEAT` 的 `generated/shown` 是否在涨、以及肉眼是否更顺。
- 闪烁用 `tools/测量-闪烁.ps1` 记录 `mean|ΔY|`，改动前后各跑一次同场景对比。

---

## 8. 实测记录与评价

### 8.1 本机环境实测（2026-11-02）

| 项 | 结果 |
|---|---|
| 显示器 | `\\.\DISPLAY1` 挂在 N 卡（luid `…EEC6`/`…D579`，每次开机变）；`ColorSpace=12` HDR10/PQ；10 bpc；峰值 1405.1 nits |
| 窗口 | 游戏 2752×1152（=3440×1440 @125%）；桥覆盖层 client 2752×1152 |
| 搬运 | 每帧 19,906,496 B（`pitch=13824`，`R10G10B10A2`） |
| 延迟 | `[SEAL] … lat≈38–49 ms`（含 1 帧跨卡 + 排队） |
| 帧率 | 游戏渲染 56–64 fps；插帧 2x 后上屏约 110–128 fps |

### 8.2 颜色（本包相对上游的最大改善）

上游模板没有 `ChainColorSpace` 生效行 ⇒ 桥按 sRGB 解释 10-bit 码 ⇒ **HDR 游戏发灰、SDR 游戏过亮**。
本机实测：显式 `ChainColorSpace=12` 后 `[H1] SetColorSpace1 hr=0`，画面恢复正常对比与饱和（截帧对比见 §8.5）。

### 8.3 NR 侧

- 用户验收结论（2026-11-02）：**"现在是 NR 组件对比原来没有问题了"**，静态闪烁不再出现。
- 此时生效的是：`TemporalRequireTuple=1` + `TemporalResetK=3` + `NVOF` 前馈 + `Intensity=1.00`，`AntiFlicker` 保持关闭。
- 未做（本代内核缺这两个机制，10-31 那代 2.18 MB 有）：`NRCodec`（显示域 codec）与 `NRSteady*`（时域稳定器）。
- ⚠️ **2026-11-02 修正（16:14 二次更正）**：`NRSteady` 不是静态闪烁的根因（被 `NRInput16=4` 门控、复现态没开）；根因是 `MVecUnits` 被写死。见 §8.6。
  当天实测证明 `NRSteady` 默认开启正是该内核静态闪烁的直接来源，必须 `NRSteady=0`。见 §8.6。

### 8.4 插帧（NVOF + DLSS-G）

| 配置 | 现象 |
|---|---|
| 只有 DLSS-G（上游默认，无 `NVOF*`） | **画面拉扯/边缘错位，严重** —— 只有未修正的引擎向量 + 近似相机矩阵 |
| DLSS-G + `NVOF=1`（本包） | 用户验收：**"正常了"**；2x 生效 |
| 历史参照（2026-10-31，2.18 MB 内核） | `generated=161,914 / shown=161,913 / failed=0`（16 万帧零失败），当时另有 `[NVOF][PRIOR]` 拟合 |

结论：**NVOF 光流前馈是这一支能把插帧做干净的前提**；本代内核缺 `PRIOR` 拟合，快速转视角时仍可能出现轻微错位，属已知边界。

### 8.5 截帧与测量物

| 文件 | 内容 |
|---|---|
| `hdr_now.png` | HDR 正确后的整屏截帧（自然色） |
| `after_enter.png` | SDR + PQ 声明错误时的过饱和截帧（反例） |
| `flicker_before_20261102-143558.csv` | 闪烁基线（`mean|ΔY|=8.299`，含场景运动，非纯 NR 噪声） |

### 8.6 静态闪烁的根因定位（2026-11-02，重要）

> **更正（2026-11-02 16:14）**：根因是 **`MVecUnits` 被写死在 ini 里**，不是 `NRSteady`。
> 同一颗二进制（`6B8C0ADE`）上：10-31 那份 ini 原样 ⇒ 三处静态闪砂复现；只注释 `MVecUnits=uv`
> 一行（其余 110 行逐行相同）⇒ 不闪；`[R87] MVEC FRAME ALIGNMENT … at 1` 由 87.24% 升到 93.93%。
> `NRSteady` 为什么不是：它被 `NRInput16=4` 门控，复现态 ini 没有这个键，10-31 日志里也没有
> `[R360] NRSteady ON` 行 —— 之前"设 `NRSteady=0` 就好了"那一步同时换回了基线 ini，是两个变量。

- 现象（10-31 内核 2,179,584 B / `6B8C0ADE`）：**飞船灯下、中远距细纹理、屋顶阴影**三处，站着不动也在闪；动起来更重。用户对照 `CTRL+ALT+F7` 的原图：**原图不闪，NR 侧才闪**。
- 方法：把当时的部署（addon + `mgpu.ini` + `ReShade.ini` + `reshade-shaders`）从 `<备份目录>` **逐字节复原**，拿到稳定复现的阳性样本，然后每次只改一个键、重启验证。
- 七刀排除：`Tuning`、`NRCodec`+`NRInput16`、`JitterComp`、`DepthTransport`、`ChainColorSpace`+`NRMode`+`NRDetailGain`+`Perf11`、关插帧（`CTRL+ALT+F12`）—— 全部无效；
  **`NRSteady=0` 一刀见效**，用户验收："和最开始的不闪版差不多了"。
- 判据：日志出现 `[MGPU][R360] NRSteady ON: amount …` 即该模块开着；设 `=0` 后该行消失。二进制自述
  `NRSteady=0 restores the R359 chain bit for bit.`（作者留的退路）。
- 边界：只对**含 R360 的构建**成立；本包 01 里那颗 2,001,408 B（Oct 29）没有该模块，所以它怎么调都不闪。

### 8.7 评价

- **优点**：HDR 链一次打通后颜色稳定；NR 在成品帧上做，UI/字幕天然正确；NVOF 前馈让 DLSS-G 在 2x 下可用；整套只靠 ini 就能开关，回滚成本低。
- **代价**：桥独占一个覆盖层窗口（Alt-Tab 需 z-order 门配合）；+1 帧延迟；游戏必须开 HDR 才有正确颜色；DLSS-G 相机矩阵是近似值，极端转动仍有边界。
- **不建议**：用降低 `Intensity` 换"不闪"（用户已明确否决：削弱效果的改善没有意义）；用 `AntiFlicker=1`（上游实测无效且与 FG 冲突）。

---

### 8.8 11.2 的痛点清单（2026-11-02 记录，按用户要求"只记不改"）

> 本节是**待办清单**，不是已修项。已修的见 §8.3 / §8.6，未修的列在这里，附证据与修法方向。

| # | 痛点 | 现状与证据 | 影响 | 状态 | 修法方向 |
|---|---|---|---|---|---|
| P1 | **运动亮度闪烁（两类）** | 用户 2026-11-02 16:30 实测：缓慢移动时亮/暗被"拖"着走；运动过快时大面积亮度突变。机制 = 模型内部时域累积 + `TemporalRequireTuple=1` / `TemporalResetK=3` 的**硬阈值** + 历史权重**常数** | 走路/转视角时最明显，当前画面第一号问题 | ⬜ 未修 | 《经验总结》16 篇 M9 的 **F 路线**（幅度 A / 支持度 P 分离 + 非对称 τ 0.06/0.18 + 误差权重 q）；先 MVP（q≡1）再补 q |
| P2 | 静止闪砂（灯下 / 中远距细纹理 / 屋顶阴影） | 根因 `MVecUnits` 写死；注释后 `[R87] MVEC FRAME ALIGNMENT` 87.2% → 93.9% | 已消除 | ✅ 已修（模板已注释 + 警示块） | — |
| P3 | 插帧拉扯 / 边缘错位 | 无 NVOF 前馈时裸 DLSS-G 必拉扯（`fg_map` 一套向量两帧） | 已消除 | ✅ 已修（模板补 NVOF 块） | — |
| P4 | HDR 灰白 / SDR 过曝 | 模板原本没有 `ChainColorSpace` 生效行 | 已消除 | ✅ 已修（显式 `12`） | — |
| P5 | 模板重复键 | `Intensity` 出现两次（`:105` 2.00 / `:650` 0.85，后者生效）；`Tuning` 两次（`0` 生效、后面 `1` 是死键） | 极易误判"改了没反应" | ⬜ 未修（本轮只加注释，不动模板结构） | 下一版清理重复键，或把死键段整段注释 |
| P6 | 没有"运行时是否真生效"的判据 | 自检脚本只查文件与键；真跑起来仍靠人读 `[H1]` / `[R87]` / `[R101] creates=0` | 排障靠经验 | 🟡 半修 | addon 加 `SelfCheck=1`：启动 5 秒后把四条判据打成一行 |
| P7 | 面板回写 `mgpu.ini`（`PanelPersist=1`） | 拖滑杆会把脚本刚写的值改回去（`DomainStrengthPct` 事件，11-01 踩过） | 脚本与面板同时用时互相打脸 | ⬜ 未修 | 用脚本时置 `PanelPersist=0`，或写后回读校验 |
| P8 | `AntiFlicker` 与插帧冲突 | README 原文 "Measured ineffective and conflicts with FG." | 开插帧时无法用 R360 钳亮度 | ⬜ 未修（上游限制） | 测 AntiFlicker 时先 `Ctrl+Alt+F12` 关插帧 |
| P9 | 插帧时 NR 可能用到"没有自己矢量"的帧 | `NRFrameFilter=0`（默认关）；FG 每渲染帧出两帧，其中一帧没有独立矢量 | 插帧 + NR 同开可能加重闪烁 | ⬜ 未修 | 试 `NRFrameFilter=1` + `NRFrameKeep=2`（"一套向量两帧"开关） |
| P10 | NR 输入域没有真正修 | `nr16.cpp:42-43` 是**码值进码值出**；`PaperWhite` 是静态标量，不跟场景曝光 | P1 的结构性来源之一（编辑量随曝光漂移） | ⬜ 未修 | 先搬 scRGB/线性再做差分（03 篇 §7.1），再上 per-frame 白点锚定（10 篇 §12 / 16 篇 M11） |
| P11 | 没有"同帧成对"落盘 | 只能靠 DDA/GDI 抓屏 + 场景静止近似 | 验收只能"看起来" | ⬜ 未修 | present 钩子同帧存 `anchor` + `nout` 两张（11 篇 §8） |
| P12 | 日志无分级 | 单次运行 `ReShade.log` 1.1–1.4 MB，标签几十种 | 排障全靠 grep | ⬜ 未修 | 加 `LogLevel`（0 静默 / 1 关键 / 2 全量） |
| P13 | 模型与运行时不随包 | `mgpu\nvngx_dlssnr.dll` 166 MB / `nvngx_dlssg.dll` 7.5 MB / `vendor_dlss.dll` 35 MB 的再分发受 NVIDIA 许可约束 | 分发需单独确认 | ⬜ 不可修（法律） | 保留 `mgpu\PUT-YOUR-DLL-HERE.txt` 说明 |

**P1 的复现与判据（下一次实验照这个做）**

1. 位置：飞船内灯下、中远距细纹理（栏杆/管线）、屋顶阴影 —— 11-02 实测的高发点；
2. 动作：① 缓慢平移/转视角 4–6 秒；② 快速甩视角 2–3 秒；
3. 观察：① 亮/暗是否被"拖"着走（拖影）；② 快甩时是否出现**整块区域**亮度跳变（不是偏色、不是全屏均匀呼吸）；
4. 量化：`测量-闪烁.ps1` 现在只量帧间差（高频砂），**量不到"呼吸"**；要补一条"全屏平均亮度时间序列"的 σ / 峰峰 / 0.3–3 Hz 能量才有前后对比依据（⬜ 见 P6）。

---
### 8.9 R401 Look 调色（2026-11-08 完成）

- **背景**：R401（11-07）在 anti-flicker 之后、present 之前加入全屏 compute 调色 pass，但“参数写入 af_out 后画面无变化”，11-07 23:10 停手并置 `Look=0`。
- **根因（11-08 定位）**：`src/look.cpp:52` 的 `g_fmt` 默认 `R16G16B16A16_FLOAT`，而 `arm(out_format)` 的 `out_format` 从未赋值给它 ⇒ `g_out` 8Bpp vs 帧 4Bpp（`R10G10B10A2_UNORM`）⇒ 每帧 `CopyResource(af_out, g_out)` 格式不匹配、运行期静默丢弃。20:32/21:06 的 `Close()=E_INVALIDARG` 亦同源。
- **修复**（build `20261108-A`）：`g_fmt = out_format`（UNKNOWN 拒绝）+ copyback barrier 前态修正 + `GetDesc()` 格式守卫；`look.cpp` 657 行。addon `build\mgpu_bridge.addon64` 1,282,048B，sha256 `f3ca6093…`；现场已装（备份 `.bak-20261108-0345-B-magenta`）。
- **验证**：整屏洋红（`PresentFill=1`）→ 灰度（`PresentSatPct=0`）→ 面板实时调色；`PanelOverPicture=1` 时面板经 `[R294]` 开在 GPU 1 runtime、叠在跨卡画面上，改键即时生效并写回 `mgpu.ini`；中性时整级跳过（零开销）。
- **状态（2026-11-08 04:30；随后升级为 R298，见下条）**：现场与 `Win64/` 已一致——addon 1,282,048B / sha256 `f3ca6093…`、`mgpu.ini` 39,584B（Look 全段 + `PanelOverPicture=1`，调色参数全部中性、`PresentTintPct=0`）；`check-deploy.ps1` 期望尺寸已同步；详见 `10-R401阶段A实验-20261108.md` 与 `09` 附录后续。
- **风险**：`PanelOverPicture=1` 为实验性（需重启生效）；面板拖动时每帧写 ini 的 hitching 待观察。
- **2026-11-08 10:20 面板输入修复（R298）**：gameplay 下 HOME 面板可用鼠标且不再带动游戏——面板 live 时摘除游戏注册的鼠标 raw input（`RIDEV_REMOVE`），关闭时按快照恢复；日志 `[MGPU][R297] raw input suspended while the panel is live: 1 device(s) …` / `raw input restored when the panel closed`。新增键 `PanelFreeCursor=1`（释放光标：`ClipCursor(nullptr)` + `ShowCursor`，位置走桌面 `GetCursorPos`、按钮 `GetAsyncKeyState`）、`PanelGameOverlay=0`（实验：允许 ReShade 在游戏 runtime 开 overlay，已验证挡不住这款游戏的 raw input，保持 0）。addon 升级 1,287,680B / `1ba37561…`；详见 `10-R401阶段A实验-20261108.md`。
- **2026-11-08 11:27 P1 收尾（R401c-P1）**：`look.hpp:33` 的 `PresentFill` 注释改为“洋红”（原来写 flat white，与 shader 不一致）；面板拖动写 ini 改为**250 ms 队列节流**（`release()` 强制落盘、240 帧重读跳过待写项）；新增 `CTRL+ALT+L` 切换 `LookPresent` 实时 A/B。新 addon `66043bb2727d7c64…`（1,287,680B），部署包待同步。
- **2026-11-08 11:44 R401d**：帧率/延迟/插帧状态显示并入 MGPU 面板（`FRAME RATE & LATENCY (live)` 段；呼出可见、平时不显示）；present 采样改为始终开启；addon `9cc9e08b2dde…`（1,288,704B），待装现场/同步包。
- **2026-11-08 11:57 R401e**：MGPU 面板全局面板换行 + 两条可拖分隔条（`PanelSplitX` 0.2–0.8 / `PanelBoxH` 200–4000，写回 mgpu.ini，默认=原布局）；addon `0370aaf389d2…`（1,290,752B，= R298+P1+R401d+R401e），待装现场/同步包。
- **2026-11-08 12:23 R401f**：FG 状态显示补全（FULL / CADENCE-ONLY / armed but OFF 三色）+ 基帧绿/上屏蓝配色 + `FGStartDelayMs`（默认 0；现场设 3000，桥 arm 后 3 秒自动从 1× 切 FULL）；addon `1c31f216cdf1…`（1,292,288B），包待同步。
- **2026-11-08 12:26 R401g**：面板帧数区新增 `Frame generation` 开关（勾=FULL、取消=OFF，立即生效并写 `FGCount` 供下次启动；未 armed 时置灰）；`fg::set_mode()` 新增；addon `da147e948bcf…`（1,292,800B），包待同步。
- **2026-11-08 13:05 R401h**：present 循环前置 owed 帧（gate 非阻塞询问；欠帧时跳过 `stream_poll` 直接上屏），目标把复杂场景上屏从 60 拉回 90–120；addon 1,292,800B / `9ef475e0…`，包待同步。

## 9. 已知问题与边界

1. **相机矩阵近似**：DLSS-G 在本整合包里拿到的是"一个静态透视（70°、near 0.1、far 1000）+ 上一帧相机=本帧"的近似矩阵 ⇒ 快速平移/转动时边缘可能有轻微拉伸。
2. **本代缺 `NRCodec`/`NRSteady`**：闪烁治理只能依赖时域三键 + NVOF；换 2.18 MB 内核可拿回这两个机制。
3. **`AntiFlicker` 关闭**：R360 模块与 FG 冲突。
4. **模型文件位置**：`nvngx_dlssnr.dll` 必须在 `mgpu\` 子目录；放 exe 旁会被游戏自己加载并在神经阶段崩溃。
5. **必须有 HDR 或必须改默认**：SDR 内容 + `ChainColorSpace=12` = 过饱和过曝。
6. **拓扑限制**：单显示器、渲染卡无输出、N 卡接屏；否则 `DcompOverlay` 会被拒绝（`[V55]`）。
7. **虚拟显示器会干扰选卡**：本机有 GameViewer（网易 UU）虚拟显示器，DXGI 会多报一个"NVIDIA 适配器"且 `outputs=0`；旧版选卡规则会判"歧义"并拒绝建卡（`[T2] REFUSING`）。本版按 `rule="exclusion + software filter + duplicate-row collapse"` 正常选中；**不要禁用该虚拟设备**。
8. **`LUID` 每次开机变**：判据与配置里都用名字/`outputs>0`/`[Gpu1] LuidLowHex`，不要写死 LUID。
9. **读帧/日志**：`ReShade.log` 运行中实时写；`ERROR 204` = 缺 `mgpu_depth_tap.fx`。

---

## 10. 回滚

1. 退出游戏。
2. 删除本包放入的文件：`dxgi.dll`、`nvngx.dll_mgpu_bridge.addon64`、`mgpu.ini`、`ReShade*.ini`、`gpu1.ini`、`renodx-jedisurvivor.addon64`、`reshade-shaders\`、`mgpu\`。
3. 恢复备份（若之前有）或直接删到只剩游戏本体文件（`JediSurvivor.exe`、`turbojpeg.dll`、`amd_fidelityfx_*.dll`、`Core\`）。
4. 单项回滚：`mgpu.ini` 里把 `FGCount=0`（关插帧）、`NVOF=0`（关光流）、`ChainColorSpace=0`（SDR 链）、`Neural=0`（关 NR）。

---

## 11. 许可与致谢

- MGPU Bridge 本体：MIT，Marcelo Guibout，`https://github.com/maohgad-web/Neural-coprocessor`。
- ReShade：BSD-3-Clause。
- RenoDX：MIT，`https://github.com/clshortfuse/renodx`。
- DLSS / DLSS-G / NvOF 运行时来自 NVIDIA，**不在本包内重新授权**；分发前请确认 NVIDIA 许可条款（尤其 `mgpu\nvngx_dlssnr.dll`、`mgpu\nvngx_dlssg.dll`、`mgpu\vendor_dlss.dll`）。
- 本项目（三处 ini 改动、自检/测量工具、本文档）：随包自由使用，保留出处即可。

- **2026-11-08 13:05–19:15 R401i/J、R402i/j、R405 与 R403 M1/M3**：① 面板统计区固定高度（`PanelStatsH` 4–14 行 + 底部拖拽条），行数不再跳动；② `R402i/R402j` 帧序探针与 FG 失败三因（nocolour/nomvec/ngx），`R401i` 缺 mvec 时复用上一帧流场（失败率从 16.6% 降到仅启动期 1 次）；③ `R405` 面板新增 `Generated frames` 倍率滑条（2..MultiFrameCountMax+1）与 `Target Hz` 滑条（0..240），拖动即时生效、松手写 `FGCount`/`FGTargetHz`；④ `R403`：M1.0b/M1.1 整批付费 + PACE 探针、M3.0 cadence 探针、M3.1 动态倍率（`FGDynamic`）、M3.2 修复、M3.3 不超帧（floor + ±2% 死区）+ 手动锁帧滑条（30–90）。M3 实测与决策见 `11-R403-M3-动态倍率-实测与决策-20261108.md`；现场 addon 为 M3.2 `25be4524…`（1,301,504B），M3.3 `200dc7b4…` 待装，`01-部署包` 待同步。

### 2.4 可选模块：超分升级（OptiScaler-FSR4）+ 桥 NR/FG 共存（2026-11-08）

- 位置 `optional-OPT-FSR4/`（约 206MB），不参与核心部署；采用 `dxgi.dll = OptiScaler（托管 ReShade64.dll）` 形态，游戏内 FSR2 输入被 OPT 接管、A 卡跑 FSR 4.1.2，同时桥的 NR 与帧生成继续工作。
- **状态：已验证（2026-11-08 21:26–21:31 实机）**；关键修复 `UseFakenvapi=false` + 桥私有 `mgpu\_nvngx.dll` + R242-OPT 取核；配方与回滚见 `13-OPT-FSR4+桥NR-FG共存-实测配方-20261108.md`。
- 旧 `winmm.dll` 形态已作废（启动崩溃，2026-11-08 19:33 实测），仅保留于历史记录。
- 详见 `docs/deployment-zh.md` 附录与 `<研究目录>/经验总结/33-11.2-超分升级-OPT-FSR4可选模块-20261108.md` §9。
