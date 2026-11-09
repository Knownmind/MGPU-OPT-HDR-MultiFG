# 19 · 截图与热键：实现与验收（2026-11-09）

> 性质：**功能落地记录**（不是分析）。覆盖 2026-11-09 这一轮 `CTRL+ALT+S` 截图管线（R40x → R41x4）与 MGPU 面板热键改绑（R41x → R41x4）的实现、缺陷复盘与验收结果。
> 最高原则不变：A 卡渲染 + N 卡 NR/插帧；本文所有改动都不碰这条链。

---

## 0. 一页纸

| 项 | 现状（2026-11-09 12:05 装机，addon `c70767bc…` / 1,348,608B） |
|---|---|
| **截图格式** | **永远是 8-bit SDR**（PNG/JPG/BMP），与游戏是 HDR 还是 SDR 无关 |
| 颜色链路 | HDR10（`ChainColorSpace=12`）：PQ 解码 → **BT.2020→BT.709** → ACES 肩 → sRGB（纸白 BT.2408 203 nit）；SDR（≠12）：**直通**（线性光里只乘曝光） |
| 帧格式 | R10G10B10A2 / RGBA16F / R8G8B8A8 / B8G8R8A8 / B8G8R8X8 |
| 输出文件 | `CaptureFormat=png`（默认，3440×1440 约 3–6MB）/ `jpg`（`CaptureJpegQuality=92`，约 1MB）/ `bmp`（14.9MB） |
| 保存位置 | 默认 **`C:\Users\<你>\Pictures\MGPU`**（`SHGetKnownFolderPath(FOLDERID_Pictures)`，重定向/OneDrive 也认）；`ini` = mgpu.ini 同目录 `mgpu_captures`；其它 = 自定义（绝对/`%ENV%`/`~/相对`，含空格） |
| 限频 | `CaptureMinIntervalMs=1500`（默认；0=关）+ 同一时刻只写一张；日志 `took=NNNms` |
| 热键改绑 | MGPU 面板最下面 `HOTKEYS` 段，**16 个动作全部可改**；必须带 Ctrl/Alt/Shift；写 `mgpu.ini` 的 `Hotkey*`，**立即生效** |
| 已知限制 | 改键时按键**游戏也会收到**（无法吞键，所以裸键默认禁止；确需裸键在面板勾选 `Allow bare keys`，写 `HotkeyAllowBare=1`）；被其它程序占用的组合注册不上，面板状态列显示 `claimed` |

---

## 1. 截图管线

### 1.1 判定"这帧是什么色彩"

`gpu1_context.cpp` 的 `capture_finish()` 里：

```cpp
const int chain_cs = ini_read_chain_colorspace();      // mgpu.ini 的 ChainColorSpace，默认 12
const bool hdr_chain = (chain_cs == 12);
int mode = 0;                                          // 0 = SDR display-referred
if (c.fmt == DXGI_FORMAT_R16G16B16A16_FLOAT)      mode = hdr_chain ? 2 : 3;
else if (c.fmt == DXGI_FORMAT_R10G10B10A2_UNORM)  mode = (hdr_chain && tonemap != 0) ? 1 : 0;
```

| mode | 含义 | 转换 |
|---|---|---|
| 1 | HDR10 PQ / BT.2020 | PQ EOTF → BT.2020→BT.709（负值向亮度去饱和，保色相）→ ×(10000/203) → ACES 肩 → sRGB |
| 2 | FP16 HDR | ×曝光 → ACES 肩 → sRGB |
| 3 | FP16 SDR | ×曝光 → clamp → sRGB |
| 0 | 8/10-bit SDR display-referred | sRGB 解码 → ×曝光 → sRGB 编码（曝光 1.0 时为恒等） |

### 1.2 输出文件

- `CaptureFormat=png|jpg|bmp`；PNG/JPEG 走 **WIC**（`windowscodecs`）。
- **文件命名（R41x5 起）**：`YYYYMMDD-HHMMSS_nr_before.<ext>` / `..._nr_after.<ext>`——时间前缀在前，**按名字排序就是按截图时间排序**；同一秒冲突自动加 `-2`，不覆盖。
- **R41x3 修的坑**：`IWICImagingFactory::CreateEncoder` 的第一个参数是**容器格式 GUID**；R40y–R41x2 误传了 `CLSID_WICPngEncoder/CLSID_WICJpegEncoder`，WIC 返回 `WINCODEC_ERR_COMPONENTNOTFOUND (0x88982F50)`，文件被创建成 0 字节，随后静默回退 BMP，而日志仍写 `.png`。
- 正确写法：`GUID_ContainerFormatPng` / `GUID_ContainerFormatJpeg`。离线复现：旧写法 `hr=0x88982F50`，新写法 `hr=0x00000000`（见 §2.2）。
- **实机验证（2026-11-09 10:29 局）**：PNG 成对写出，`nr_before` 6,242,258 B / `nr_after` 6,536,903 B（3440×1440），日志 `file=png, mode=1, chain_cs=12`，无 `WIC ... encode failed`。
- **R41x6 色彩修正**：用户反馈 NR 后截图"饱和太高"。逐通道 ACES 会让亮部彩色高光保持一个屏幕不会出现的通道比；改为默认保亮度 ACES + 可调 `CaptureSaturation`，日志加 `tone=` / `sat=`。`CaptureTonemap=2`（保留 BT.2020 原色）方向相反，不要用来救饱和。
- **R41x7 通用自动 SDR（每个游戏都适用）**：不再依赖每个游戏手填 `ChainColorSpace`。判定矩阵：
  | 游戏链格式 | 显示器 HDR | 判定 | 转换 |
  |---|---|---|---|
  | 8-bit（R8G8B8A8/B8G8R8A8/B8G8R8X8） | 任意 | SDR | 直通 |
  | R10G10B10A2 | 开 | HDR10 PQ / BT.2020 | PQ 解码 → BT.2020→709 → 帧统计 EETF（纸白 203 nits） |
  | R10G10B10A2 | 关 | SDR（10-bit） | 直通 |
  | FP16 | 任意 | scRGB 线性（80 nit 参考） | 线性 → 帧统计 EETF |
  检测来源：ReShade present 事件里对**游戏自己的 swap chain** 取 `GetDesc1().Format` + `GetContainingOutput → IDXGIOutput6::GetDesc1().ColorSpace`（DXGI 没有 `GetColorSpace1`，不能直接问 swapchain 色彩空间）。日志：`[MGPU][R41x7] game swap chain: format=.., display HDR=..` 与 `auto SDR: game_fmt=.. display_hdr=.. src=.. peak=.. nits median=.. knee=..`。`CaptureAutoSdr=0` 一键回手动档。

### 1.3 保存位置（R40z3 起）

```cpp
// 空 -> Pictures\MGPU（已知文件夹）；"ini" -> mgpu.ini 同目录 mgpu_captures；其它 -> 自定义
void capture_dir(wchar_t *dir, size_t cap_chars);
```

- 用 `SHGetKnownFolderPath(FOLDERID_Pictures, KF_FLAG_CREATE, ...)`，不是硬编码 `%USERPROFILE%\Pictures`——图片库被重定向到别的盘 / OneDrive 时也正确。
- 路径读取用 `ui_ini_read_value`（读到行尾、保留空格），修掉了旧 `ui_ini_read_word` 遇空格截断的问题。
- 支持 `%USERPROFILE%\Pictures\NR`、`~\shots`、相对 `mgpu.ini` 的相对路径。
- **面板里也能改（R41x5）**：MGPU 面板最下面 `SCREENSHOT` 段——`CaptureDir` 输入框 + `Apply` + `Open`、`Format` 下拉、`Min interval (ms)`，全部下一次截图生效。
- **改 `CaptureDir` 是热生效的**：每次截图都重新读一次 mgpu.ini，所以改完保存、下一次按键就写到新目录，**不用重启游戏**（这一点和别的 ini 键不同）。
- 目录建不出来 → 自动回退 `mgpu_captures` 并打 warn（不静默丢图）。
- 启动日志打印最终目录，不用截图就能确认：
  ```
  [MGPU][R40x] screenshot folder: <用户目录>\Pictures\MGPU (CaptureDir: empty = Windows Pictures\MGPU, ...)
  ```

### 1.4 限频与耗时（R40z2 起）

- `CaptureMinIntervalMs=1500`（默认；`0` 关闭）：从上一张**写完**起算，间隔内的按键直接丢弃，同一条 warn 5 秒最多一条。
- 同一时刻只写一张（`busy`/`pending` 守卫），不会两对 readback 同时压在暂存缓冲上。
- 一次截图的成本 = 等本帧围栏 + 两次整帧转换 + 两次编码写盘；日志 `took=NNNms` 给出实测值。**实测 891ms**（BMP 回退那两次）；PNG 正常后预计明显更小。

### 1.5 键表

| 键 | 默认 | 说明 |
|---|---|---|
| `CaptureDir` | 空 | 见 §1.3 |
| `CaptureFormat` | `png` | `png` / `jpg` / `bmp` |
| `CaptureJpegQuality` | `92` | 仅 jpg |
| `CaptureTonemap` | `1` | 1 正常（HDR 走转换）；2 保留 BT.2020 原色（A/B）；0 线性诊断 |
| `CaptureExposure` | `1.0` | SDR 曝光倍数 |
| `CaptureAutoSdr` | `1` | **自动 SDR（每个游戏通用）**：按游戏链格式 + 显示器 HDR 状态判定源类型，按帧统计 EETF；=0 回手动档 |
| `PanelFocusOnOpen` | `1` | R41x8：HOME 呼出自动选中 MGPU Bridge 页（=0 保持 ReShade Home 页） |
| `CaptureToneMode` | `2` | 手动档：1=逐通道 ACES（更艳）；2=保亮度 ACES（高光不过饱和） |
| `CaptureSaturation` | `100` | 饱和度百分比（显示线性里绕亮度缩放色度；偏艳调 80–90） |
| `CaptureMinIntervalMs` | `1500` | 限频 |

### 1.6 日志字段（一次截图一行）

```
[MGPU][R40x] screenshot written: ...\nr_before_20261109-100821.png | ...\nr_after_20261109-100821.png
   (3440x1440, fmt=24, exposure=1.00, tonemap=1, file=png, mode=1, chain_cs=12, took=NNNms)
```
`mode`：1=HDR10 PQ，0=SDR 直通，2=FP16 HDR，3=FP16 SDR；`chain_cs` 是读到的 `ChainColorSpace`；`file` 是**实际**写出的格式（回退 BMP 时这里变成 bmp）。

---

## 2. 缺陷复盘

### 2.1 裸键被游戏吃掉（F11 → 游戏窗口化）

- 面板录制新键时只**读取**按键（`GetAsyncKeyState`），无法把按键从游戏手里拦下来。用户在面板里录 `F11`，游戏同时收到 F11（Jedi Survivor 把它当全屏/窗口切换）。
- 日志证据链（2026-11-09 10:08 局）：
  ```
  10:08:06  [R41x] hotkey "Screenshot (NR pair)" is now F11
  10:09:17  [R71] MVEC SIZES ... 2296x1436 ...          ← 全屏 3440x1440 之外的窗口尺寸
  10:09:20  [R63] DEPTH TRANSPORT ... valid=7007 invalid=3495   ← 深度覆盖掉到 67.2%
  ```
- 窗口尺寸变化本身又触发 14 号那个"桥不跟随 resize"的已知问题（重启游戏才恢复）。
- **修法（R41x2）**：改绑**必须带至少一个修饰键**（Ctrl/Alt/Shift），裸键直接拒绝并说明原因；启动时读到 ini 里的裸键也忽略、回落默认。
- 相关：`F12` 注册失败是因为 Steam 的截图键占了它；`Alt+Tab` 是系统保留组合——这类组合现在在面板条目后面标红 `(claimed by another app)`。

### 2.2 PNG/JPEG 根本写不出来（R40y–R41x2）

- 现场证据（2026-11-09 10:08:19 局）：`mgpu_captures` 里出现 **0 字节的 `.png`** + 14,860,854 B 的 `.bmp`，日志同时打：
  ```
  WARN  [MGPU][R40y] WIC encoder failed - the pair was written as BMP instead
  INFO  [MGPU][R40x] screenshot written: ...nr_before_....png | ...nr_after_....png (... file=png ...)
  ```
- 离线复现（同一套 writer 代码，`<开发目录>\wic_test`）：旧写法 `hr = 0x88982F50`（`WINCODEC_ERR_COMPONENTNOTFOUND`），PNG/JPEG 都失败；把 `CreateEncoder` 的第一个参数从 **CLSID** 改成 **`GUID_ContainerFormatPng` / `GUID_ContainerFormatJpeg`** 后 `hr = 0x00000000`，PNG/JPEG 都正常写出。
- **修法（R41x3）**：改 GUID；失败日志带 `hr=`；回退 BMP 时把日志里的文件名改成真实的 `.bmp`（不再谎报 `.png`）；JPEG 质量属性改用 `memset` 初始化（不依赖 `oleaut32` 的 `VariantInit`）。

### 2.3 旧把 BMP 当默认（R40x）

- 早期只有 24-bit BMP（14.9MB/张），分享不便，也没有 SDR 需求 → R40y 起加 PNG/JPEG 与 SDR 转换；R40z 起"始终 SDR"。

---

## 3. 热键改绑（R41x 起）

### 3.1 覆盖范围（16 个动作）

| 动作 | 默认键 | ini 键 |
|---|---|---|
| 截图（NR 对） | Ctrl+Alt+S | `HotkeyScreenshot` |
| 手动布防（transit probe） | Ctrl+Alt+F10 | `HotkeyArm` |
| 强度：切目标 / − / + | Ctrl+Alt+F8 / F9 / F11 | `HotkeyIntTarget` / `HotkeyIntDown` / `HotkeyIntUp` |
| Peek（隐藏/恢复桥画面） | Ctrl+Alt+F6 | `HotkeyPeek` |
| View（输出→输入→分割） | Ctrl+Alt+F7 | `HotkeyView` |
| 紧急关面板 | Ctrl+Alt+Home | `HotkeyOverlayClose` |
| 分割线 左/右 | Ctrl+Alt+←/→ | `HotkeySeamLeft` / `HotkeySeamRight` |
| 分割线 粗调 | Ctrl+Alt+Shift+←/→ | `HotkeySeamLeftCoarse` / `HotkeySeamRightCoarse` |
| 帧生成 开/关（轮询） | Ctrl+Alt+F12 | `HotkeyFrameGen` |
| NVOF 方向翻转（轮询） | Ctrl+Alt+F7 | `HotkeyNvofFlip` |
| Look A/B（轮询） | Ctrl+Alt+L | `HotkeyLookAB` |
| 屏上 OSD（轮询） | Ctrl+Alt+F5 | `HotkeyOsd` |

> 默认里 `HotkeyView` 与 `HotkeyNvofFlip` 都是 Ctrl+Alt+F7（历史值），想分开就在面板改其中一个。

### 3.2 机制

- 统一表在 `src/hotkeys.hpp/.cpp`，两种机制都读它：`RegisterHotKey`（worker.cpp，`WM_HOTKEY`）与轮询（fg/nvof/look/osd 的 `GetAsyncKeyState`，靠 `mgpu::hotkeys::down()`）。
- 面板只负责改表 + 写 ini + 置 `pending`；**重注册必须在 worker 线程**（WM_HOTKEY 投递到注册它的线程队列），所以 worker 的泵循环每轮检查 `pending_apply()` 并 `Unregister/Register` 全部键。
- 格式：`Ctrl+Alt+Key`（大小写不敏感；键名支持 F1–F24、A–Z、0–9、Left/Right/Up/Down/Home/End/PageUp/PageDown/Insert/Delete/Space/Tab/Enter/Backspace 等；`VKxx` 十六进制兜底）；`none` 表示禁用。

### 3.3 面板位置与操作

- `Home` 打开 MGPU 面板 → 标签页 `MGPU Bridge` 拉到**最下面** → `HOTKEYS` 段。
- 每行：动作名 / 当前键 / 状态 / `Change`；点 `Change` 后按新组合键（Esc 取消）；`Reset all to defaults` 一键恢复。
- 状态列（R41x4）：`claimed` = 该组合被别的进程占用（Steam F12、系统 Alt+Tab、显卡驱动的旋转屏幕 Ctrl+Alt+←/→ 等），`off` = 已禁用，空 = 正常。先前把这一长句塞在键名列里，导致被占用的那两行**行高异常**，已改为短状态列。
- `Allow bare keys (no Ctrl/Alt/Shift)`（R41x4）：勾选后允许录裸键（写 `HotkeyAllowBare=1`），代价是游戏也会收到这些键；默认关闭。
- 冲突：与其它动作同组合 → 拒绝并提示。
- 结果立即生效（轮询键当帧；注册键 worker 下一次泵），日志：
  ```
  [MGPU][R41x] hotkey "Screenshot (NR pair)" is now Ctrl+Alt+K (written to mgpu.ini HotkeyScreenshot=Ctrl+Alt+K).
  [MGPU][R41x] hotkeys re-registered after a panel change: arm=OK intensity=OK/OK/OK peek=OK view=OK
               overlay-close=OK screenshot=OK seam=OK/OK/OK/OK
  ```

### 3.4 限制（如实）

1. 改绑时按键**游戏也会收到**（我们无法吞键）→ 裸键默认禁止、需显式勾选 `Allow bare keys` 才放开；建议用游戏不用的组合。
2. 被其它程序占用的组合注册不上（Steam F12、系统 Alt+Tab 等）→ 面板标红，换一个。
3. 轮询类键只在游戏窗口前台时响应（原行为）；注册类任何前台窗口都响应。
4. 深度诊断键（NVOF 的 F2/F3/F4）不在改绑表内，属于仪器类。

---

## 4. 验收清单

- [ ] 进游戏 → `Home` → 面板底部 `HOTKEYS` 能看到 16 行、当前键正确；
- [x] 改 `Screenshot (NR pair)`（实测改成 Ctrl+S），日志出现 `hotkey ... is now ...` 与 `hotkeys re-registered ... screenshot=OK`；
- [x] 按新键 → `图片\MGPU\` 出 **`*_nr_before.png` / `*_nr_after.png`（非 0 字节）**，日志 `file=png, mode=1, chain_cs=12`；无 `WIC ... encode failed`（**2026-11-09 10:29 实测通过**：6.24MB / 6.54MB）；
- [ ] 连按两次 → 只出一对图 + 一条 `rate limited (CaptureMinIntervalMs)` warn；
- [ ] 重启游戏后改过的键仍然生效（ini 持久化）；
- [ ] `CaptureDir=D:\NR截图` → 下一张即写到该目录（热生效，无需重启）；
- [ ] `CaptureFormat=jpg` → 出 `.jpg`（约 1MB），分享用。

---

## 5. 回滚锚

| 内容 | 锚点 |
|---|---|
| addon | 游戏目录 `nvngx.dll_mgpu_bridge.addon64.bak-20261109-*-R4*`（每一版都有），部署包 `Win64/` 同名 .bak；当前 **R41x4 `d1910488…` / 1,339,392B** |
| 源码 | `02-源码/mgpu-fork-repo/src/*.bak-20261109-R40*/R41*` |
| mgpu.ini | `mgpu.ini.bak-20261109-*` |
| 文档/脚本 | `*.bak-20261109-*pin` |
| 本功能整体回退 | 换回 R40z3 之前的 addon（截图只有 BMP、无改绑）；`Hotkey*` 行可直接删掉，启动按默认 |

---

## 6. 依据

| 内容 | 位置 |
|---|---|
| 截图管线 | `02-源码/mgpu-fork-repo/src/gpu1_context.cpp`：`capture_finish` / `write_wic_image` / `capture_dir` / `shot_pixel` |
| 热键表 | `src/hotkeys.hpp` / `src/hotkeys.cpp`；注册与重注册 `src/worker.cpp`（`hk_reg` / `hk_apply_changes`）；面板 `src/dllmain.cpp`（`draw_hotkeys_section`） |
| 轮询键改表 | `src/fg.cpp` / `src/nvof.cpp` / `src/look.cpp` / `src/osd.cpp` 的 `hotkeys()`/`tick()` |
| 现场日志 | `<SteamLibrary>\Jedi Survivor\SwGame\Binaries\Win64\ReShade.log`（10:05–10:09 局） |
| 离线 WIC 复现 | `<开发目录>\wic_test`（旧 GUID → `hr=0x88982F50`；新 GUID → `hr=0`） |
| 一致配方 | `13-OPT-FSR4+桥NR-FG共存-实测配方-20261108.md` §11 |
| 版本注记 | R41x4：裸键勾选（`HotkeyAllowBare`）+ 热键表 4 列状态列（修两行高度异常） |
| 方案与 Phase 0 | `16-OPT-DLSS注入与ReShade-MGPU共存-实施方案-20261109.md` §14 |
