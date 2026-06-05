#Requires -Version 5.1
<#
.SYNOPSIS
  ตัวติดตั้งปลั๊กอิน thai-quotation สำหรับ Claude Code (Windows)

.DESCRIPTION
  ติดตั้งอัตโนมัติ:
    1) ดาวน์โหลด (clone) marketplace boombignose-local
    2) ลงทะเบียนใน known_marketplaces.json
    3) copy ปลั๊กอินลง cache
    4) บันทึกใน installed_plugins.json
    5) เปิดใช้งานใน settings.json (enabledPlugins)
    6) สร้าง seller.json จากเทมเพลต (ไม่เขียนทับของเดิม)
  ทุกไฟล์ config จะถูกสำรอง (.bak) ก่อนแก้ และทำซ้ำได้ (idempotent)
  ถ้าขั้นตอนอัตโนมัติล้มเหลว จะพิมพ์คำสั่ง /plugin ให้ติดตั้งด้วยมือ (fallback)

.PARAMETER DryRun
  แสดงสิ่งที่จะทำโดยไม่เขียนไฟล์จริง

.PARAMETER Force
  เขียนทับ seller.json เดิม

.EXAMPLE
  irm https://raw.githubusercontent.com/vitoon-ai/thai-quotation/main/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---------- constants ----------
$MarketKey   = 'boombignose-local'
$PluginName  = 'thai-quotation'
$Version     = '1.1.0'
$RepoUrl     = 'https://github.com/vitoon-ai/thai-quotation.git'
$RawBase     = 'https://raw.githubusercontent.com/vitoon-ai/thai-quotation/main'

$ClaudeDir     = Join-Path $env:USERPROFILE '.claude'
$PluginsDir    = Join-Path $ClaudeDir 'plugins'
$MarketDir     = Join-Path $PluginsDir ("marketplaces\" + $MarketKey)
$CacheDir      = Join-Path $PluginsDir ("cache\$MarketKey\$PluginName\$Version")
$KnownPath     = Join-Path $PluginsDir 'known_marketplaces.json'
$InstalledPath = Join-Path $PluginsDir 'installed_plugins.json'
$SettingsPath  = Join-Path $ClaudeDir 'settings.json'
$QuotaDir      = Join-Path $ClaudeDir 'quotation'
$SellerPath    = Join-Path $QuotaDir 'seller.json'
$PluginKey     = "$PluginName@$MarketKey"

# ---------- helpers ----------
function Write-Head($m){ Write-Host "`n$m" -ForegroundColor Cyan }
function Write-Step($m){ Write-Host "   $m" -ForegroundColor Gray }
function Write-OK($m){ Write-Host "   [OK] $m" -ForegroundColor Green }
function Write-Warn2($m){ Write-Host "   [!] $m" -ForegroundColor Yellow }

function Save-JsonNoBom($obj, $path){
  if($DryRun){ Write-Step "(dry-run) จะเขียน $path"; return }
  $json = $obj | ConvertTo-Json -Depth 25
  $enc  = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $json, $enc)
}

function Backup-File($path){
  if((Test-Path $path) -and -not $DryRun){
    $bak = "$path.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $path $bak -Force
    Write-Step ("สำรอง: " + (Split-Path $bak -Leaf))
  }
}

function Read-JsonOrDefault($path, $default){
  if(Test-Path $path){
    try { return ((Get-Content $path -Raw -Encoding UTF8) | ConvertFrom-Json) }
    catch { Write-Warn2 "อ่าน $path ไม่ได้ — ใช้ค่าเริ่มต้น"; return $default }
  }
  return $default
}

function Has-Prop($obj, $name){
  return ($null -ne $obj) -and ($obj.PSObject.Properties.Name -contains $name)
}

function Ensure-Dir($path){
  if(-not (Test-Path $path) -and -not $DryRun){
    New-Item -ItemType Directory -Force -Path $path | Out-Null
  }
}

# ---------- banner ----------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  thai-quotation  v$Version" -ForegroundColor Yellow
Write-Host "  ตัวติดตั้งปลั๊กอินใบเสนอราคาไทย สำหรับ Claude Code" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
if($DryRun){ Write-Warn2 "โหมด DRY-RUN — ไม่มีการเขียนไฟล์จริง" }

$autoOk = $true
try {
  # 1) prerequisites
  Write-Head "1) ตรวจสอบเครื่องมือ"
  $git = Get-Command git -ErrorAction SilentlyContinue
  if(-not $git){ throw "ไม่พบ git (จำเป็นสำหรับดาวน์โหลด marketplace) — ติดตั้ง git ก่อน https://git-scm.com" }
  Write-OK "พบ git: $($git.Source)"
  Write-OK "Claude config: $ClaudeDir"
  Ensure-Dir $PluginsDir
  Ensure-Dir (Split-Path $MarketDir)
  Ensure-Dir (Split-Path $CacheDir)

  # 2) download marketplace
  Write-Head "2) ดาวน์โหลด marketplace ($MarketKey)"
  if(Test-Path (Join-Path $MarketDir '.git')){
    Write-Step "พบ repo เดิม — อัปเดต (git pull)"
    if(-not $DryRun){ & git -C $MarketDir pull --ff-only *> $null }
  } else {
    if((Test-Path $MarketDir) -and -not $DryRun){ Remove-Item $MarketDir -Recurse -Force }
    Write-Step "clone $RepoUrl"
    if(-not $DryRun){ & git clone --depth 1 $RepoUrl $MarketDir *> $null }
  }
  Write-OK "marketplace: $MarketDir"
  $sha = if($DryRun){ 'dryrun' } else { (& git -C $MarketDir rev-parse HEAD).Trim() }

  # 3) copy plugin into cache
  Write-Head "3) ติดตั้งปลั๊กอินลง cache"
  $srcPlugin = Join-Path $MarketDir ("plugins\" + $PluginName)
  if(-not (Test-Path $srcPlugin) -and -not $DryRun){ throw "ไม่พบโฟลเดอร์ปลั๊กอินใน repo: $srcPlugin" }
  if(-not $DryRun){
    if(Test-Path $CacheDir){ Remove-Item $CacheDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
    Copy-Item (Join-Path $srcPlugin '*') $CacheDir -Recurse -Force
  }
  Write-OK "copy -> $CacheDir"

  # 4) register marketplace
  Write-Head "4) ลงทะเบียน marketplace"
  Backup-File $KnownPath
  $known = Read-JsonOrDefault $KnownPath (New-Object PSObject)
  $entry = [PSCustomObject]@{
    source          = [PSCustomObject]@{ source = 'git'; url = $RepoUrl }
    installLocation = $MarketDir
    lastUpdated     = (Get-Date).ToUniversalTime().ToString('o')
  }
  $known | Add-Member -NotePropertyName $MarketKey -NotePropertyValue $entry -Force
  Save-JsonNoBom $known $KnownPath
  Write-OK "เพิ่ม '$MarketKey' ใน known_marketplaces.json"

  # 5) record installation
  Write-Head "5) บันทึกการติดตั้ง"
  Backup-File $InstalledPath
  $installed = Read-JsonOrDefault $InstalledPath ([PSCustomObject]@{ version = 2; plugins = (New-Object PSObject) })
  if(-not (Has-Prop $installed 'plugins')){
    $installed | Add-Member -NotePropertyName 'plugins' -NotePropertyValue (New-Object PSObject) -Force
  }
  if(-not (Has-Prop $installed 'version')){
    $installed | Add-Member -NotePropertyName 'version' -NotePropertyValue 2 -Force
  }
  $now = (Get-Date).ToUniversalTime().ToString('o')
  $pe = [PSCustomObject]@{
    scope       = 'user'
    installPath = $CacheDir
    version     = $Version
    installedAt = $now
    lastUpdated = $now
    gitCommitSha= $sha
  }
  $installed.plugins | Add-Member -NotePropertyName $PluginKey -NotePropertyValue @($pe) -Force
  Save-JsonNoBom $installed $InstalledPath
  Write-OK "บันทึก '$PluginKey' (scope: user)"

  # 6) enable in settings.json
  Write-Head "6) เปิดใช้งานปลั๊กอิน"
  Backup-File $SettingsPath
  $settings = Read-JsonOrDefault $SettingsPath (New-Object PSObject)
  if(-not (Has-Prop $settings 'enabledPlugins')){
    $settings | Add-Member -NotePropertyName 'enabledPlugins' -NotePropertyValue (New-Object PSObject) -Force
  }
  $settings.enabledPlugins | Add-Member -NotePropertyName $PluginKey -NotePropertyValue $true -Force
  Save-JsonNoBom $settings $SettingsPath
  Write-OK "enabledPlugins['$PluginKey'] = true"

} catch {
  $autoOk = $false
  Write-Warn2 "ติดตั้งอัตโนมัติไม่สำเร็จ: $($_.Exception.Message)"
}

# 7) seller.json template (always attempt)
Write-Head "7) ตั้งค่า seller.json (ข้อมูลบริษัทของคุณ)"
Ensure-Dir $QuotaDir
if((Test-Path $SellerPath) -and -not $Force){
  Write-Warn2 "มี seller.json อยู่แล้ว — ข้าม (ใช้ -Force เพื่อเขียนทับ): $SellerPath"
} else {
  if($DryRun){
    Write-Step "(dry-run) จะสร้าง seller.json: $SellerPath"
  } else {
    $tmplLocal = Join-Path $MarketDir ("plugins\" + $PluginName + "\examples\seller.example.json")
    $done = $false
    if(Test-Path $tmplLocal){
      Copy-Item $tmplLocal $SellerPath -Force
      $done = $true
    } else {
      try {
        Invoke-WebRequest "$RawBase/plugins/$PluginName/examples/seller.example.json" -OutFile $SellerPath -UseBasicParsing
        $done = $true
      } catch { Write-Warn2 "ดาวน์โหลดเทมเพลต seller ไม่ได้: $($_.Exception.Message)" }
    }
    if($done){ Write-OK "สร้าง seller.json จากเทมเพลต: $SellerPath" }
  }
}

# ---------- summary ----------
Write-Head "=========================  สรุป  ========================="
if($autoOk){
  Write-Host "  [OK] ติดตั้ง $PluginKey อัตโนมัติเรียบร้อย" -ForegroundColor Green
} else {
  Write-Warn2 "ทำขั้นตอนอัตโนมัติไม่ครบ — ติดตั้งด้วยมือใน Claude Code:"
  Write-Host "        /plugin marketplace add vitoon-ai/thai-quotation" -ForegroundColor White
  Write-Host "        /plugin install thai-quotation@boombignose-local" -ForegroundColor White
}
Write-Host ""
Write-Host "  ขั้นตอนถัดไป:" -ForegroundColor Cyan
Write-Host "   1) แก้ไขข้อมูลบริษัทของคุณใน:" -ForegroundColor White
Write-Host "        $SellerPath" -ForegroundColor White
Write-Host "   2) รีสตาร์ท / รีโหลด Claude Code" -ForegroundColor White
Write-Host "   3) พิมพ์  /quotation  เพื่อออกใบเสนอราคาใบแรก" -ForegroundColor White
Write-Host ""
Write-Host "  เอกสาร: https://github.com/vitoon-ai/thai-quotation" -ForegroundColor DarkGray
Write-Host "  ไฟล์ใบเสนอราคาจะถูกบันทึกในโฟลเดอร์ quotations/ ของโปรเจกต์ที่คุณเปิดอยู่" -ForegroundColor DarkGray
Write-Host ""
