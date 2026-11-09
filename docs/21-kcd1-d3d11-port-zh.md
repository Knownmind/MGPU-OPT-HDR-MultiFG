# 21 - 移植记录：11.2 当前版本 → Kingdom Come: Deliverance（KCD1，D3D11）

> 性质：**移植记录与验收清单**（不是方案分析）。
> 日期：2026-11-09 11:41（换件）｜执行：本机 KCD1 安装目录
> 结论：**桥在 KCD1 上可用**，走的是桥自带的**实验性 D3D11 通路**（`DX11=1`）；**OPT 模块不需要**。

## 1. 事实与结论

| 项 | 值 |
|---|---|
| 游戏 | Kingdom Come: Deliverance（KCD1，CryEngine） |
| 安装目录 | `<SteamLibrary>\KingdomComeDeliverance\Bin\Win64` |
| 图形 API | **D3D11**（日志 `[T2] init_device: not a d3d12 device`；`[R287] Game chain D3D12=no`） |
| 桥的通路 | **`mgpu.ini` → `DX11=1` → D3D11 producer**：桥在 A 卡（RX 9070 XT）上建自己的 D3D12 设备，用 **D3D11.4 共享纹理 + 共享 fence** 从游戏的 D3D11 context 取帧；N 卡（RTX 5070 Ti）继续跑 NR（`mgpu\nvngx_dlssnr.dll`）与 FG |
| 首次换件 | 旧 addon `2,001,408B / e68ea955… / 0.4.0 built Oct 30 2026` → R41x8 `6b9bf034…`（**启动失败，见 §7.5**） |
| 修复后换件 | **R41x9 `1,348,608B / c70767bc…`（2026-11-09 build，D3D11 通路关闭适配器 spoof）** |
| 备份 | `…bak-20261109-114124-KCD1-pre` 与 `…bak-20261109-1145-KCD1-r41x9pre`（两份都是原始 2MB 认证版 `e68ea955…`，回滚任选其一；R41x8 `6b9bf034…` 保存在部署包 `Win64/` 里） |
| ini | **未改动**。KCD1 现有键全部保留：`DX11=1`（必须）、`ChainColorSpace=0`（KCD1 是 SDR，正确）、`Neural=1`、`DcompOverlay=1`；R41x/R41x7/R41x8 的新键全部**走默认值**（见 §4） |

## 2. 桥在 DX11 上是怎么跑起来的（日志实证）

2026-11-09 11:34–11:36 那一局（旧 addon）已经证明整条链路是通的：

```
[MGPU][DX11P] DX11=1: building the D3D11 producer - a D3D12 device of ours on the game's adapter,
              fed from the game's D3D11 context through shared textures and a shared fence. Experimental.
[MGPU][DX11P] PRODUCER BUILT on the game's adapter luid=0x...-0x00012A71: shared colour 2560x1440 fmt=28
[MGPU][T2] adapter[1] "NVIDIA GeForce RTX 5070 Ti" (luid=0x...-0x0000D5C6) SELECTED
[MGPU][T3] D3D12CreateDevice hr=0x00000000 luid=0x...-0x0000D5C6 - device live on the second adapter
[MGPU][SEAL] new f=... slot=... gap=1 lat=~20-28ms pitch=10240 fmt=28 bytes=14745600 OK
[MGPU][NVOF] f=... kicks=... execs=... exec_failed=0 ...        ← 光流在跑
[MGPU][R63] DEPTH TRANSPORT f=... mode=1 (TRANSPORTED AND BOUND)
[MGPU][R240] NGX core (_nvngx.dll): loaded ...
[MGPU][P4.1] Init_Ext: result=0x00000001 (Success) app_id=0x4D475055
[MGPU][FG] snippet Init_Ext(app_id=0x4D475055, GPU 1 device) result=0x00000001 (Success)
[MGPU][V53] first neural frame: the bridge visual is now ROOTED (on screen)
[MGPU][V49] COMPOSING INTO THE GAME'S WINDOW ... topmost DirectComposition visual on the game's own HWND
[MGPU][T5] present loop alive: frame 10200 thread id 0x7C40
```

要点：**NR 与 FG 都初始化成功并上屏**，游戏画面经 DComp 合成到游戏自己的窗口上，桥没有额外窗口。

## 3. 本机 KCD1 现状（换件后）

| 文件 | 值 |
|---|---|
| `nvngx.dll_mgpu_bridge.addon64` | **1,348,608 B / `6b9bf034…`（R41x8）** |
| `dxgi.dll` | 5,592,064 B = **stock ReShade 6.x 代理**（非 OPT 模式，与 Jedi 包内的 `dxgi.dll` 同一文件） |
| `mgpu\nvngx_dlssnr.dll` | **266,424,944 B**（用户自选模型，**本次未动**；与 11.2 包内 310.9.16 的 276,162,560 B 不同，属 KCD1 独立配置） |
| `mgpu\nvngx_dlssg.dll` | 7,506,544 B（FG 用） |
| `mgpu.ini` | 38,203 B（756 行，KCD1 专用调参，未改） |
| `gpu1.ini` | 30 B（桥的 ReShade 预设，未改） |

## 4. 新键的默认值（不写进 ini 也生效）

面板第一次改动会自己写回 ini；不改就用默认：

| 键 | 默认 | 说明 |
|---|---|---|
| `HotkeyScreenshot` | `Ctrl+Alt+S` | 成对截图 |
| `Hotkey*`（其余 15 个） | 见面板 `HOTKEYS` 段 | 全部可改绑，见 19 号文档 |
| `CaptureFormat` | `png` | 也可 `jpg` / `bmp` |
| `CaptureDir` | 空 = `图片\MGPU` | 面板 `SCREENSHOT` 段可改，热生效 |
| `CaptureMinIntervalMs` | `1500` | 连按防卡死 |
| `CaptureAutoSdr` | `1` | 自动识别：KCD1 是 SDR → 直通（不会 PQ 误解码） |
| `PanelFocusOnOpen` | `1` | HOME 呼出直接落在 `MGPU Bridge` 页 |
| `AdapterSpoof` | **KCD1 显式写 `0`** | 新版默认在 `DX11=1` 时也关（见 §7.5）；写 0 是双保险 |

## 5. 进游戏后的验收清单（按顺序看 `ReShade.log`）

1. `[R141] MGPU Bridge 0.4.0 | built Nov  9 2026`（确认换件成功，R41x8）；
2. `[DX11P] PRODUCER BUILT ... shared colour 2560x1440 fmt=28`；
3. `[SEAL] ... OK` 持续出现、`[NVOF] exec_failed=0`；
4. `[P4.1] Init_Ext: result=0x00000001`、`[FG] ... Success`、`[V53] first neural frame ... ROOTED`；
5. `[R41x7] game swap chain: format=28, display HDR=OFF (SDR)`；
6. `[R41x8]`（面板页）：按 `Home` 应直接看到 `MGPU Bridge` 页；
7. 按 `Ctrl+Alt+S`（或自己在面板改的键）→ `图片\MGPU\` 出 `YYYYMMDD-HHMMSS_nr_before.png` / `_nr_after.png`；日志 `[R40x] screenshot written ... tone=.., sat=..`，无 `WIC ... encode failed`；
8. 面板 `HOTKEYS` 段可改绑、`SCREENSHOT` 段可改目录/格式/限频。

## 6. OPT 模块：不需要（KCD1 上不建议叠）

- **桥不需要 OPT**：Jedi 上的 OPT 模块只做"把游戏 FSR2 输入换成 A 卡 FSR4"，与桥运行无关；KCD1 上桥走自己的 DX11 通路，当前**没有装 OptiScaler** 也跑通了 NR/FG。
- **KCD1 自带超分**：DLSS 2（2021 补丁，A 卡不可用）+ FSR 1（质量较旧）。想升级到 FSR 2/3 才需要 OPT（接管 DLSS 输入、DX11 支持）；**FSR4 是 DX12 路径，KCD1 用不上**（实验构建另说，不可依赖）。
- **风险**：`OPT + 桥` 目前只在 Jedi（DX12/UE4、FSR2 输入）验证过；KCD1（DX11/CryEngine、DLSS 输入）是新组合，OPT 的 spoof 可能与桥的 NGX 时序（`[R287] scene hold` 等游戏第一次 DLSS evaluate）冲突，需单独实测。

## 7. 已知限制（DX11 通路）

1. `[DX11P]` 自己的日志写明：**Experimental. Real vectors and own Reflex are not on this path yet.** → 没有游戏真运动矢量、没有桥自带 Reflex；光流靠 NVOF（日志里 `[NVOF]` 在跑），FG 质量以 NVOF 为准。
2. `ChainColorSpace=0` 固定 SDR：KCD1 PC 无 HDR，正确；截图自动 SDR 会走 SDR 直通。
3. 截图每对 PNG 约 12.8MB、present 线程约 1.4s（`took=` 可见），限频 1500ms 兜底。
4. 若某次 arm 失败，按 `docs/deployment-zh.md` §6 的顺序查；DX11 通路优先看 `[DX11P] STOPPED at %s` 指出的那一步。


## 7.5 启动失败的复盘（2026-11-09 11:48，R41x8 首次换件后）

**现象**：启动后图标一闪，游戏没打开（`kcd.log` 末尾只有 `Renderer initialization` → `System Shutdown`；`kcd_launcher.log` 显示退出）。

**证据**（`ReShade.log`，11:48:47）：
```
[MGPU][DX1] adapter description spoof INSTALLED from the game device (AMD -> NVIDIA 0x10DE/0x2684)
Redirecting D3D11CreateDeviceAndSwapChain(...)
...
[WARN] D3D11CreateDeviceAndSwapChain failed with error code E_FAIL.
```
即：新构建在启动时把"游戏枚举到的 A 卡描述"改写成 NVIDIA RTX 4090（R-DX1/R-DX2 适配器 spoof），之后游戏自己的 D3D11 设备+交换链创建失败 → 游戏直接退出。

**为什么旧版没事**：certified 10/30 版 addon **完全没有 spoof 代码**（二进制里 0 处 "adapter description spoof"），而 R41x8 里 1 处且**无条件安装**。KCD1 走 D3D11 通路，这个 spoof 对它只有害处。

**修复（R41x9）**：spoof 在 **`DX11=1` 时默认不装**（新键 `AdapterSpoof`：1 强制开 / 0 强制关 / 缺省按 API 判断）；KCD1 的 `mgpu.ini` 再显式写 `AdapterSpoof=0` 双保险。D3D12 标题（Jedi）不受影响，spoof 默认仍开。

**回滚锚点**：`nvngx.dll_mgpu_bridge.addon64.bak-20261109-114124-KCD1-pre`（2MB 认证版，写入即回到换件前）。

## 7.6 面板不在 ReShade 里、浮成一个小窗口（2026-11-09 12:32 修复）

**现象**：KCD1 上按 `Home` 呼出后，`MGPU Bridge` 面板是一个**独立小窗口**，不在 ReShade 的标签栏里；Jedi 上它是 dock 在 ReShade 面板里的一个页签。

**原因**：ReShade 6.8 的 overlay 是 ImGui 的 dock 布局，每个 overlay（含 addon 注册的 "MGPU Bridge" 窗口）dock 到哪个节点记在 `ReShade.ini` 的 `Docking=` / `Window=` 状态里。Jedi 的包内 `ReShade.ini` 是**预置好 dock 的**（`[Window][MGPU Bridge] … DockId=0x00000001`），而 KCD1 的 `ReShade.ini`（11-05 保存）里的 `Window=` 列表**没有 MGPU Bridge 这一项** → ImGui 把新窗口当浮动窗口创建，于是出现"单独一个小窗口"。不是 R41x8/R41x9 的行为差异。

**修复**：在 KCD1 `Bin\Win64\ReShade.ini` 的 `Window=` 串里、`[Window][###about]` 之后插入一行（与 Jedi 同构）：
```
[Window][MGPU Bridge],Pos=8,,8,Size=895,,1424,Collapsed=0,DockId=0x00000001,,6,
```
这样 ReShade 下次启动会把 MGPU Bridge 窗口 dock 进主标签栏（ReShade 退出/关闭 overlay 时会自己把状态写回）。
备份：`ReShade.ini.bak-20261109-1232-dockpre`。

**若仍然浮动**（ReShade 没采纳预置状态）：overlay 打开时把 `MGPU Bridge` 窗口的标题拖到 ReShade 标签栏上松手，它就会 dock；关一次 overlay（状态写回 ini）之后永久生效。R41x8 起的 `PanelFocusOnOpen` 会在每次打开时 focus 该窗口，所以 dock 之后每次 `Home` 都会直接选中它。

## 8. 回滚

```powershell
Copy-Item "<SteamLibrary>\KingdomComeDeliverance\Bin\Win64\nvngx.dll_mgpu_bridge.addon64.bak-20261109-114124-KCD1-pre" `
          "<SteamLibrary>\KingdomComeDeliverance\Bin\Win64\nvngx.dll_mgpu_bridge.addon64" -Force
```
（游戏需先退出；ini 未改，无需回滚 ini。）

## 9. 后续可选

- [ ] 进游戏跑一局，按 §5 逐条勾掉，把日志片段追加到本文 §5 下方；
- [ ] 若 NR 在 KCD1 上的观感需要调，优先动 `NRFrameFilter` / 强度键（`Ctrl+Alt+F9/F11`），不要动 `DX11=1`；
- [ ] 若要试 OPT：先只装 OptiScaler（不碰桥配置）验证 FSR 2/3 超分本身，再考虑与桥共存；
- [ ] KCD1 的 `mgpu\nvngx_dlssnr.dll` 是用户自选 266MB 模型，**任何升级/回滚都不要覆盖它**。
