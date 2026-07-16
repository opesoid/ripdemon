#Requires -Version 5.1
<#
.SYNOPSIS
  Installs RIP Demon for the current Windows user (no admin required).
#>
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'RIP-Demon'),
    [switch]$SkipTools,
    [switch]$SkipWizard
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ToolsScript = Join-Path $ProjectRoot 'updater\RipDemon.Tools.ps1'
if (-not (Test-Path $ToolsScript)) {
    $ToolsScript = Join-Path $PSScriptRoot '..\updater\RipDemon.Tools.ps1'
}
. $ToolsScript

Write-RipDemonBanner -Title 'RIP Demon Installer'

try {
    Assert-RipDemonWindowsX64
} catch {
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    exit 1
}

$versionFile = Join-Path $ProjectRoot 'VERSION'
if (-not (Test-Path $versionFile)) {
    $versionFile = Join-Path $InstallRoot 'version.txt'
}
$version = if (Test-Path $versionFile) {
    (Get-Content -Path $versionFile -Raw).Trim()
} else {
    '1.0.1'
}

Write-Host "  Version:  $version"
Write-Host "  Target:   $InstallRoot"
Write-Host ''

$totalSteps = 6
$step = 0
function Write-Step([string]$Message) {
    $script:step++
    Write-Host "  [$script:step/$totalSteps] $Message" -ForegroundColor Cyan
}

$binDir   = Join-Path $InstallRoot 'bin'
$libDir   = Join-Path $InstallRoot 'lib'
$toolsDir = Join-Path $InstallRoot 'tools'

Write-Step 'Copying application files...'
$copyResult = Copy-RipDemonAppFiles -ProjectRoot $ProjectRoot -InstallRoot $InstallRoot
$version = $copyResult.Version
Write-Host '  Application files copied.' -ForegroundColor Green

Write-Step 'First-run setup...'
$cfg = Invoke-RipDemonFirstRunWizard -InstallRoot $InstallRoot -Skip:$SkipWizard
if (-not $cfg) {
    . (Join-Path $libDir 'RipDemon.Config.ps1')
    $cfg = Get-RipDemonConfig -InstallRoot $InstallRoot -DefaultConfigPath (Join-Path $libDir 'config.default.ini')
}

New-Item -ItemType Directory -Force -Path $cfg.Mp3Dir, $cfg.Mp4Dir | Out-Null
Write-Host "  MP3 folder: $($cfg.Mp3Dir)" -ForegroundColor DarkGray
Write-Host "  MP4 folder: $($cfg.Mp4Dir)" -ForegroundColor DarkGray

Write-Step 'Installing yt-dlp + ffmpeg + deno...'
Write-Host '  Stage A/3: yt-dlp' -ForegroundColor DarkGray
Write-Host '  Stage B/3: FFmpeg (~80 MB)' -ForegroundColor DarkGray
Write-Host '  Stage C/3: deno (~40 MB)' -ForegroundColor DarkGray
Write-Host '  First install downloads ~100-150 MB — please wait.' -ForegroundColor DarkGray
if (-not $SkipTools) {
    Ensure-RipDemonTools -ToolsDir $toolsDir | Out-Null
} else {
    Write-Host '  Skipped tool download (-SkipTools).' -ForegroundColor Yellow
}

Write-Step 'Updating PATH...'
Add-UserPathEntry -Entry $binDir | Out-Null
# Ensure this process can invoke yt immediately
if ($env:Path -notlike "*$binDir*") {
    $env:Path = "$binDir;$env:Path"
}

$legacyYt = Join-Path $env:USERPROFILE 'bin\yt.cmd'
if (Test-Path $legacyYt) {
    $legacyContent = Get-Content -Path $legacyYt -Raw -ErrorAction SilentlyContinue
    if ($legacyContent -and ($legacyContent -notmatch 'RIPDEMON')) {
        $backup = Join-Path $env:USERPROFILE 'bin\yt.cmd.pre-ripdemon.bak'
        Move-Item -Force $legacyYt $backup
        Write-Host "  Retired legacy yt.cmd -> $backup" -ForegroundColor Yellow
    }
}

Write-Step 'Start Menu shortcuts...'
New-RipDemonStartMenuShortcut -InstallRoot $InstallRoot -BinDir $binDir
Clear-RipDemonShellLeftovers -Quiet | Out-Null

Write-Step 'Registering uninstaller...'
Register-RipDemonUninstall -InstallRoot $InstallRoot -Version $version

Write-Host ''
Write-Host '  ========================================' -ForegroundColor DarkGreen
Write-Host '   RIP Demon installed successfully' -ForegroundColor Green
Write-Host '  ========================================' -ForegroundColor DarkGreen
Write-Host ''
Write-Host "  RIP Demon $version by Opes - https://opes.dev" -ForegroundColor White
Write-Host ''
Write-Host '  This installer window can already run yt (PATH updated for this session).' -ForegroundColor White
Write-Host '  Other open terminals still need a restart to pick up PATH.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Try:' -ForegroundColor White
Write-Host '    yt version'
Write-Host '    yt gui'
Write-Host '    yt mp3          (uses clipboard if you omit the URL)'
Write-Host '    yt mp4 --open <url>'
Write-Host '    yt info <url>'
Write-Host '    yt config'
Write-Host ''
Write-Host "  MP3 folder: $($cfg.Mp3Dir)"
Write-Host "  MP4 folder: $($cfg.Mp4Dir)"
Write-Host "  Config:     $(Join-Path $InstallRoot 'config.ini')"
Write-Host "  Install:    $InstallRoot"
Write-Host ''
