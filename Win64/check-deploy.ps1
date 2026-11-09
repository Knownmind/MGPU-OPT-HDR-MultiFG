param(
    [Alias('Dir')][string]$GameDir = '',
    [switch]$Quiet
)
# 2026-11-09 (test report): the old default pointed at the author's Jedi install,
# so a stranger running it with no arguments got a full PASS report about a game
# they do not own. Default to the directory the script sits in (README: run it
# in the game's exe folder); -GameDir can name another one. -Dir is kept as an
# alias for old shortcuts.
$Dir = if ($GameDir) { $GameDir } else { $PSScriptRoot }

# MGPU Bridge deployment preflight.
# Validates the things that silently kill the chain before anyone looks at picture quality:
#   1. the files are the ones we shipped (size is enough to catch the "old copy" mistake)
#   2. ReShade actually enables the depth tap technique (wrong name => TAP = OFF => stream arm HELD)
#   3. ReShade.ini keeps the depth copy and the effect search path
#   4. mgpu.ini has no duplicated keys and the HDR colour-space line is present
#   5. the last ReShade.log run reached the armed state
#   6. coexistence mode (dxgi.dll = OptiScaler): dxgi/ReShade64 split + [R189] A/N binding gate
#   7. NR model accepts both 310.9.16 (package default) and 310.8 (user-selected, 165,840,496)
# Exit code = number of FAILs.

$fail = 0
$warn = 0
$script:rows = [System.Collections.Generic.List[object]]::new()

function Add-Row([string]$state, [string]$item, [string]$detail) {
    [void]$script:rows.Add([pscustomobject]@{ State = $state; Item = $item; Detail = $detail })
    if ($state -eq 'FAIL') { $script:fail++ }
    if ($state -eq 'WARN') { $script:warn++ }
}

function Get-IniValue([string]$path, [string]$key) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $lines = [IO.File]::ReadAllLines($path)
    $hits = @()
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ($t.StartsWith(';') -or $t.StartsWith('#')) { continue }
        if ($t -match ('^' + [regex]::Escape($key) + '\s*=')) { $hits += ($t -replace '^[^=]*=\s*', '') }
    }
    if ($hits.Count -eq 0) { return $null }
    if ($hits.Count -gt 1) { Add-Row 'WARN' "duplicate:$key" ("{0} occurrences, last wins: {1}" -f $hits.Count, $hits[-1]) }
    $v = $hits[-1]
    $i = $v.IndexOf(';'); if ($i -ge 0) { $v = $v.Substring(0, $i) }
    $i = $v.IndexOf('#'); if ($i -ge 0) { $v = $v.Substring(0, $i) }
    return $v.Trim()
}

# 1. shipped files -------------------------------------------------------------
$expect = @{
    'nvngx.dll_mgpu_bridge.addon64'  = 1360896
    'mgpu.ini'                       = 0
    'reshade-shaders\Shaders\mgpu_depth_tap.fx' = 8227
    'mgpu\nvngx_dlssg.dll'           = 7506544
    'mgpu\vendor_dlss.dll'           = 35400248
    'mgpu\vendor_gpu.dll'            = 560200
}

# 1a. dxgi.dll / ReShade64.dll: core-only (ReShade as dxgi.dll) or OPT mode (OptiScaler as dxgi.dll)
#     2026-11-09 Phase 0: OPT mode used to FAIL on the dxgi.dll size check - that was a false alarm.
$dxgiPath = Join-Path $Dir 'dxgi.dll'
$reshadeSize = 5592064
$optScalerSize = 26681856
$optMode = $false
if (-not (Test-Path -LiteralPath $dxgiPath)) {
    Add-Row 'FAIL' 'file:dxgi.dll' 'missing'
} else {
    $dxgiLen = (Get-Item -LiteralPath $dxgiPath).Length
    if ($dxgiLen -eq $reshadeSize) {
        Add-Row 'PASS' 'file:dxgi.dll' '5,592,064 bytes (ReShade, core only)'
    } elseif ($dxgiLen -eq $optScalerSize) {
        $optMode = $true
        Add-Row 'SKIP' 'file:dxgi.dll' '26,681,856 bytes = OptiScaler (coexistence module); ReShade lives in ReShade64.dll -> run check-optional.ps1'
        $r64Path = Join-Path $Dir 'ReShade64.dll'
        if (-not (Test-Path -LiteralPath $r64Path)) {
            Add-Row 'FAIL' 'file:ReShade64.dll' 'missing in OPT mode'
        } else {
            $r64Len = (Get-Item -LiteralPath $r64Path).Length
            if ($r64Len -eq $reshadeSize) { Add-Row 'PASS' 'file:ReShade64.dll' '5,592,064 bytes (ReShade hosted by OPT)' }
            else { Add-Row 'FAIL' 'file:ReShade64.dll' ("size {0:N0}, expected 5,592,064" -f $r64Len) }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Dir 'OptiScaler.ini'))) { Add-Row 'WARN' 'file:OptiScaler.ini' 'missing in OPT mode' }
    } else {
        Add-Row 'FAIL' 'file:dxgi.dll' ("size {0:N0}, expected 5,592,064 (ReShade) or 26,681,856 (OptiScaler)" -f $dxgiLen)
    }
}

# 1b. NR model: 310.9.16 (package default) and 310.8 (user-selected since 2026-11-07) are both valid.
#     310.8 is kept on purpose - do not "fix" it by copying the package model over the user's file.
$nrPath = Join-Path $Dir 'mgpu\nvngx_dlssnr.dll'
if (-not (Test-Path -LiteralPath $nrPath)) {
    Add-Row 'FAIL' 'file:mgpu\nvngx_dlssnr.dll' 'missing'
} else {
    $nrLen = (Get-Item -LiteralPath $nrPath).Length
    if ($nrLen -eq 276162560) { Add-Row 'PASS' 'file:mgpu\nvngx_dlssnr.dll' '276,162,560 bytes (310.9.16, package default)' }
    elseif ($nrLen -eq 165840496) { Add-Row 'WARN' 'file:mgpu\nvngx_dlssnr.dll' '165,840,496 bytes = 310.8 (user-selected; package ships 310.9.16 - 2026-11-07 measured temporal micro-jitter on 310.8)' }
    else { Add-Row 'FAIL' 'file:mgpu\nvngx_dlssnr.dll' ("size {0:N0}, expected 276,162,560 (310.9.16) or 165,840,496 (310.8)" -f $nrLen) }
}

# 1a-bis. RenoDX is a Jedi-only OPTIONAL add-on. Version 11.9 shipped it in the
# required table by mistake: every non-Jedi game then reported a FAIL for a file
# it was never supposed to have (2026-11-09 PBZ report, defect 2). Check it only
# when it is actually present.
$renodx = Join-Path $Dir 'renodx-jedisurvivor.addon64'
if (Test-Path -LiteralPath $renodx) {
    $rlen = (Get-Item -LiteralPath $renodx).Length
    if ($rlen -eq 2061312) { Add-Row 'PASS' 'file:renodx-jedisurvivor.addon64' '2,061,312 bytes (optional RenoDX add-on present)' }
    else { Add-Row 'WARN' 'file:renodx-jedisurvivor.addon64' ("size {0:N0}, expected 2,061,312 when present" -f $rlen) }
}

foreach ($rel in $expect.Keys) {
    $p = Join-Path $Dir $rel
    if (-not (Test-Path -LiteralPath $p)) { Add-Row 'FAIL' "file:$rel" 'missing'; continue }
    $len = (Get-Item -LiteralPath $p).Length
    if ($expect[$rel] -gt 0 -and $len -ne $expect[$rel]) {
        Add-Row 'FAIL' "file:$rel" ("size {0:N0}, expected {1:N0} (old copy?)" -f $len, $expect[$rel])
    } else {
        Add-Row 'PASS' "file:$rel" ("{0:N0} bytes" -f $len)
    }
}

# 2. the depth tap technique must be enabled by its TECHNIQUE name ------------
$preset = Join-Path $Dir 'ReShadePreset.ini'
$tech = Get-IniValue $preset 'Techniques'
if (-not (Test-Path -LiteralPath $preset)) {
    Add-Row 'FAIL' 'preset:file' 'ReShadePreset.ini missing (the effect ships but is never enabled)'
} elseif (-not $tech) {
    Add-Row 'FAIL' 'preset:Techniques' 'empty: no effect enabled, bridge will wait for depth forever'
} elseif ($tech -match 'mgpu_depth_tap' -and $tech -notmatch 'MGPU_DepthTap') {
    Add-Row 'FAIL' 'preset:Techniques' ("'{0}' is the FILE name; ReShade wants the TECHNIQUE name MGPU_DepthTap" -f $tech)
} elseif ($tech -match 'MGPU_DepthTap') {
    Add-Row 'PASS' 'preset:Techniques' $tech.Trim()
} else {
    Add-Row 'WARN' 'preset:Techniques' ("'{0}' does not contain MGPU_DepthTap" -f $tech)
}

# 3. ReShade.ini ---------------------------------------------------------------
$reshade = Join-Path $Dir 'ReShade.ini'
$dcc = Get-IniValue $reshade 'DepthCopyBeforeClears'
if ($dcc -ne '1') { Add-Row 'WARN' 'ReShade:DepthCopyBeforeClears' ("'{0}' (expects 1 for the depth tap)" -f $dcc) }
else { Add-Row 'PASS' 'ReShade:DepthCopyBeforeClears' '1' }
$esp = Get-IniValue $reshade 'EffectSearchPaths'
if (-not $esp -or $esp -notmatch 'reshade-shaders') { Add-Row 'WARN' 'ReShade:EffectSearchPaths' ("'{0}'" -f $esp) }
else { Add-Row 'PASS' 'ReShade:EffectSearchPaths' $esp.Trim() }

# 4. mgpu.ini -----------------------------------------------------------------
$mgpu = Join-Path $Dir 'mgpu.ini'
$ccs = Get-IniValue $mgpu 'ChainColorSpace'
if ($null -eq $ccs) { Add-Row 'WARN' 'mgpu:ChainColorSpace' 'absent (HDR games need 12 = PQ)' }
elseif ($ccs.Trim() -eq '12') { Add-Row 'PASS' 'mgpu:ChainColorSpace' '12 (PQ/HDR10)' }
elseif ($ccs.Trim() -eq '0') { Add-Row 'PASS' 'mgpu:ChainColorSpace' '0 (SDR; package default for strangers - set 12 on an HDR display)' }
else { Add-Row 'WARN' 'mgpu:ChainColorSpace' ("{0} (valid: 0 = SDR, 12 = PQ/HDR10)" -f $ccs) }
$mvu = Get-IniValue $mgpu 'MVecUnits'
if ($mvu) { Add-Row 'FAIL' 'mgpu:MVecUnits' ("set to '{0}': writing this key is the known static-sparkle bug" -f $mvu) }
else { Add-Row 'PASS' 'mgpu:MVecUnits' 'absent/commented (correct)' }
$tun = Get-IniValue $mgpu 'Tuning'
$sty = Get-IniValue $mgpu 'Style'
Add-Row 'INFO' 'mgpu:Tuning/Style' ("Tuning={0} Style={1} (Tuning unset => Tone/Structure/Skin/Style are ALL ignored)" -f $tun, $sty)
$af = Get-IniValue $mgpu 'AntiFlicker'
$afp = Get-IniValue $mgpu 'AntiFlickerPresent'
$afv = Get-IniValue $mgpu 'AntiFlickerView'
Add-Row 'INFO' 'mgpu:AntiFlicker' ("AntiFlicker={0} Present={1} View={2} (batch 2 2026-11-06: 2+1+0 validated on Jedi; 0 = off)" -f $af, $afp, $afv)

# 5. last run -----------------------------------------------------------------
$log = Join-Path $Dir 'ReShade.log'
if (-not (Test-Path -LiteralPath $log)) {
    Add-Row 'WARN' 'log:file' 'ReShade.log missing (never launched with ReShade?)'
} else {
    $fs = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        $sr = New-Object IO.StreamReader($fs)
        $txt = $sr.ReadToEnd()
        $sr.Dispose()
    } finally { $fs.Dispose() }
    $fresh = (Get-Item -LiteralPath $log).LastWriteTime
    Add-Row 'INFO' 'log:lastwrite' $fresh.ToString('yyyy-MM-dd HH:mm:ss')
    if ($txt -match 'TAP = ON') { Add-Row 'PASS' 'log:TAP' 'TAP = ON' }
    elseif ($txt -match 'TAP = OFF') { Add-Row 'FAIL' 'log:TAP' 'TAP = OFF (technique not enabled)' }
    else { Add-Row 'WARN' 'log:TAP' 'no [R53] technique line found' }
    if ($txt -match 'TRANSPORTED AND BOUND') { Add-Row 'PASS' 'log:depth' 'depth transported and bound' }
    elseif ($txt -match 'stream arm HELD') { Add-Row 'FAIL' 'log:depth' 'stream arm HELD: depth never bound' }
    else { Add-Row 'WARN' 'log:depth' 'no depth transport line' }

    # [R189] is the hard A/N gate (15/16 §4.4): game luid must be AMD (0x1002), bridge luid NVIDIA (0x10DE).
    $m189 = [regex]::Matches($txt, '\[R189\] BINDING CONFIRMED AT ARM: the game renders on adapter luid=0x[0-9A-Fa-f]+-0x([0-9A-Fa-f]+) and the bridge is on luid=0x[0-9A-Fa-f]+-0x([0-9A-Fa-f]+) \("([^"]+)"\)')
    if ($m189.Count -gt 0) {
        $hit189 = $m189[$m189.Count - 1]
        $gl = $hit189.Groups[1].Value.ToUpper()
        $bl = $hit189.Groups[2].Value.ToUpper()
        Add-Row 'PASS' 'log:R189' ("game luid=0x{0} / bridge luid=0x{1} ({2})" -f $gl, $bl, $hit189.Groups[3].Value)
        $vend = @{}
        foreach ($mm in [regex]::Matches($txt, '\[T2\] adapter\[\d+\][^\r\n]*luid=0x[0-9A-Fa-f]+-0x([0-9A-Fa-f]+)[^\r\n]*vendor=0x([0-9A-Fa-f]{4})')) { $vend[$mm.Groups[1].Value.ToUpper()] = $mm.Groups[2].Value.ToUpper() }
        $gv = $vend[$gl]; $bv = $vend[$bl]
        if ($gv -eq '1002' -and $bv -eq '10DE') { Add-Row 'PASS' 'log:R189 vendors' 'game on AMD (0x1002), bridge on NVIDIA (0x10DE)' }
        elseif ($gv -and $bv) { Add-Row 'FAIL' 'log:R189 vendors' ("game vendor=0x{0} bridge vendor=0x{1} - highest principle broken, roll back" -f $gv, $bv) }
        else { Add-Row 'WARN' 'log:R189 vendors' 'cannot map luid -> vendor from [T2] adapter lines' }
    } else { Add-Row 'WARN' 'log:R189' 'no BINDING CONFIRMED AT ARM line (not armed yet?)' }
    $llPath = Join-Path $Dir 'mgpu\last_launch.ini'
    if (Test-Path -LiteralPath $llPath) {
        $lt = Get-Content -LiteralPath $llPath -Raw
        $sv = '?'; $gl2 = '?'; $bl2 = '?'
        if ($lt -match 'SelectionValid=(\d)') { $sv = $Matches[1] }
        if ($lt -match 'GameAdapterLuid=0x[0-9A-Fa-f]+-0x([0-9A-Fa-f]+)') { $gl2 = $Matches[1] }
        if ($lt -match 'BridgeAdapterLuid=0x[0-9A-Fa-f]+-0x([0-9A-Fa-f]+)') { $bl2 = $Matches[1] }
        Add-Row 'INFO' 'mgpu:last_launch' ("GameAdapterLuid=0x{0} BridgeAdapterLuid=0x{1} SelectionValid={2}" -f $gl2, $bl2, $sv)
        if ($sv -ne '1') { Add-Row 'WARN' 'mgpu:last_launch' 'SelectionValid != 1' }
    }
    if ($txt -match '\[R101\] CALIBRATOR[^\r\n]*creates=0') { Add-Row 'INFO' 'log:calibrator' 'creates=0 (normal when the game renders FSR2 or has upscaling off; only require creates>=1 when the game actually selects DLSS input)' }
    if ($txt -match '\[FG\] ARMED') { Add-Row 'PASS' 'log:fg' 'frame generation armed' } else { Add-Row 'WARN' 'log:fg' 'no [FG] ARMED' }
    if ($txt -match '\[NVOF\] armed') { Add-Row 'PASS' 'log:nvof' 'NVOF armed' } else { Add-Row 'WARN' 'log:nvof' 'no [NVOF] armed' }
    if ($txt -match 'REFUSING') { Add-Row 'FAIL' 'log:refusing' 'bridge refused (see log)' }
}

$fail = @($rows | Where-Object { $_.State -eq 'FAIL' }).Count
$warn = @($rows | Where-Object { $_.State -eq 'WARN' }).Count
if (-not $Quiet) {
    $rows | Format-Table -AutoSize -Wrap State, Item, Detail | Out-String -Width 200 | Write-Host
    Write-Host ("RESULT: {0} fail, {1} warn" -f $fail, $warn)
}
exit $fail
