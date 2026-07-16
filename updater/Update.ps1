#Requires -Version 5.1
<#
.SYNOPSIS
  Updates RIP Demon itself and bundled yt-dlp, ffmpeg, and deno.
#>
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'RIP-Demon'),
    [switch]$Force,
    [switch]$SkipApp,
    [switch]$AppOnly
)

$ErrorActionPreference = 'Stop'

if ($SkipApp -and $AppOnly) {
    Write-Host '  -SkipApp and -AppOnly cannot be used together.' -ForegroundColor Red
    exit 1
}

# Guard: yt.cmd used to forward "update" via %* (cmd SHIFT does not change %*),
# which bound InstallRoot="update". Ignore bare command words / relative junk.
$defaultRoot = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
if (-not $InstallRoot -or $InstallRoot -match '^(update|uninstall|version|help|gui|config)$' -or
    ($InstallRoot -notmatch '^[A-Za-z]:\\' -and $InstallRoot -notmatch '^\\\\' -and -not (Test-Path -LiteralPath $InstallRoot))) {
    $InstallRoot = $defaultRoot
}

$toolsPs1 = Join-Path $PSScriptRoot 'RipDemon.Tools.ps1'
if (-not (Test-Path $toolsPs1)) {
    $toolsPs1 = Join-Path $InstallRoot 'updater\RipDemon.Tools.ps1'
}
. $toolsPs1

Write-RipDemonBanner -Title 'RIP Demon Updater'

$root = Get-RipDemonRoot -Override $InstallRoot
$toolsDir = Join-Path $root 'tools'
$versionFile = Join-Path $root 'version.txt'
$appVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }

Write-Host "  RIP Demon: $appVersion (Opes - https://opes.dev)"
Write-Host "  Tools:     $toolsDir"
Write-Host ''

if (-not (Test-Path -LiteralPath $root)) {
    Write-Host "  RIP Demon is not installed at $root" -ForegroundColor Red
    Write-Host '  Install with:' -ForegroundColor Yellow
    Write-Host '    irm https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/installer/web-install.ps1 | iex' -ForegroundColor Yellow
    exit 1
}

$appResult = $null
if (-not $SkipApp) {
    try {
        $appResult = Update-RipDemonApp -InstallRoot $root -Force:$Force
        # Reload helpers after app files may have been replaced
        $toolsPs1 = Join-Path $root 'updater\RipDemon.Tools.ps1'
        if (Test-Path -LiteralPath $toolsPs1) {
            . $toolsPs1
        }
        $appVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { $appVersion }
    } catch {
        Write-Host "  App update failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($AppOnly) { exit 1 }
        Write-Host '  Continuing with tool updates...' -ForegroundColor Yellow
    }
    Write-Host ''
}

$result = $null
if (-not $AppOnly) {
    Write-Host '  Checking yt-dlp + ffmpeg + deno...' -ForegroundColor Cyan
    $result = Ensure-RipDemonTools -ToolsDir $toolsDir -ForceYtDlp:$Force -ForceFfmpeg:$Force -ForceDeno:$Force
}

Write-Host ''
Write-Host '  Done.' -ForegroundColor Green
Write-Host "  RIP Demon $appVersion"
if ($appResult -and $appResult.Updated) {
    Write-Host '  (application package updated)' -ForegroundColor DarkGray
}
if ($result) {
    if ($result.YtDlp.Version) {
        Write-Host "  yt-dlp $($result.YtDlp.Version)"
    }
    if ($result.Ffmpeg.Tag) {
        Write-Host "  ffmpeg $($result.Ffmpeg.Tag)"
    }
    if ($result.Deno.Version) {
        Write-Host "  deno $($result.Deno.Version)"
    }
}
Write-Host ''
