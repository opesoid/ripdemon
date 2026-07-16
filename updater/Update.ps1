#Requires -Version 5.1
<#
.SYNOPSIS
  Updates bundled yt-dlp, ffmpeg, and deno.
#>
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'RIP-Demon'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

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

if (-not (Test-Path $root)) {
    Write-Host "  RIP Demon is not installed at $root" -ForegroundColor Red
    Write-Host '  Run installer\Install.cmd first.' -ForegroundColor Yellow
    exit 1
}

Write-Host '  Checking yt-dlp + ffmpeg + deno...' -ForegroundColor Cyan
$result = Ensure-RipDemonTools -ToolsDir $toolsDir -ForceYtDlp:$Force -ForceFfmpeg:$Force -ForceDeno:$Force

Write-Host ''
Write-Host '  Done.' -ForegroundColor Green
if ($result.YtDlp.Version) {
    Write-Host "  yt-dlp $($result.YtDlp.Version)"
}
if ($result.Ffmpeg.Tag) {
    Write-Host "  ffmpeg $($result.Ffmpeg.Tag)"
}
if ($result.Deno.Version) {
    Write-Host "  deno $($result.Deno.Version)"
}
Write-Host ''
Write-Host '  To upgrade RIP Demon itself, re-run the installer from a newer zip.' -ForegroundColor DarkGray
Write-Host ''
