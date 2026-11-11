# MGPU(NVOF自适应多倍插帧+OPT注入超分+HDR) 11.9 · 轻量发布包

> **English**：A dual-GPU MGPU Bridge 11.9 — the AMD card renders, the NVIDIA card runs DLSS-NR / NVOF / DLSS-G frame generation / HDR10 output. **Lite release: NVIDIA/AMD runtimes are NOT included** (see `docs/RUNTIME-FILES.md`). **Free share, not for sale.**
> **中文**：A+N 双显卡 MGPU Bridge 11.9：A 卡渲染，N 卡跑 DLSS-NR / NVOF / DLSS-G 插帧 / HDR10 上屏。**轻量包不含 NVIDIA/AMD 运行时**（见 `docs/RUNTIME-FILES.md`）。**免费分享，禁止倒卖。**
> [English README](README.en.md) · [中文说明](README.md)
>
> **作者**：电子羊羊尾（小黑盒 ID: 38096711）
> **免费分享**：本包**免费分享**、不收取任何费用；**禁止倒卖/付费售卖**——如在第三方平台付费购得，请退款并向平台举报。
> **内核**：MGPU Bridge 0.4.0 定制构建 **R41x13j**（`Win64/nvngx.dll_mgpu_bridge.addon64` = 1,360,896 B / `sha256:13e01caf…`）
> **发布仓库**：https://github.com/Knownmind/MGPU-OPT-HDR-MutiFG （可按需改名）
> **本仓库是"轻量包"**：**不含 NVIDIA / AMD 运行时二进制**（DLSS-NR 模型、DLSS-G、`_nvngx.dll`、FSR 运行库等），需要你自备，见 [`docs/RUNTIME-FILES.md`](docs/RUNTIME-FILES.md)。完整包不在公开仓库分发。

---

## 1. 这是什么

**A 卡继续跑游戏，把已经画完的成品帧搬到 N 卡上做 DLSS-NR 神经渲染，再用 NVOF 硬件光流喂 DLSS-G 插帧，最后由 N 卡以 HDR10/PQ 直接上屏。**

本包 = ReShade 6.8 add-on（MGPU Bridge 定制内核）+ 部署脚本 + 中文文档。装上后不需要再挂别的超分/插帧工具，NR、插帧、上屏、截图、调参都在同一个 add-on 里完成。

**核心能力**

| 能力 | 说明 |
|---|---|
| NR（DLSS-NR） | N 卡跑神经渲染；面板可调 NR 强度、切换 NR 模型文件（重启生效） |
| NVOF 光流 + DLSS-G 插帧 | NVOF 硬件光流喂给 DLSS-G；2x–6x 动态倍率；`Ctrl+Alt+F12` 开关 |
| HDR10 上屏 | 桥交换链声明 PQ/BT.2020，N 卡直出 HDR10；SDR 游戏写 `ChainColorSpace=0` |
| 面板 | `Home` 直接落到 `MGPU Bridge` 页：实时帧率/延迟、NR/插帧开关、NR 模型、截图设置、热键改绑、OPT 状态行 |
| 9 个可自定义热键 | 全部面板可视化改绑，冲突/被占用会标 `claimed` |
| 成对截图 | `Ctrl+Alt+S` 同一帧出 NR 前/后两张，恒 SDR，时间戳命名 |
| 自动选卡 / 自动 spoof | 重复枚举行自动优先"内核映射显示器"的行；适配器 spoof 按 API 自动（D3D11 关 / D3D12 开） |
| 诊断/自检 | `check-deploy.ps1`、`selfcheck.ps1`、`choose-adapter.ps1`、`setup-driver.ps1`、`first-run.ps1` |
| D3D11 实验路径 | `DX11=1`，共享纹理+fence 从游戏 D3D11 context 取帧（无真矢量/Reflex） |

---

## 2. 仓库/发布内容

```
.
├── README.md                  ← 本文件
├── LICENSE                    ← MIT（作者：电子羊羊尾）
├── THIRD_PARTY_NOTICES.md     ← 上游/第三方许可与"不随仓库分发"声明
├── RELEASE_NOTES.md           ← 本版发布说明与校验值
├── PUBLISH.md                 ← 发布到 GitHub 的操作步骤（给维护者）
├── .gitignore
├── SHA256SUMS.txt             ← 仓库文件校验值
├── Win64/                     ← 复制到游戏 exe 同目录（轻量包：不含运行时 DLL）
│   ├── nvngx.dll_mgpu_bridge.addon64   ← 桥内核 R41x13j（1,360,896 B）
│   ├── dxgi.dll                        ← ReShade 6.8（BSD-3，见 THIRD_PARTY_NOTICES）
│   ├── mgpu.ini                        ← 桥的全部开关（默认值安全，见 §7）
│   ├── ReShade.ini / ReShade2.ini / ReShadePreset.ini / gpu1.ini
│   ├── reshade-shaders/Shaders/mgpu_depth_tap.fx
│   ├── check-deploy.ps1                ← 部署后自检
│   └── mgpu/README.txt                 ← **运行时文件需要你放进来**（见 docs/RUNTIME-FILES.md）
├── tools/
│   ├── first-run.ps1          ← 首次部署自检 + 写缺失键（HDR/SDR、Windows HDR 前置核对）
│   ├── setup-driver.ps1       ← 驱动 / NGX core / NR 模型配套检查（可从 DriverStore 复制 _nvngx.dll）
│   ├── choose-adapter.ps1     ← 选卡检查/钉卡
│   └── selfcheck.ps1          ← 环境自检
├── docs/
│   ├── RUNTIME-FILES.md       ← **轻量包必读**：需要自备哪些 NVIDIA/AMD 运行时文件
│   ├── deployment-zh.md       ← 分步部署、配置含义、排障
│   ├── project-zh.md          ← 组件清单、实测记录、已知问题、回滚
│   ├── 19-screenshots-hotkeys-zh.md
│   ├── opt-a-n-en.md          ← OptiScaler 在 A+N 混插机上开启 DLSS 槽位（英文）
└── _release-assets/           ← 发布用 zip + .sha256（.gitignore 忽略，不进 git）
```

> **可选件 OPT（OptiScaler/FSR4）不包含在本轻量发布中**（含第三方二进制，许可与体积原因）。需要 OPT 的请看完整包/自行按 OptiScaler 文档安装；A+N 混插机先看 [`docs/opt-a-n-en.md`](docs/opt-a-n-en.md)（一行 `Dxgi=true` 修复）。

---

## 3. 前置条件

| 项 | 要求 |
|---|---|
| 系统 | Windows 10/11 64 位 |
| 显卡 | **A 卡负责渲染 + N 卡负责 NR/插帧**（本包验证：RX 9070 XT + RTX 5070 Ti）；**NR 需 RTX 50 系**（Blackwell），其它 RTX 型号未实测 |
| 显示 | N 卡的显示器；HDR10 屏可开 HDR；**显示线必须接 N 卡**（A 卡无头） |
| 运行时 | 见 `docs/RUNTIME-FILES.md`：NR 模型 / DLSS-G / vendor 运行库 / `_nvngx.dll`（本仓库**不提供**） |
| 工具 | Windows PowerShell 5.1（系统自带）；游戏可关闭 |

---

## 4. 安装（五步）

1. **备份游戏目录**里同名的 `dxgi.dll`、`nvngx*.dll`、`ReShade*.ini`、`mgpu.ini`（安装会直接覆盖）。
2. 把 `Win64/` 全部内容复制到**游戏 exe 所在目录**。
3. **补运行时文件**（轻量包的核心步骤，详见 `docs/RUNTIME-FILES.md`）：
   - `mgpu\_nvngx.dll`：跑 `powershell -ExecutionPolicy Bypass -File tools\setup-driver.ps1 -GameDir "<游戏exe目录>" -Apply`（从本机 DriverStore 复制）；
   - `mgpu\nvngx_dlssnr.dll`（NR 模型，310.9.16）、`mgpu\nvngx_dlssg.dll`、`mgpu\vendor_dlss.dll`、`mgpu\vendor_gpu.dll`：**你自备**（NVIDIA 运行时，本仓库不再分发），放进 `mgpu\`。
4. **首次自检**：
   `powershell -ExecutionPolicy Bypass -File tools\first-run.ps1 -GameDir "<游戏exe目录>"`（先 dry-run，确认后加 `-Apply`）；
   HDR 用户先开 Windows「设置→系统→显示→HDR」+ 显示器 HDR 模式；非交互可用 `-Hdr hdr|sdr|keep`。
5. 启动游戏 → 桥自动 arm，按 §6 验收。

> 运行时的放置/校验、以及"哪些文件由谁提供"的完整表见 [`docs/RUNTIME-FILES.md`](docs/RUNTIME-FILES.md)。

---

## 5. 工具脚本（全部在 `tools/`，详见 docs）

| 脚本 | 用途 |
|---|---|
| `first-run.ps1` | 部署自检 + 写缺失键（含 Windows HDR 前置核对、`ReShade.log` 真值交叉校验）；`-Apply` 才写、先备份 |
| `setup-driver.ps1` | 读驱动版本 / DriverStore `_nvngx.dll` / 模型变体；`-Apply` 复制私有 core；`-ModelPath` 换模型 |
| `choose-adapter.ps1` | 读 `[T2]`/`[R265]`/`[R270]` 建议钉哪张 N 卡；`-Apply` 写 `Display=`/`BridgeLuid`（需游戏先启动过一次） |
| `selfcheck.ps1` | 环境自检（只读） |
| `Win64\check-deploy.ps1` | 部署后自检（只读；退出码=FAIL 数） |

通用：`-ExecutionPolicy Bypass`；路径带空格/中文要加引号；写文件的脚本要求游戏关闭、改前自动备份。

---

## 6. 验收（进游戏后看 `ReShade.log`）

| 判据 | 期望 |
|---|---|
| 版本/内核 | `[R141] MGPU Bridge 0.4.0 \| built …`、`[R41x13b] adapt: api=… spoof=… chain_cs=… mvec=…` |
| N 卡选中 | `[T2] SELECTED adapter… desc="NVIDIA…"` |
| 色彩空间 | `[H1] bridge chain colour space: ChainColorSpace=0/12 …` |
| NGX core | `[R240] NGX core: loaded from the private mgpu copy` |
| NR 初始化 | `[P4.1] using the PRIVATE NR snippet … Init_Ext: result=0x00000001 (Success)` |
| 上屏 | `[V53] first neural frame: the bridge visual is now ROOTED` |
| 拓扑 | `[R189] BINDING CONFIRMED AT ARM: game renders on …(AMD) … bridge is on …(NVIDIA)` |
| 插帧 | `[FG] ARMED …`、`[FG] HEARTBEAT … failed=0 dropped=0` |

---

## 7. 默认值（面向陌生机器的安全值）

| 键 | 默认 | 说明 |
|---|---|---|
| `MVec` | 0 | 控制臂；**有真运动矢量的游戏（如 PBZ/Jedi）手写 `MVec=3`**，改完重启 |
| `ChainColorSpace` | 0（SDR） | HDR10 桌面/游戏必须改 12（或 `first-run.ps1` 回答 HDR） |
| `AdapterSpoof` | 不写（按 API 自动） | D3D12 开 / D3D11 关；显式 1/0 可强制 |
| `DX11` | 1 | D3D11 通路开关；D3D12 标题不触发 |
| `FGCount` | 1 | 插帧 2x；0=关、2=3x，改完重启 |
| `AdapterExcludeLuid` / `NGXLog` | 注释 | 本机示例/诊断项，陌生机器不要启用 |

---

## 8. 默认热键（面板 `HOTKEYS` 段可改绑）

| 动作 | 默认键 |
|---|---|
| 手动 arm（过场探针） | `Ctrl+Alt+F10` |
| Peek（撤掉神经画面） | `Ctrl+Alt+F6` |
| 视图：输出/输入/分割 | `Ctrl+Alt+F7` |
| 紧急关闭面板 overlay | `Ctrl+Alt+Home` |
| 成对截图 | `Ctrl+Alt+S` |
| 帧生成开关 | `Ctrl+Alt+F12` |
| NVOF 方向翻转 | `Ctrl+Alt+F7`（与视图同默认键，可改） |
| Look A/B | `Ctrl+Alt+L` |
| 屏幕 OSD | `Ctrl+Alt+F5` |

---

## 9. 面板

- `Home` → 直接是 `MGPU Bridge` 页；顶部作者/免费分享行（ASCII）；
- 实时帧率/延迟、NR 开关与强度、插帧开关与倍率、`NR MODEL` 模型选择、`SCREENSHOT` 设置、`HOTKEYS` 改绑；
- `OPT (optional)` 段：本轻量包未装 OPT 时显示 `○ OPT: not installed`（灰）；装了 OPT 时显示 `● OPT: RUNNING`（绿，含 backend 行）。

---

## 10. 常见问题

| 现象 | 先看什么 |
|---|---|
| 没有 NR 画面 | 先补 `mgpu\nvngx_dlssnr.dll` 与 `mgpu\_nvngx.dll`（`docs/RUNTIME-FILES.md`）；再看 `[P4.1]`/`[V53]` |
| `[P4.1] Init_Ext` 失败 | 驱动/core/模型三查：`tools\setup-driver.ps1` |
| NR/插帧不启动 | 跑 `tools\choose-adapter.ps1`：多半选到了同一张 N 卡的重复枚举行 |
| 画面发灰/过亮 | `ChainColorSpace`：HDR 用 12、SDR 用 0；HDR 用户先确认 Windows HDR 已开 |
| 插帧开关灰 | `FGCount=0` 时阶段未创建；改 `FGCount=1` 重启（面板有说明+按钮） |
| 截图发灰 | `CaptureAutoSdr=1`；看 `[R41x7] auto SDR: …` |
| 游戏启动闪退（D3D11） | spoof 已按 API 自动关；仍闪退把 `AdapterSpoof=0` 写死 |

---

## 11. 许可与致谢

- 本仓库的定制构建、脚本与文档：**MIT**（作者：电子羊羊尾，小黑盒 ID 38096711），见 `LICENSE`；
- 上游 MGPU Bridge / Neural-coprocessor：MIT（Marcelo Guibout）；
- ReShade 6.8：BSD-3（Copyright (c) 2014 Patrick Mours）；
- **NVIDIA DLSS 运行时（NR 模型/DLSS-G/vendor 库）与 AMD FSR 运行库：按 NVIDIA/AMD 许可，本仓库不随仓库/Release 再分发**，由用户自备（见 `docs/RUNTIME-FILES.md`）；
- OptiScaler（可选模块）：按其自身许可，本轻量发布不含；
- 本仓库不包含任何游戏文件。

**本包免费分享，禁止倒卖/付费售卖。**
