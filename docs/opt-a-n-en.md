# OptiScaler on an A+N hybrid: making the DLSS slot usable

A short field note for machines where an **AMD card renders** but an **NVIDIA card is also
present** (hybrid laptop, A+N desktop, or an NVIDIA card kept for compute). On these machines
OptiScaler's DXGI spoofing silently turns itself off, and the in-game DLSS option never leaves
the greyed-out state. The fix is one line.

This is not a general OptiScaler guide — the official
[Manual Installation](https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation) covers
everything else.

## Tested on

|               |                                                       |
| ------------- | ----------------------------------------------------- |
| Rendering GPU | AMD Radeon RX 9070 XT (RDNA4), driver 32.0.32015.7029 |
| Other GPU     | NVIDIA RTX 5070 Ti, driver 32.0.16.2114               |
| OS            | Windows 11 26300                                      |
| OptiScaler    | v0.9.4-final (7534ad0)                                |
| Game          | STAR WARS Jedi: Survivor (UE4, D3D12)                 |
| Result        | FSR 4.1.2 via the DLSS input path (`fsr31` backend)   |

**One title only.** Treat this as a data point, not a compatibility claim.

## Requirements

- The game has a DLSS 2+/FSR 2.x/XeSS input and runs on D3D12 (DX11 works through DX12 interop,
  at a cost).
- No kernel-level anti-cheat. Single-player titles are generally fine.
- The game does **not** static-link FSR2. If it does (Jedi: Survivor is one), the FSR2 input path
  is dead — the DLSS slot is the only route, which is exactly why spoofing matters here.

## Steps

1. **Get the official build.** <https://github.com/optiscaler/OptiScaler/releases/tag/v0.9.4>
   — asset `Optiscaler_0.9.4-final.20260718._MM.7z`, 55,016,448 bytes,
   sha256 `575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad`.
   There is no official website or manager app; anything charging money is not them.

2. **Extract flat next to the game exe.** For UE4/UE5 that is
   `<Game>\Binaries\Win64\`, not the game root. `[Libraries] OptiDllPath` defaults to `.\`,
   so subfolders break the dependency lookup.

3. **Rename `OptiScaler.dll` → `dxgi.dll`.** If that name is taken by another mod, try
   `winmm.dll` (preferred for EA App titles), then `version.dll`. Only one copy of OptiScaler
   per game. Do not rename `OptiScaler.ini`.

4. **Set one key.** In `OptiScaler.ini`:

   ```ini
   [Spoofing]
   Dxgi=true
   ```

   Leave everything else at default. `Dx12Upscaler=auto` already picks FSR4 on RDNA4.

5. **Launch, open the graphics menu, select DLSS**, then press `Insert` to confirm the backend
   shows `FSR3.X/4` or `FSR4`. A restart is often required before the selection takes effect.

## Why step 4 is mandatory here

`OptiScaler/dllmain.cpp`:

```cpp
State::Instance().isRunningOnNvidia = isNvidia();      // is an NVIDIA GPU visible at all?

if (State::Instance().isRunningOnNvidia)
{
    if (!Config::Instance()->DxgiSpoofing.has_value()) // "auto" -> no explicit value
    {
        Config::Instance()->DxgiSpoofing.set_volatile_value(false);
        // logs: [I] Running on Nvidia / [I] Disabling DxgiSpoofing
    }
}
```

`has_value()` is false when the ini says `auto`, so the spoofing gets cancelled based on *GPU
presence*, not on *which adapter renders the game*. On a hybrid machine those differ: the game
builds its D3D12 device on the AMD card, sees an AMD vendor id, and greys out DLSS.

Writing `true` makes `has_value()` true, and the cancellation branch is skipped.

The cancellation line is `[I]`, not `[W]`, and it will not appear in the default log level —
set `[Log] LogLevel=0` if you need to see it. `[D] isNvidia Detected: true` is the line that
precedes it.

## Verify (all three)

```
[I] DxgiSpoofing::AttachToAdapter Attach to GetDesc
[I] FeatureProvider_Dx12::ChangeFeature init successful for fsr31, upscaler changed
[T] SkipSpoofing DxgiSpoofing: true, skipSpoofing: true, skipping spoofing
```

If `[I] Disabling DxgiSpoofing` appears instead, DLSS will stay grey.

Watermark check: `[FSR] Fsr4EnableWatermark=true`, restart, and look for `FSR4` (RDNA4 FP8) or
`FSR4-i8` (RDNA3 INT8). `FSR3` means it fell back.

## Known issues

- **Spoofing costs performance.** The OptiScaler wiki lists roughly 15% for this title. Accept or
  use a non-spoofing unlock route instead.
- **`fsr31` is not FSR 3.1.** It is OptiScaler's internal name for the FSR 3.x/4 family; which
  model actually runs is decided by `Fsr4Update` / `Fsr4Preset`.
- **The "FSR 4 GPU check" reading is unconfirmed.** `hkD3DKMTQueryAdapterInfo ... Likely FSR 4
  GPU Check` combined with `SkipSpoofing` suggests OptiScaler deliberately presents the real AMD
  adapter to the driver when creating the FSR4 context. The source itself says `Likely`, so treat
  the causal link as unverified.
- **`Dxgi=true` is topology-specific.** On a pure AMD machine `auto` already resolves to spoofing
  on; the explicit value is only needed when an NVIDIA GPU is also visible. It is harmless, but
  not required.
- **If you also run a second-adapter bridge** (e.g. one card renders, another runs NGX): when
  OptiScaler loads as `dxgi.dll` it pulls in the DriverStore copy of `_nvngx.dll` first, and a
  bridge that resolves that module by bare name will get the uninitialized one — `Init_Ext`
  returns `0xBAD00001`. The bridge needs to load its own `<addon>\mgpu\_nvngx.dll` instead.
  Not covered further here.

## Rollback

Delete from the exe directory: the renamed DLL (`dxgi.dll`/`winmm.dll`/...), `OptiScaler.ini`,
`OptiScaler.log`, `amd_fidelityfx_*.dll`, `dlssg_to_fsr3_amd_is_better.dll`, `fakenvapi.dll`,
`fakenvapi.ini`, `libxess*.dll`, `libxell.dll`, `D3D12_Optiscaler\`, `Licenses\`. The game itself
is untouched.

## Provenance

No binaries are redistributed here. Everything comes from the official v0.9.4 release above;
verify with the sha256. OptiScaler is GPL-3.0 — if you repackage it, that licence travels with
it. Do not redistribute NVIDIA's `_nvngx.dll`; take it from your own driver install.
