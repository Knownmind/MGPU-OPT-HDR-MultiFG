# choose-adapter.ps1 - 选卡检查/钉卡（11.9 部署包附带）
#
# 用途：别人的显卡型号/数量、显示接线和本机不同时，桥的自动选卡可能落在"同一张卡的
#      重复枚举行"上（LUID 不同），导致 NGX Init_Ext 返回 FAIL_FeatureNotSupported、
#      NR/FG 全不启动。本脚本读取游戏目录里的 ReShade.log（桥自己的选卡日志），
#      列出所有适配器/显示映射，给出建议的 BridgeLuid，并可一键写入 mgpu.ini。
#
# 用法（先启动过一次游戏，生成 ReShade.log；画面不动也没关系）：
#   powershell -ExecutionPolicy Bypass -File choose-adapter.ps1 -GameDir "<游戏exe目录>"
#   powershell -ExecutionPolicy Bypass -File choose-adapter.ps1 -GameDir "<游戏exe目录>" -Apply
#
# 注意：LUID 每次重启可能重排；日志里若出现 [R270] matches no enumerated adapter，
#      重跑本脚本（或按新的 [T2] 行手改 BridgeLuid）。

param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

function Write-Info($m)  { Write-Host "[选卡] $m" }
function Write-Warn2($m) { Write-Host "[警告] $m" -ForegroundColor Yellow }
function Write-Err2($m)  { Write-Host "[失败] $m" -ForegroundColor Red }

function Normalize-Hex($v) {
    $u = ([string]$v).ToUpperInvariant()
    if ($u.StartsWith('0X')) { return '0x' + $u.Substring(2) }
    return $u
}
function VendorName($v) {
    $n = Normalize-Hex $v
    switch ($n) {
        '0x10DE' { return 'NVIDIA' }
        '0x1002' { return 'AMD' }
        '0x8086' { return 'Intel' }
        '0x1414' { return 'Microsoft(软件)' }
        default  { return "其他($n)" }
    }
}

$log = Join-Path $GameDir 'ReShade.log'
$ini = Join-Path $GameDir 'mgpu.ini'
if (-not (Test-Path $log)) {
    Write-Err2 "找不到 $log"
    Write-Info "请先启动一次游戏（有桥加载即可），再运行本脚本。"
    exit 2
}
if (-not (Test-Path $ini)) {
    Write-Err2 "找不到 $ini"
    Write-Info "请先把 11.9 部署包的 Win64\ 内容复制到游戏目录。"
    exit 2
}

$lines = Get-Content -LiteralPath $log -Encoding UTF8

# ---- 1. 适配器表：日志里最后一批 [T2] adapter[i] 行 ----
$adapter = @{}
$rxA = [regex]'\[T2\] adapter\[(?<i>\d+)\] driver=(?<drv>[0-9.]+) luid=0x(?<hi>[0-9A-Fa-f]{8})-0x(?<lo>[0-9A-Fa-f]{8}) flags=0x(?<fl>[0-9A-Fa-f]+) vendor=0x(?<vn>[0-9A-Fa-f]+) device=0x(?<dv>[0-9A-Fa-f]+) dedicated_vram=(?<vram>\d+)MB outputs=(?<out>\d+) desc="(?<name>[^"]+)"'
foreach ($ln in $lines) {
    $m = $rxA.Match($ln)
    if ($m.Success) {
        $i = [int]$m.Groups['i'].Value
        $adapter[$i] = [pscustomobject]@{
            Index   = $i
            Luid    = ('0x{0}-0x{1}' -f $m.Groups['hi'].Value, $m.Groups['lo'].Value)
            LuidLo  = ('0x{0}' -f $m.Groups['lo'].Value)
            Vendor  = Normalize-Hex ('0x' + $m.Groups['vn'].Value)
            Device  = Normalize-Hex ('0x' + $m.Groups['dv'].Value)
            Vram    = [int]$m.Groups['vram'].Value
            Outputs = [int]$m.Groups['out'].Value
            Flags   = $m.Groups['fl'].Value
            Name    = $m.Groups['name'].Value
        }
    }
}
if ($adapter.Count -eq 0) {
    Write-Err2 "日志里没有 [T2] adapter[..] 行 —— 桥可能没有加载/启动。"
    Write-Info "确认 dxgi.dll 和 nvngx.dll_mgpu_bridge.addon64 都在游戏目录，且 ReShade.log 是这次启动生成的。"
    exit 3
}

Write-Host ''
Write-Host '==== 适配器（桥看到的）====' -ForegroundColor Cyan
$adapter.Values | Sort-Object Index | ForEach-Object {
    '{0,2}  {1,-22} {2,-15} dev={3,-6} VRAM={4,6} MB  outputs={5}  {6}' -f `
        $_.Index, $_.Luid, (VendorName $_.Vendor), $_.Device, $_.Vram, $_.Outputs, $_.Name
}

# ---- 2. 显示 -> 内核适配器映射（[R265]）----
$displayLuids = @{}     # luid -> GDI 名（如 \\.\\DISPLAY1）
$rxD = [regex]'DISPLAY(?<n>\d+).*?kernel adapter for .*?: (?<luid>0x[0-9A-Fa-f]{8}-0x[0-9A-Fa-f]{8})'
$rxGdi = [regex]'on (?<gdi>\\\\.\\DISPLAY\d+)'
foreach ($ln in $lines) {
    $m = $rxD.Match($ln)
    if ($m.Success) {
        $gdi = $null
        $mg = $rxGdi.Match($ln)
        if ($mg.Success) { $gdi = $mg.Groups['gdi'].Value }
        $displayLuids[$m.Groups['luid'].Value] = [pscustomobject]@{ Num = $m.Groups['n'].Value; Gdi = $gdi }
    }
}
Write-Host ''
Write-Host '==== 内核显示映射（[R265]）====' -ForegroundColor Cyan
if ($displayLuids.Count -eq 0) {
    Write-Warn2 '日志里没有 [R265] kernel adapter 行（可能显示在虚拟/远程桌面上）。'
} else {
    $displayLuids.GetEnumerator() | ForEach-Object { '  显示器 DISPLAY{0} -> {1}' -f $_.Value.Num, $_.Key }
}

# ---- 3. 候选与建议 ----
$nvidia = @($adapter.Values | Where-Object { $_.Vendor -eq '0x10DE' })

Write-Host ''
if ($nvidia.Count -eq 0) {
    Write-Err2 '没有 NVIDIA 适配器：NR/FG 需要一张 N 卡（建议 RTX 50 系）。'
    exit 4
}

$recommend = $null
$reason = ''
foreach ($a in $nvidia) {
    if ($displayLuids.ContainsKey($a.Luid)) { $recommend = $a; $reason = '内核显示映射指向它（最可靠）'; break }
}
if ($null -eq $recommend) {
    $withOut = @($nvidia | Where-Object { $_.Outputs -gt 0 })
    if ($withOut.Count -eq 1) { $recommend = $withOut[0]; $reason = '它是唯一带显示输出的 N 卡' }
    elseif ($nvidia.Count -eq 1) { $recommend = $nvidia[0]; $reason = '它是唯一一张 N 卡' }
}

$dup = $nvidia | Group-Object { "$($_.Vendor)/$($_.Device)/$($_.Vram)" } | Where-Object { $_.Count -gt 1 }
if ($dup) { Write-Warn2 '同一张 N 卡被枚举成多行（LUID 不同）——这是选错卡的高发场景。' }

$blackwell = @($nvidia | Where-Object { $_.Name -match 'RTX\s*50\d0' })
if ($blackwell.Count -eq 0) {
    Write-Warn2 '没有识别到 RTX 50 系（Blackwell）：DLSS-NR 神经渲染需要 50 系；只有 40 系时最多能用插帧（DLSS-G）。'
}

Write-Host ''
Write-Host '==== 建议 ====' -ForegroundColor Cyan
if ($null -eq $recommend) {
    Write-Warn2 '无法自动判断，请从上面的 NVIDIA 行里人工选一个"带显示输出"的 LUID：'
    $nvidia | ForEach-Object { '  BridgeLuid={0}   # {1} (outputs={2})' -f $_.LuidLo, $_.Name, $_.Outputs }
    exit 5
}
Write-Info ('桥应钉在: {0}   (LUID {1})' -f $recommend.Name, $recommend.Luid)
Write-Info "理由: $reason"
$suggest = 'BridgeLuid=' + $recommend.LuidLo
$suggest2 = $null
if ($displayLuids.ContainsKey($recommend.Luid)) {
    $g = $displayLuids[$recommend.Luid].Gdi
    if ($g) { $suggest2 = 'Display=' + $g }
}
Write-Host ''
Write-Host '  建议写入 mgpu.ini 的行（二选一）：' -ForegroundColor Green
if ($suggest2) { Write-Host ('    ' + $suggest2 + '   ← 推荐（显示名稳定，重启不失效）') -ForegroundColor Green }
Write-Host ('    ' + $suggest) -ForegroundColor Green
$others = @($nvidia | Where-Object { $_.Luid -ne $recommend.Luid })
if ($others.Count -gt 0) {
    Write-Host '  （若 [R270] 仍选不到/仍失败，可改用排除法：）'
    $others | ForEach-Object { Write-Host ('    AdapterExcludeLuid=' + $_.Luid) }
}
Write-Info '提示：若日志里 [R41x7] game swap chain: display HDR=unknown，说明取不到显示器 HDR 状态；截图会自动退回 SDR 直通，属正常。'

# ---- 4. 写入 ----
if (-not $Apply) {
    Write-Host ''
    Write-Info '只检查不修改。要写进 mgpu.ini，加 -Apply 重跑。'
    exit 0
}

$raw = Get-Content -LiteralPath $ini -Raw
$backup = $ini + '.bak-choose-adapter-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item -LiteralPath $ini -Destination $backup -Force
Write-Info "已备份 mgpu.ini -> $backup"

# 首选 Display=\\.\\DISPLAYn（显示名稳定，重启后 LUID 重排也不受影响）；
# 拿不到 GDI 名时才退回 BridgeLuid。
$gdi = $null
if ($displayLuids.ContainsKey($recommend.Luid)) { $gdi = $displayLuids[$recommend.Luid].Gdi }
if ($gdi) {
    $newLine = 'Display=' + $gdi
    if ($raw -match '(?m)^Display=.*$') {
        $raw = [regex]::Replace($raw, '(?m)^Display=.*$', $newLine, 1)
    } else {
        if (-not $raw.EndsWith("`n")) { $raw += "`r`n" }
        $raw += "; choose-adapter.ps1 选了显示器 $gdi`r`n$newLine`r`n"
    }
    # 旧的 BridgeLuid 钉值会让 LUID 重排后失效，注释掉（保留原文便于恢复）
    $raw = [regex]::Replace($raw, '(?m)^BridgeLuid=.*$', { param($m) ';' + $m.Value + '  ; 由 choose-adapter 改成 Display=，如需恢复把行首 ; 去掉' }, 1)
    [System.IO.File]::WriteAllText($ini, $raw, (New-Object System.Text.UTF8Encoding($false)))
    Write-Info "已写入: $newLine（并把旧 BridgeLuid 注释掉）"
} else {
    $newLine = 'BridgeLuid=' + $recommend.LuidLo
    if ($raw -match '(?m)^BridgeLuid=.*$') {
        $raw = [regex]::Replace($raw, '(?m)^BridgeLuid=.*$', $newLine, 1)
    } else {
        if (-not $raw.EndsWith("`n")) { $raw += "`r`n" }
        $raw += "; choose-adapter.ps1 选了显示卡 LUID（拿不到 GDI 名，退回 LUID 钉法）`r`n$newLine`r`n"
    }
    [System.IO.File]::WriteAllText($ini, $raw, (New-Object System.Text.UTF8Encoding($false)))
    Write-Info "已写入: $newLine"
}
Write-Info '重启游戏后看 ReShade.log: [R269] Display=... 或 [R270] BridgeLuid=...；[P4.1] Init_Ext 应为 Success。'
