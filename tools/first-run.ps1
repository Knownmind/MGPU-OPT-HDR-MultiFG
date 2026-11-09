# first-run.ps1 -- R41x13a deployment self-check + interactive ini writes.
#
# WHY THIS EXISTS: the shipped mgpu.ini is still a snapshot of one machine. This
# script checks the deployment (files/model/private core/A+N topology/game not
# running), PROBES the display HDR state via DXGI IDXGIOutput6::GetDesc1
# (ColorSpace 12 = RGB_FULL_G2084_NONE_P2020 when HDR is active; a bare human
# answer is not trusted - see the 2026-11-09 Jedi first-install test), asks the
# one question the bridge cannot answer itself (will the GAME output HDR or
# SDR?), warns when the answer contradicts the probe, and writes ONLY missing
# keys plus that answer. It does NOT guess the adapter: R41x10 already prefers
# the kernel's display-mapped row, and DXGI output counts are known unreliable.
#
# Dry-run by default. -Apply writes with a timestamped backup, UTF-8 WITHOUT BOM
# (the bridge reads raw bytes; a BOM would corrupt the first key).
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [switch]$Apply,
    [ValidateSet('ask', 'sdr', 'hdr', 'keep')][string]$Hdr = 'ask'
)

$ErrorActionPreference = 'Stop'

function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 2 }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "[ OK ] $m" -ForegroundColor Green }

# ---- display HDR probe (DXGI IDXGIOutput6::GetDesc1) ----
# Vtable slot order is taken from dxgi.h (F31 rule: count from the SDK header,
# not from memory):
#   IDXGIObject  = SetPrivateData, SetPrivateDataInterface, GetPrivateData, GetParent
#   IDXGIAdapter = + EnumOutputs, GetDesc, CheckInterfaceSupport
#   IDXGIOutput  = + GetDesc, GetDisplayModeList, FindClosestMatchingMode,
#                      WaitForVBlank, TakeOwnership, ReleaseOwnership,
#                      GetDisplaySurfaceData, GetFrameStatistics
#   IDXGIOutput5 = + DuplicateOutput      {eef60f31-a8c8-4c96-a6ea-6d67ab09b1b8}
#   IDXGIOutput6 = + GetDesc1             {0635687c-1c5a-4f43-bdd5-4b6b8a2b0c1e}
$script:HdrProbeCS = @'
using System;
using System.Runtime.InteropServices;

public static class HdrProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int L, T, R, B; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DXGI_OUTPUT_DESC1 {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        public int AttachedToDesktop;
        public int Rotation;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 2)] public RECT[] DesktopCoordinates;
        public int ColorSpace;              // DXGI_COLOR_SPACE_TYPE; 12 = RGB_FULL_G2084_NONE_P2020 (HDR active)
        public float RedPrimary0, RedPrimary1;
        public float GreenPrimary0, GreenPrimary1;
        public float BluePrimary0, BluePrimary1;
        public float WhitePoint0, WhitePoint1;
        public float MinLuminance, MaxLuminance, MaxFullFrameLuminance;
        public int BitsPerColor;
    }

    [ComImport, Guid("ae02eedb-c735-4509-aa0f-80d063a49e7b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutput {
        [PreserveSig] int GetDesc(IntPtr p);
        [PreserveSig] int GetDisplayModeList(int fmt, uint flags, ref uint num, IntPtr desc);
        [PreserveSig] int FindClosestMatchingMode(IntPtr a, IntPtr b, IntPtr c);
        [PreserveSig] int WaitForVBlank();
        [PreserveSig] int TakeOwnership(IntPtr d, bool ex);
        [PreserveSig] int ReleaseOwnership();
        [PreserveSig] int GetDisplaySurfaceData(IntPtr s);
        [PreserveSig] int GetFrameStatistics(IntPtr s);
    }
    [ComImport, Guid("eef60f31-a8c8-4c96-a6ea-6d67ab09b1b8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutput5 : IDXGIOutput {
        [PreserveSig] int DuplicateOutput(IntPtr device, out IntPtr dup);
    }
    [ComImport, Guid("0635687c-1c5a-4f43-bdd5-4b6b8a2b0c1e"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutput6 : IDXGIOutput5 {
        [PreserveSig] int GetDesc1(out DXGI_OUTPUT_DESC1 desc);
    }

    [ComImport, Guid("2411e7e1-12ac-4ccf-bd14-9798e8534dc0"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIAdapter {
        [PreserveSig] int SetPrivateData(IntPtr a, uint b, IntPtr c);
        [PreserveSig] int SetPrivateDataInterface(IntPtr a, IntPtr b);
        [PreserveSig] int GetPrivateData(IntPtr a, out uint size, IntPtr c);
        [PreserveSig] int GetParent(ref Guid iid, out IntPtr parent);
        [PreserveSig] int EnumOutputs(uint i, out IntPtr o);
        [PreserveSig] int GetDesc(IntPtr d);
        [PreserveSig] int CheckInterfaceSupport(ref Guid iid, out long umd);
    }

    [ComImport, Guid("770aae78-f26f-4dba-a829-253c83d1b387"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIFactory1 {
        [PreserveSig] int SetPrivateData(IntPtr a, uint b, IntPtr c);
        [PreserveSig] int SetPrivateDataInterface(IntPtr a, IntPtr b);
        [PreserveSig] int GetPrivateData(IntPtr a, out uint size, IntPtr c);
        [PreserveSig] int GetParent(ref Guid iid, out IntPtr parent);
        [PreserveSig] int EnumAdapters(uint i, out IntPtr a);
        [PreserveSig] int MakeWindowAssociation(IntPtr h, uint f);
        [PreserveSig] int GetWindowAssociation(out IntPtr h);
        [PreserveSig] int CreateSwapChain(IntPtr d, IntPtr dc, IntPtr desc, out IntPtr sc);
        [PreserveSig] int CreateSoftwareAdapter(IntPtr m, out IntPtr a);
        [PreserveSig] int EnumAdapters1(uint i, out IntPtr a);
        [PreserveSig] int IsCurrent();
    }

    [DllImport("dxgi.dll")]
    public static extern int CreateDXGIFactory1(ref Guid iid, out IntPtr factory);

    // Returns per-output tokens joined with ';': "HDR:DISPLAY1" / "SDR:DISPLAY1",
    // or "ERR:<reason>".
    public static string Probe() {
        Guid iid = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
        IntPtr fp;
        int hr = CreateDXGIFactory1(ref iid, out fp);
        if (hr != 0) return "ERR:CreateDXGIFactory1 hr=0x" + hr.ToString("X8");
        IDXGIFactory1 factory = null;
        try {
            factory = (IDXGIFactory1)Marshal.GetObjectForIUnknown(fp);
            var results = new System.Collections.Generic.List<string>();
            for (uint ai = 0; ; ai++) {
                IntPtr ap;
                hr = factory.EnumAdapters1(ai, out ap);
                if (hr != 0) break;
                IntPtr apLocal = ap;
                try {
                    IDXGIAdapter adapter = (IDXGIAdapter)Marshal.GetObjectForIUnknown(apLocal);
                    for (uint oi = 0; ; oi++) {
                        IntPtr op;
                        hr = adapter.EnumOutputs(oi, out op);
                        if (hr != 0) break;
                        IntPtr opLocal = op;
                        try {
                            IDXGIOutput6 o6 = (IDXGIOutput6)Marshal.GetObjectForIUnknown(opLocal);
                            DXGI_OUTPUT_DESC1 d;
                            if (o6.GetDesc1(out d) == 0 && d.DeviceName != null) {
                                results.Add((d.ColorSpace == 12 ? "HDR:" : "SDR:") + d.DeviceName);
                            }
                        } finally { Marshal.Release(opLocal); }
                    }
                } finally { Marshal.Release(apLocal); }
            }
            if (results.Count == 0) return "ERR:no output enumerated";
            return string.Join(";", results.ToArray());
        } finally {
            if (factory != null) Marshal.ReleaseComObject(factory);
        }
    }
}
'@
function Get-DisplayHdrState {
    try { Add-Type -TypeDefinition $script:HdrProbeCS -ErrorAction Stop | Out-Null }
    catch { } # already compiled in this session - fine
    try { $r = [HdrProbe]::Probe() }
    catch { return @{ Err = 'COM QI unavailable on this machine (hooked/blocked); question + game log remain available' } }
    if ($r -like 'ERR:*') { return @{ Err = $r.Substring(4) } }
    $hdrOn = $false; $name = ''
    foreach ($part in ($r -split ';')) {
        $kv = $part -split ':'
        if ($kv[0] -eq 'HDR') { $hdrOn = $true; $name = $kv[1] }
        elseif (-not $name) { $name = $kv[1] }
    }
    return @{ HdrOn = $hdrOn; Name = $name }
}

if (-not (Test-Path -LiteralPath $GameDir)) { Fail "GameDir not found: $GameDir" }
$root = (Resolve-Path -LiteralPath $GameDir).Path
Write-Host "== first-run: $root"

# ---- 1. files ----
foreach ($f in @('dxgi.dll', 'nvngx.dll_mgpu_bridge.addon64', 'ReShade.ini', 'mgpu.ini')) {
    $p = Join-Path $root $f
    if (-not (Test-Path -LiteralPath $p)) { Fail "missing $f" }
    Info $f
}
$mgpu = Join-Path $root 'mgpu'
if (-not (Test-Path -LiteralPath $mgpu)) { Fail 'missing mgpu\ folder' }
$model = Join-Path $mgpu 'nvngx_dlssnr.dll'
if (Test-Path -LiteralPath $model) { Info ('model: {0:N0} B' -f (Get-Item -LiteralPath $model).Length) }
else { Fail 'missing mgpu\nvngx_dlssnr.dll (the NR model)' }

$core = Join-Path $mgpu '_nvngx.dll'
if (Test-Path -LiteralPath $core) { Info ('private NGX core: {0:N0} B' -f (Get-Item -LiteralPath $core).Length) }
else {
    Warn 'missing mgpu\_nvngx.dll (private NGX core) - it is NOT shipped; generate it from this machine:'
    Write-Host ('       powershell -ExecutionPolicy Bypass -File "{0}" -GameDir "{1}" -Apply' -f `
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\setup-driver.ps1'), $root) -ForegroundColor Cyan
}

# ---- 2. game must be closed (ReShade.log is held open while it runs) ----
$log = Join-Path $root 'ReShade.log'
if (Test-Path -LiteralPath $log) {
    try {
        $fs = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $fs.Close()
        Info 'ReShade.log not locked (game appears closed)'
    }
    catch { Fail 'ReShade.log is locked - close the game first, then re-run' }
}
else { Info 'no ReShade.log yet (first launch not done; fine)' }

# ---- 3. topology: one NVIDIA + one non-NVIDIA ----
$vcs = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
$nv = @($vcs | Where-Object { $_.Name -match 'NVIDIA' })
$am = @($vcs | Where-Object { $_.Name -match 'AMD|Radeon|ATI' })
if ($nv.Count -ge 1 -and $am.Count -ge 1) { Info ('A+N detected: {0} / {1}' -f $am[0].Name, $nv[0].Name) }
elseif ($nv.Count -ge 1) { Warn ('NVIDIA found but no AMD/ATI adapter - A+N is the supported topology; bridge may still start') }
else { Fail 'no NVIDIA adapter found - this package needs at least one' }
Write-Host '     Note: the display cable must be on the NVIDIA card (A card is headless).'

# ---- 4. ini: only missing keys + the HDR answer ----
$iniPath = Join-Path $root 'mgpu.ini'
$text = [IO.File]::ReadAllText($iniPath)
$planned = New-Object System.Collections.Generic.List[string]
function Get-IniKey([string]$k) {
    $m = [regex]::Match($text, '(?m)^\s*' + [regex]::Escape($k) + '\s*=\s*(.*)$')
    if (-not $m.Success) { return $null }
    return (($m.Groups[1].Value -replace '\s*;.*$', '')).Trim()
}
function Add-Key([string]$line, [string]$why) {
    $planned.Add("add  $line    ($why)")
    if ($Apply) { $script:text = $script:text.TrimEnd() + "`r`n" + $line + "`r`n" }
}
function Set-Key([string]$k, [string]$v, [string]$why) {
    $planned.Add("set  $k=$v    ($why)")
    if ($Apply) {
        # keep the trailing "; comment" if the line has one (review 28 §3.8)
        $script:text = [regex]::Replace($script:text,
            '(?m)^(\s*)' + [regex]::Escape($k) + '\s*=\s*([^;\r\n]*)(;.*)?$',
            ('${1}' + $k + '=' + $v + '${3}'), 1)
    }
}

# Probe the display HDR state once (best effort; do not trust a bare human
# answer alone: 2026-11-09 Jedi first-install test - the answerer said HDR, the
# game log later showed [R41x7] display HDR=OFF (SDR)).
$disp = Get-DisplayHdrState
if ($disp.Err) {
    Warn ('display HDR auto-detect failed ({0}) - falling back to the question + game log' -f $disp.Err)
    $dispStr = 'unknown'
}
else {
    $dispStr = 'ON (HDR10/PQ)'; if (-not $disp.HdrOn) { $dispStr = 'OFF (SDR)' }
    Info ('display HDR auto-detect: {0} on {1}' -f $dispStr, $disp.Name)
}

# Cross-check with the game's own ground truth: the bridge writes the display
# HDR state to ReShade.log at arm time ([R41x7] game swap chain: ... display HDR=...).
# Known environment quirk (2026-11-09, author rig): COM QI on DXGI output objects
# returns E_NOINTERFACE here (suspected IDD/overlay hooking), so the auto-detect
# can be unavailable exactly where it is needed most - the log never lies.
$logHd = $null
if (Test-Path -LiteralPath $log) {
    $m41x7 = Select-String -LiteralPath $log -Pattern '\[R41x7\].*display HDR=(ON|OFF)' | Select-Object -Last 1
    if ($m41x7) { $logHd = ($m41x7.Matches[0].Groups[1].Value -eq 'ON') }
}
if ($null -ne $logHd) {
    $logStr = 'ON (HDR10/PQ)'; if (-not $logHd) { $logStr = 'OFF (SDR)' }
    Info ('game log ground truth: display HDR={0} ([R41x7], last arm)' -f $logStr)
}

$target = $null
switch ($Hdr) {
    'hdr' { $target = 12 }
    'sdr' { $target = 0 }
    'ask' {
        Write-Host '游戏按哪种模式部署？(决定 mgpu.ini 的 ChainColorSpace: 12=HDR10/PQ, 0=SDR)' -ForegroundColor Cyan
        Write-Host ('  检测到显示器 HDR 状态: {0}' -f $dispStr)
        Write-Host '  HDR 部署的前提: Windows 设置→系统→显示→HDR 已开，且显示器自身 HDR 模式已开。'
        $ans = Read-Host '  请按游戏实际输出模式选择 [H=HDR / S=SDR, 默认 S]'
        if ($ans -match '^(h|hdr|y|yes|是)$') { $target = 12 } else { $target = 0 }
    }
    'keep' { $target = $null }
}
if ($target -eq 12) {
    $blockers = @()
    if (-not $disp.Err -and -not $disp.HdrOn) { $blockers += 'HDR 自动检测=OFF' }
    if ($null -ne $logHd -and -not $logHd)    { $blockers += '游戏日志 [R41x7] 上一次 arm 时 display HDR=OFF' }
    if ($blockers.Count) {
        Warn ('选择了 HDR(12)，但 {0} —— PQ 码值被按 SDR 解释会整幅发灰。' -f ($blockers -join '，'))
        Warn '  先打开 Windows 设置→系统→显示→HDR（及显示器自身 HDR 模式），再重启游戏；若游戏确实跑 SDR，请改用 -Hdr sdr 或重跑选 S。'
    }
    elseif ($disp.Err -and $null -eq $logHd) {
        Write-Host '     提示: HDR(12) 的前提是 Windows/显示器 HDR 已开；若两者都没开，画面会整幅发灰。' -ForegroundColor DarkCyan
    }
}
if ($target -eq 0 -and ((-not $disp.Err -and $disp.HdrOn) -or ($null -ne $logHd -and $logHd))) {
    Warn '选择了 SDR(0)，但检测到 HDR=ON —— 若游戏走 HDR10，码值被按 gamma 2.2 解释，对比度会塌掉；确认游戏确实 SDR 再继续。'
}
if ($null -ne $target) {
    $cur = Get-IniKey 'ChainColorSpace'
    if ($null -eq $cur) { Add-Key "ChainColorSpace=$target" 'HDR answer; SDR is the safe default' }
    elseif ($cur -ne "$target") { Set-Key 'ChainColorSpace' $target "was $cur" }
    else { Info "ChainColorSpace already $target" }
}
else { Info 'ChainColorSpace left as-is (-Hdr keep)' }

if ($null -eq (Get-IniKey 'DX11')) { Add-Key 'DX11=1' 'D3D11 path for D3D11 titles' }
if ($null -eq (Get-IniKey 'Frames')) { Add-Key 'Frames=0' 'unbounded run' }
if ($null -eq (Get-IniKey 'MVec')) { Add-Key 'MVec=0' 'control arm; write 3 if the game provides real motion vectors' }

if ($planned.Count -eq 0) { Info 'ini already contains all required keys' }
else { foreach ($p in $planned) { Write-Host "[PLAN] $p" -ForegroundColor Cyan } }

if (-not $Apply) {
    Write-Host 'dry-run: nothing written. Re-run with -Apply to write (backup is made first).' -ForegroundColor Cyan
    Write-Host 'Then launch the game and look for: [MGPU][R41x13] adapter spoof, [MGPU][H1], [P4.1] Init_Ext Success, [V53] ROOTED.'
    exit 0
}
if ($planned.Count -gt 0) {
    $bak = $iniPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-first-run'
    Copy-Item -LiteralPath $iniPath -Destination $bak
    [IO.File]::WriteAllText($iniPath, $text, (New-Object System.Text.UTF8Encoding($false)))
    Info "ini written; backup: $bak"
}
Write-Host 'Done. Launch the game and verify: [MGPU][R41x13] adapter spoof / [MGPU][H1] / [P4.1] Init_Ext Success / [V53] ROOTED.' -ForegroundColor Cyan
