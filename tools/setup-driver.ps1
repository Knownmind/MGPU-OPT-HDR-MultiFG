# setup-driver.ps1 - 驱动 / NGX core / NR 模型 配套检查与一键修复（11.9 部署包附带）
#
# 用途：不同机器、不同 NVIDIA 驱动版本上，桥的 NGX 初始化需要两样东西配套：
#   1) mgpu\_nvngx.dll  —— 本机驱动自带的 NGX core（直接从 DriverStore 拷，版本永远和驱动配套）
#   2) mgpu\nvngx_dlssnr.dll —— NR 模型，版本要与 core/驱动匹配；不匹配时 [P4.1] Init_Ext
#                               会返回 FAIL_FeatureNotSupported / FAIL_PlatformError，NR 和插帧都不启动
#
# 本脚本做三件事：
#   - 读出本机 NVIDIA 驱动版本、DriverStore 里的 _nvngx.dll 路径/版本；
#   - 扫描本机（当前游戏 + Steam 库里的其他游戏）已有的 nvngx_dlssnr.dll 变体，列出 版本/大小/路径；
#   - 对比 mgpu\ 现状，给出建议；-Apply 会把 DriverStore 的 _nvngx.dll 拷进 mgpu\
#     （可用 -ModelPath 指定要换的模型文件一并拷入，自动备份旧文件）。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File setup-driver.ps1 -GameDir "<游戏exe目录>"
#   powershell -ExecutionPolicy Bypass -File setup-driver.ps1 -GameDir "<游戏exe目录>" -Apply
#   powershell -ExecutionPolicy Bypass -File setup-driver.ps1 -GameDir "<游戏exe目录>" -Apply -ModelPath "D:\...\nvngx_dlssnr.dll"
#   powershell -ExecutionPolicy Bypass -File setup-driver.ps1 -GameDir "<游戏exe目录>" -NoScan   # 不扫 Steam 库
#
# 说明：NVIDIA 运行时文件不随包再分发；本脚本只是把"本机驱动已有的文件"复制到本机游戏目录。

param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [switch]$Apply,
    [string]$ModelPath = '',
    [switch]$NoScan
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "[驱动] $m" }
function Warn2($m) { Write-Host "[警告] $m" -ForegroundColor Yellow }
function Err2($m) { Write-Host "[失败] $m" -ForegroundColor Red }

if (-not (Test-Path (Join-Path $GameDir 'mgpu'))) {
    Err2 "找不到 $GameDir\mgpu —— 请先把部署包 Win64\ 内容复制到游戏目录。"
    exit 2
}
$mgpu = Join-Path $GameDir 'mgpu'
$coreLocal = Join-Path $mgpu '_nvngx.dll'
$modelLocal = Join-Path $mgpu 'nvngx_dlssnr.dll'

# ---- 1. 本机 NVIDIA 驱动 ----
Write-Host ''
Write-Host '==== 本机 NVIDIA 驱动 ====' -ForegroundColor Cyan
$gpus = @()
try { $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -match 'NVIDIA' }) } catch { }
if ($gpus.Count -eq 0) {
    Err2 '没有找到 NVIDIA 显卡；NR/插帧需要 N 卡（建议 RTX 50 系做 NR）。'
    exit 3
}
$gpus | ForEach-Object { '  {0}  driver={1} ({2:yyyy-MM-dd})' -f $_.Name, $_.DriverVersion, $_.DriverDate }

# ---- 2. DriverStore 的 NGX core（权威版本）----
$coreDst = $null
$regPath = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\NGXCore'
try {
    $v = (Get-ItemProperty -Path $regPath -Name 'FullPath' -ErrorAction Stop).FullPath
    if ($v -and (Test-Path $v)) {
        $it = Get-Item $v
        if ($it.PSIsContainer) {
            $inside = Join-Path $v '_nvngx.dll'
            if (Test-Path $inside) { $coreDst = $inside }
        } elseif ($it.Name -match '_nvngx\.dll$') { $coreDst = $v }
    }
} catch { }
if (-not $coreDst) {
    $cand = Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -Directory -Filter 'nv_dispi.inf_amd64_*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName '_nvngx.dll' } |
            Where-Object { Test-Path $_ } |
            Sort-Object { (Get-Item $_).LastWriteTime } -Descending
    $coreDst = ($cand | Select-Object -First 1)
}
Write-Host ''
Write-Host '==== NGX core（DriverStore）====' -ForegroundColor Cyan
if (-not $coreDst) {
    Warn2 '找不到 DriverStore 里的 _nvngx.dll（注册表 NGXCore\FullPath 也没有）。'
    Warn2 '请确认 NVIDIA 驱动安装完整；桥会退回从注册表加载。'
} else {
    $coreDstItem = Get-Item $coreDst
    $coreVer = $coreDstItem.VersionInfo.FileVersion
    '  {0}' -f $coreDst
    '  version={0}  size={1}' -f $coreVer, $coreDstItem.Length
    if (Test-Path $coreLocal) {
        $a = (Get-FileHash $coreLocal -Algorithm SHA256).Hash
        $b = (Get-FileHash $coreDst -Algorithm SHA256).Hash
        if ($a -eq $b) { Info 'mgpu\_nvngx.dll 与驱动一致（已配套）。' }
        else { Warn2 'mgpu\_nvngx.dll 与当前驱动不一致（旧驱动残留）——建议 -Apply 覆盖。' }
    } else {
        Warn2 'mgpu\_nvngx.dll 不存在：桥会从注册表加载系统 core；-Apply 可复制一份私有 core。'
    }
}

# ---- 3. 扫描本机已有 NR 模型变体 ----
Write-Host ''
Write-Host '==== 本机已有 NR 模型（nvngx_dlssnr.dll）====' -ForegroundColor Cyan
$models = @()
function Add-Model($p) {
    if (-not (Test-Path $p)) { return }
    $it = Get-Item $p
    $script:models += [pscustomobject]@{
        Path = $it.FullName
        Ver = $it.VersionInfo.FileVersion
        Size = $it.Length
        Sha = (Get-FileHash $p -Algorithm SHA256).Hash.Substring(0,16)
    }
}
Add-Model $modelLocal
if ($ModelPath) { Add-Model $ModelPath }
if (-not $NoScan) {
    # Steam 库位置：先读注册表里的 SteamPath，再读 libraryfolders.vdf；
    # 不写死盘符（不同机器 Steam 库可能在任意盘）
    $libs = @()
    $steamDir = ''
    try { $steamDir = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath } catch { }
    if (-not $steamDir) { $steamDir = Join-Path ${env:ProgramFiles(x86)} 'Steam' }
    if (Test-Path (Join-Path $steamDir 'steamapps')) { $libs += $steamDir }
    $vdf = Join-Path $steamDir 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $txt = Get-Content $vdf -Raw
        [regex]::Matches($txt, '"path"\s+"([^"]+)"') | ForEach-Object { $libs += ($_.Groups[1].Value -replace '\\\\', '\') }
    }
    $roots = @()
    foreach ($l in ($libs | Select-Object -Unique)) {
        $common = Join-Path $l 'steamapps\common'
        if (Test-Path $common) { $roots += $common }
    }
    Write-Host ('  扫描 ' + $roots.Count + ' 个 Steam 库（可加 -NoScan 跳过）...')
    foreach ($r in $roots) {
        try {
            Get-ChildItem -LiteralPath $r -Filter 'nvngx_dlssnr.dll' -Recurse -Depth 6 -File -ErrorAction SilentlyContinue |
                ForEach-Object { Add-Model $_.FullName }
        } catch { }
    }
}
$uniq = @{}
foreach ($m in $models) { $uniq[$m.Sha] = $m }
$models = @($uniq.Values)
if ($models.Count -eq 0) {
    Warn2 '没找到任何 nvngx_dlssnr.dll：请用 -ModelPath 指定一个模型，或从别的游戏 mgpu\ 里复制。'
} else {
    $models | Sort-Object Ver, Size | ForEach-Object {
        '  ver={0,-12} size={1,10} sha={2}  {3}' -f $_.Ver, $_.Size, $_.Sha, $_.Path
    }
}

# ---- 4. 建议 ----
Write-Host ''
Write-Host '==== 建议 ====' -ForegroundColor Cyan
Info 'core：与本机驱动一致 = 从 DriverStore 复制（-Apply 会做）'
if ($models.Count -gt 1) {
    Info 'model：日志 [P4.1] Init_Ext 若失败（FAIL_FeatureNotSupported / FAIL_PlatformError），换另一个版本的模型再试；'
    Info '       本机验证过的组合：core=驱动自带 + model=310.8（165,840,496 B）工作正常。'
} elseif ($models.Count -eq 1) {
    Info ('model：当前只有一个变体（ver={0}）。若 Init_Ext 失败，找另一个版本的 nvngx_dlssnr.dll 用 -ModelPath 指定。' -f $models[0].Ver)
}
Info '换完模型/ core 后重启游戏；判据：[R240] private mgpu copy / [P4.1] Init_Ext Success / [V53] ROOTED'

if (-not $Apply) {
    Write-Host ''
    Info '只检查不修改。要执行复制，加 -Apply（可配合 -ModelPath "<模型文件>"）。'
    exit 0
}

# ---- 5. 写入 ----
Write-Host ''
if ($coreDst) {
    $bak = $coreLocal + '.bak-setup-driver-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    if (Test-Path $coreLocal) { Copy-Item -LiteralPath $coreLocal -Destination $bak -Force; Info "备份 _nvngx.dll -> $bak" }
    Copy-Item -LiteralPath $coreDst -Destination $coreLocal -Force
    Info "已复制驱动 core -> mgpu\_nvngx.dll"
}
if ($ModelPath) {
    if (-not (Test-Path $ModelPath)) { Err2 "找不到 -ModelPath 指定的文件: $ModelPath"; exit 4 }
    $bakM = $modelLocal + '.bak-setup-driver-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    if (Test-Path $modelLocal) { Copy-Item -LiteralPath $modelLocal -Destination $bakM -Force; Info "备份 nvngx_dlssnr.dll -> $bakM" }
    Copy-Item -LiteralPath $ModelPath -Destination $modelLocal -Force
    Info "已复制模型 -> mgpu\nvngx_dlssnr.dll ($ModelPath)"
}
Write-Host ''
Info '完成。重启游戏后看 ReShade.log: [R240] NGX core ... private mgpu copy；[P4.1] Init_Ext 应为 Success。'
