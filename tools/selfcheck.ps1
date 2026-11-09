<#
.SYNOPSIS
  MGPU Bridge 部署自检（2.00 MB 包 / 2026-11-02 改进版）
.DESCRIPTION
  只读检查：文件齐不齐、ini 关键键对不对、日志里该出现的标签有没有。
  不改任何文件。退出码 0 = 全绿，1 = 有问题。
.EXAMPLE
  pwsh -File .\自检-selfcheck.ps1 -GameDir "<SteamLibrary>\Jedi Survivor\SwGame\Binaries\Win64"
#>
param(
  [string]$GameDir = "",
  [string]$Log = ""
)
$ErrorActionPreference = "Continue"
$fail = 0
function Ok($m){ Write-Host ("  [OK]   " + $m) -ForegroundColor Green }
function Bad($m){ Write-Host ("  [FAIL] " + $m) -ForegroundColor Red; $script:fail++ }
function Info($m){ Write-Host ("  [--]   " + $m) -ForegroundColor DarkGray }

$pkg = $PSScriptRoot
if(-not (Test-Path (Join-Path $pkg "01-部署包"))){
  $up = Split-Path $pkg -Parent
  if(Test-Path (Join-Path $up "01-部署包")){ $pkg = $up }
  elseif(Test-Path (Join-Path (Get-Location).Path "01-部署包")){ $pkg = (Get-Location).Path }
}
if(Test-Path (Join-Path $pkg "01-部署包\Win64")){ $pkg = Join-Path $pkg "01-部署包\Win64" }
Write-Host "== 1. 包内文件" -ForegroundColor Cyan
foreach($f in @("nvngx.dll_mgpu_bridge.addon64","mgpu.ini","reshade-shaders\Shaders\mgpu_depth_tap.fx","ReShade2.ini","gpu1.ini")){
  $p = Join-Path $pkg $f
  if(Test-Path $p){ Ok ("{0}  ({1:N0} B)" -f $f,(Get-Item $p).Length) } else { Bad ("缺文件: " + $f) }
}
$sz = (Get-Item (Join-Path $pkg "nvngx.dll_mgpu_bridge.addon64")).Length
$corep = Join-Path $pkg "mgpu\_nvngx.dll"
if(Test-Path $corep){ Ok ("mgpu\_nvngx.dll  ({0:N0} B)" -f (Get-Item $corep).Length) }
else { Info "缺 mgpu\_nvngx.dll（私有 NGX core，不随包；安装后跑 tools\setup-driver.ps1 -GameDir <dir> -Apply 生成）" }
if($sz -ne 1360896){ Info ("addon 大小 {0:N0} B（预期 1,360,896 B = R41x8（2026-11-09 build：HOME 呼出直接落在 MGPU Bridge 页 + 截图自动 SDR 等 R41x6/R41x7 全部改进），与 OPT 共存配方同一代）" -f $sz) }

Write-Host "== 2. mgpu.ini 关键键" -ForegroundColor Cyan
$ini = Join-Path $pkg "mgpu.ini"
$txt = Get-Content $ini -Encoding utf8
function KeyVal($name){
  $hit = $txt | Where-Object { $_ -match ("^\s*" + [regex]::Escape($name) + "\s*=") } | Select-Object -Last 1
  if($hit){ ($hit -replace ";.*$","").Trim() } else { $null }
}
$expect = @{ Neural="1"; Passes="1"; Depth="1"; MVec="1"; DcompOverlay="1"; TemporalRequireTuple="1"; TemporalResetK="3"; AntiFlicker="2"; Look="1"; PanelOverPicture="1"; PanelFreeCursor="1"; PanelGameOverlay="0" }
foreach($k in $expect.Keys){
  $v = KeyVal $k
  if($null -eq $v){ Bad ("缺键 " + $k) }
  elseif(($v -split "=")[1].Trim() -eq $expect[$k]){ Ok ("$v") }
  else { Bad ("$v  (期望 $k=$($expect[$k]))") }
}
foreach($k in @("ChainColorSpace","NRFrameFilter","NRFrameKeep","Intensity","Style","Tuning")){
  $v = KeyVal $k
  if($null -eq $v){ Info ("无 " + $k + "（该代可能用默认值）") } else { Info $v }
}

Write-Host "== 3. 游戏目录（可选）" -ForegroundColor Cyan
if($GameDir -eq ""){
  Info "未传 -GameDir，跳过"
} else {
  foreach($f in @("dxgi.dll","nvngx.dll_mgpu_bridge.addon64","mgpu.ini","reshade-shaders\Shaders\mgpu_depth_tap.fx","mgpu\nvngx_dlssnr.dll")){
    $p = Join-Path $GameDir $f
    if(Test-Path $p){ Ok ("{0}  ({1:N0} B)" -f $f,(Get-Item $p).Length) } else { Bad ("缺文件: " + $f) }
  }
  $rs = Join-Path $GameDir "ReShade.ini"
  if(Test-Path $rs){
    $line = (Get-Content $rs -Encoding utf8 | Where-Object { $_ -match "^EffectSearchPaths" } | Select-Object -First 1)
    if($line -match "reshade-shaders\\Shaders"){ Ok ("EffectSearchPaths 含 reshade-shaders\\Shaders") } else { Bad ("EffectSearchPaths 不含 reshade-shaders\\Shaders : " + $line) }
  } else { Bad "缺 ReShade.ini" }
  if($Log -eq ""){ $Log = Join-Path $GameDir "ReShade.log" }
}

Write-Host "== 4. 日志标签" -ForegroundColor Cyan
if($Log -ne "" -and (Test-Path $Log)){
  $lg = Get-Content $Log -Encoding utf8 -ErrorAction SilentlyContinue
  $tags = @(
    @{p="\[R141\]|MGPU Bridge 0\.4"; n="构建横幅（确认跑的是本包）"; must=$true},
    @{p="\[T2\]|adapter|selection"; n="选卡"; must=$false},
    @{p="\[T4\]|present chain created"; n="交换链建立"; must=$false},
    @{p="\[H1\]|bridge chain colour space"; n="PQ 声明（ChainColorSpace）"; must=$true},
    @{p="\[R101\]|\[R280\]|creates="; n="NR/NVOF 计数行"; must=$false},
    @{p="first neural frame"; n="NR 真在跑（bridge visual ROOTED on the neural frame）"; must=$true},
    @{p="ERROR 204|ERROR 40|REFUSING"; n="错误标记"; must=$false}
  )
  foreach($t in $tags){
    $hit = $lg | Select-String -Pattern $t.p | Select-Object -Last 1
    if($hit){ Ok ("{0}: {1}" -f $t.n, $hit.Line.Trim().Substring(0,[Math]::Min(120,$hit.Line.Trim().Length))) }
    elseif($t.must){ Bad ("日志里没有: " + $t.n) }
    else { Info ("未出现（不一定错）: " + $t.n) }
  }
  $err = $lg | Select-String -Pattern "ERROR 204|REFUSING" -SimpleMatch:$false | Select-Object -First 3
  if($err){ foreach($e in $err){ Bad ("发现问题行: " + $e.Line.Trim().Substring(0,[Math]::Min(140,$e.Line.Trim().Length))) } }
} else { Info "没有日志文件（先跑一次游戏再来）" }

Write-Host ""
if($fail -eq 0){ Write-Host "结论：全绿。" -ForegroundColor Green; exit 0 }
else { Write-Host ("结论：{0} 项有问题。" -f $fail) -ForegroundColor Red; exit 1 }
