# MGPU (NVOF Adaptive Multi-Frame + OPT Super-Resolution Injection + HDR) 11.9 · Lite Release

> **Author**: 电子羊羊尾 (Heybox ID: 38096711)
> **Repository**: https://github.com/Knownmind/MGPU-OPT-HDR-MutiFG
> **Free share**: This package is shared for **free**. Reselling or paid distribution is **prohibited**. If you paid for it on a third-party platform, ask for a refund and report the seller.
> **Kernel**: MGPU Bridge 0.4.0 custom build **R41x13j** (`Win64/nvngx.dll_mgpu_bridge.addon64` = 1,360,896 B / `sha256:13e01caf…`)
> **This is the "lite" release**: it does **NOT** bundle NVIDIA/AMD runtime binaries (DLSS-NR model, DLSS-G, `_nvngx.dll`, FSR runtimes). You must supply them yourself — see [`docs/RUNTIME-FILES.md`](docs/RUNTIME-FILES.md). The full package is not distributed publicly.

---

## 1. What it is

**The AMD card keeps rendering the game. Finished frames are sent to the NVIDIA card, which runs DLSS-NR neural rendering, then NVOF hardware optical flow feeds DLSS-G frame generation, and finally the NVIDIA card presents HDR10 directly.**

The package is a ReShade 6.8 add-on (MGPU Bridge custom kernel) plus deployment scripts and Chinese/English docs. No separate upscaler/frame-gen tool is needed: NR, frame generation, presentation, screenshots and tuning all live in one add-on.

**Features**

| Feature | Details |
|---|---|
| NR (DLSS-NR) | Neural rendering on the NVIDIA card; adjust strength and switch NR model DLLs in the panel (restart to apply) |
| NVOF + DLSS-G frame generation | NVOF hardware flow feeds DLSS-G; 2x–6x dynamic multiplier; toggle with `Ctrl+Alt+F12` |
| HDR10 output | The bridge's swap chain declares PQ/BT.2020; uses `ChainColorSpace=0` for SDR games |
| Panel | `Home` opens the `MGPU Bridge` page: live fps/latency, NR/FG switches, NR model, screenshot settings, hotkey rebinding, OPT status row |
| 9 rebindable hotkeys | All rebindable in the panel; conflicts/claimed keys are marked |
| Paired screenshots | `Ctrl+Alt+S` writes the same frame before/after NR, always SDR, timestamped names |
| Auto adapter selection / auto spoof | Duplicate adapter rows prefer the kernel display-mapped row; adapter spoof judged by API (off for D3D11, on for D3D12) |
| Self-check tools | `check-deploy.ps1`, `selfcheck.ps1`, `choose-adapter.ps1`, `setup-driver.ps1`, `first-run.ps1` |
| D3D11 experimental path | `DX11=1`: shared texture + fence from the game's D3D11 context (no real motion vectors / Reflex) |

---

## 2. Repository / release contents

```
.
├── README.md / README.en.md   ← Chinese / English docs
├── LICENSE                    ← MIT (author: 电子羊羊尾)
├── THIRD_PARTY_NOTICES.md     ← upstream/third-party licenses; no NVIDIA/AMD runtime redistribution
├── RELEASE_NOTES.md           ← release notes + checksums
├── PUBLISH.md                 ← maintainer publishing steps
├── SHA256SUMS.txt             ← checksums of repository files
├── Win64/                     ← copy into the game's exe directory (lite: no runtime DLLs)
├── tools/                     ← first-run / setup-driver / choose-adapter / selfcheck
├── docs/                      ← deployment, runtime files, project notes, screenshots/hotkeys, KCD1 D3D11, OPT on A+N
└── _release-assets/           ← release zip + .sha256 (gitignored)
```

> **OPT (OptiScaler/FSR4) is not part of this lite release** (third-party binaries, licensing/size). Use the full package, or install OptiScaler yourself — for A+N hybrid machines see [`docs/opt-a-n-en.md`](docs/opt-a-n-en.md) (one-line `Dxgi=true` fix).

---

## 3. Requirements

| Item | Requirement |
|---|---|
| OS | Windows 10/11 64-bit |
| GPUs | **AMD renders + NVIDIA runs NR/FG** (validated: RX 9070 XT + RTX 5070 Ti); **NR needs RTX 50 series** (Blackwell); other RTX models untested |
| Display | Monitor wired to the **NVIDIA** card (AMD is headless); HDR10 monitor for HDR |
| Runtime files | See `docs/RUNTIME-FILES.md`: NR model / DLSS-G / vendor libs / `_nvngx.dll` (**not** in this repo) |
| Tools | Windows PowerShell 5.1 (built in); game must be closed for writes |

---

## 4. Install (5 steps)

1. **Back up** same-named files in the game dir (`dxgi.dll`, `nvngx*.dll`, `ReShade*.ini`, `mgpu.ini`).
2. Copy everything in `Win64/` into the **game's exe directory**.
3. **Add the runtime files** (the essential lite-release step; see `docs/RUNTIME-FILES.md`):
   - `mgpu\_nvngx.dll`: run `powershell -ExecutionPolicy Bypass -File tools\setup-driver.ps1 -GameDir "<game exe dir>" -Apply` (copies from the local DriverStore);
   - `mgpu\nvngx_dlssnr.dll` (NR model 310.9.16), `mgpu\nvngx_dlssg.dll`, `mgpu\vendor_dlss.dll`, `mgpu\vendor_gpu.dll`: **supply them yourself** (NVIDIA runtimes) into `mgpu\`.
4. **First-run check**: run `tools\first-run.ps1 -GameDir "<game exe dir>"` (dry-run first, then `-Apply`). HDR users must enable Windows HDR + monitor HDR first; non-interactive: `-Hdr hdr|sdr|keep`.
5. Launch the game; the bridge arms itself; verify with §6.

---

## 5. Tools

| Script | Purpose |
|---|---|
| `first-run.ps1` | Deployment self-check + write missing ini keys (HDR precondition check, cross-check with `ReShade.log`); `-Apply` writes with backup |
| `setup-driver.ps1` | Inspect driver / DriverStore `_nvngx.dll` / model variants; `-Apply` copies the private core |
| `choose-adapter.ps1` | Read `[T2]`/`[R265]`/`[R270]` and recommend which NVIDIA LUID to pin; `-Apply` writes `Display=`/`BridgeLuid` |
| `selfcheck.ps1` | Read-only environment self-check |
| `Win64\check-deploy.ps1` | Read-only post-deploy check (exit code = number of FAILs) |

Always use `-ExecutionPolicy Bypass`; quote paths; scripts that write require the game to be closed and make backups.

---

## 6. Acceptance (check `ReShade.log`)

| Item | Expect |
|---|---|
| Version | `[R141] MGPU Bridge 0.4.0 \| built …`, `[R41x13b] adapt: …` |
| NVIDIA adapter selected | `[T2] SELECTED adapter… desc="NVIDIA…"` |
| Color space | `[H1] bridge chain colour space: ChainColorSpace=0/12 …` |
| NGX core | `[R240] NGX core: loaded from the private mgpu copy` |
| NR init | `[P4.1] using the PRIVATE NR snippet … Init_Ext: result=0x00000001 (Success)` |
| Present | `[V53] first neural frame: the bridge visual is now ROOTED` |
| Topology | `[R189] BINDING CONFIRMED AT ARM: …(AMD) … …(NVIDIA)` |
| Frame generation | `[FG] ARMED …`, `[FG] HEARTBEAT … failed=0 dropped=0` |

---

## 7. Defaults (safe defaults for unknown machines)

| Key | Default | Notes |
|---|---|---|
| `MVec` | 0 | Control arm; set **`MVec=3`** for games with real motion vectors (PBZ/Jedi), restart to apply |
| `ChainColorSpace` | 0 (SDR) | HDR10 desktop/game: set 12 (or answer HDR in `first-run.ps1`) |
| `AdapterSpoof` | absent (API-judged) | ON for D3D12 / OFF for D3D11; explicit 1/0 overrides |
| `DX11` | 1 | D3D11 path switch; D3D12 titles never trigger it |
| `FGCount` | 1 | 2x; 0 = off, 2 = 3x, restart to apply |
| `AdapterExcludeLuid` / `NGXLog` | commented | machine-specific/diagnostic, leave off |

---

## 8. Hotkeys (rebindable in the panel)

| Action | Default |
|---|---|
| Manual arm (transit probe) | `Ctrl+Alt+F10` |
| Peek (hide neural frame) | `Ctrl+Alt+F6` |
| View: output/input/split | `Ctrl+Alt+F7` |
| Emergency overlay close | `Ctrl+Alt+Home` |
| Paired screenshot | `Ctrl+Alt+S` |
| Frame generation on/off | `Ctrl+Alt+F12` |
| NVOF direction flip | `Ctrl+Alt+F7` (same default as View; rebind) |
| Look A/B | `Ctrl+Alt+L` |
| Screen OSD | `Ctrl+Alt+F5` |

---

## 9. License & credits

- Our custom build, scripts and docs: **MIT** (author 电子羊羊尾, Heybox ID 38096711) — see `LICENSE`;
- Upstream MGPU Bridge / Neural-coprocessor: MIT (Marcelo Guibout);
- ReShade 6.8: BSD-3 (Copyright (c) 2014 Patrick Mours);
- **NVIDIA DLSS runtimes and AMD FSR runtimes are NOT redistributed** with this repository/release; users must supply their own copies — see `docs/RUNTIME-FILES.md`;
- No game files are included.

**This package is free to share. Do not resell or charge for it.**
