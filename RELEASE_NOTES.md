# MGPU 11.9 · 轻量发布（R41x13j）

> 作者：电子羊羊尾（小黑盒 ID 38096711）｜**免费分享，禁止倒卖/付费售卖**

## 包含

- `Win64/`：桥内核 **R41x13j**（`nvngx.dll_mgpu_bridge.addon64` = 1,360,896 B / `sha256:13e01caf…`）、ReShade 6.8 `dxgi.dll`、`mgpu.ini`、ReShade 配置、深度抓取 shader、`check-deploy.ps1`；
- `tools/`：`first-run.ps1`、`setup-driver.ps1`、`choose-adapter.ps1`、`selfcheck.ps1`；
- `docs/`：部署排障、运行时文件说明、项目记录、截图/热键、KCD1 D3D11 移植记录。

## **不包含（需自备）**

NVIDIA DLSS 运行时（`nvngx_dlssnr.dll` / `nvngx_dlssg.dll` / `vendor_*.dll` / `_nvngx.dll`）与 AMD FSR 运行库、OptiScaler 可选模块——按各自许可不再分发，见 `docs/RUNTIME-FILES.md`。

## 安装（摘要）

1. 复制 `Win64/` 全部内容到游戏 exe 目录；
2. 按 `docs/RUNTIME-FILES.md` 放好 `mgpu\` 运行时文件；
3. `setup-driver.ps1 -GameDir "<游戏exe目录>" -Apply`；
4. `first-run.ps1 -GameDir "<游戏exe目录>"` 看 dry-run，再加 `-Apply`；
5. 启动游戏，按 README §6 验收。

## 校验

下载后校验压缩包（与仓库 `SHA256SUMS.txt` 分别核对）：

```
<见 Release 附件 .sha256.txt>
```

## 已知限制

- NR 需 RTX 50 系（其它 RTX 未实测）；
- 显示线必须接 N 卡（A 卡无头）；
- HDR 需 Windows HDR + 显示器 HDR 同时开启；
- 本版本不带 OPT；需要 OPT 超分请自行按 OptiScaler 文档安装。

---

## English summary

**MGPU 11.9 (R41x13j) — lite release, free share.** A dual-GPU bridge for "AMD renders + NVIDIA runs DLSS-NR / NVOF / DLSS-G frame generation / HDR10 output". This lite zip contains the bridge add-on, ReShade 6.8, ini/config, tools and docs — **no NVIDIA/AMD runtime binaries**: supply `mgpu\nvngx_dlssnr.dll`, `mgpu\nvngx_dlssg.dll`, `mgpu\vendor_*.dll` and `mgpu\_nvngx.dll` yourself (see `docs/RUNTIME-FILES.md`). Install: copy `Win64/` into the game exe dir → add runtime files → `setup-driver.ps1 -Apply` → `first-run.ps1` (dry-run then `-Apply`) → launch. Requirements: Windows 10/11, AMD render + RTX 50 NVIDIA card, monitor wired to the NVIDIA card. License: MIT (author 电子羊羊尾, Heybox 38096711); upstream MIT/BSD-3 notices in `THIRD_PARTY_NOTICES.md`. **Free share — do not resell.**
