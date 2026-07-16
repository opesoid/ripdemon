#Requires -Version 5.1
<#
.SYNOPSIS
  One-line installer: download RIP Demon from GitHub main and run Install.ps1.

.DESCRIPTION
  Recommended (jsDelivr — avoids stale GitHub raw CDN cache):

    irm https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/installer/web-install.ps1 | iex

  With flags:

    & ([scriptblock]::Create((irm https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/installer/web-install.ps1))) -SkipWizard
#>
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'RIP-Demon'),
    [switch]$SkipTools,
    [switch]$SkipWizard
)

$ErrorActionPreference = 'Stop'

# irm|iex runs in the caller's session — Restricted policy blocks .ps1 on disk.
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {}

# --- Load RipDemon.Tools.ps1 into THIS scope (must not be inside a function; iex drops function-local defs) ---
$RipDemonToolsText = $null
if ($PSScriptRoot) {
    $localTools = Join-Path $PSScriptRoot '..\updater\RipDemon.Tools.ps1'
    if (Test-Path -LiteralPath $localTools) {
        $RipDemonToolsText = Get-Content -LiteralPath $localTools -Raw
    }
}

if (-not $RipDemonToolsText) {
    $toolUrls = @(
        'https://api.github.com/repos/opesoid/ripdemon/contents/updater/RipDemon.Tools.ps1?ref=main'
        'https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/updater/RipDemon.Tools.ps1'
        'https://raw.githubusercontent.com/opesoid/ripdemon/main/updater/RipDemon.Tools.ps1'
    )
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        foreach ($toolUrl in $toolUrls) {
            try {
                if ($toolUrl -match 'api\.github\.com/.+/contents/') {
                    $apiResp = Invoke-RestMethod -Uri $toolUrl -Headers @{
                        'User-Agent' = 'RIP-Demon'
                        'Accept'     = 'application/vnd.github+json'
                    }
                    if ($apiResp.content) {
                        $b64 = ($apiResp.content -replace '\s', '')
                        $RipDemonToolsText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
                    }
                }
                else {
                    $webResp = Invoke-WebRequest -Uri $toolUrl -UseBasicParsing -Headers @{
                        'User-Agent'    = 'RIP-Demon'
                        'Cache-Control' = 'no-cache'
                    }
                    $RipDemonToolsText = if ($webResp.Content -is [byte[]]) {
                        [Text.Encoding]::UTF8.GetString($webResp.Content)
                    } else {
                        [string]$webResp.Content
                    }
                }
                if ($RipDemonToolsText -and $RipDemonToolsText.Length -gt 100 -and ($RipDemonToolsText -match 'function Write-RipDemonBanner')) {
                    break
                }
                $RipDemonToolsText = $null
            } catch {
                $RipDemonToolsText = $null
            }
        }
    }
    finally {
        $ProgressPreference = $prevProgress
    }
}

if (-not $RipDemonToolsText -or ($RipDemonToolsText -notmatch 'function Write-RipDemonBanner')) {
    throw 'Failed to load RipDemon.Tools.ps1 helpers (Write-RipDemonBanner missing).'
}

. ([scriptblock]::Create($RipDemonToolsText))

if (-not (Get-Command Write-RipDemonBanner -ErrorAction SilentlyContinue)) {
    throw 'RipDemon helpers loaded but Write-RipDemonBanner is still unavailable.'
}

Write-RipDemonBanner -Title 'RIP Demon Web Installer'

try {
    Assert-RipDemonWindowsX64
} catch {
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    exit 1
}

Write-Host '  Fetching latest sources from GitHub (main)...' -ForegroundColor Cyan
$source = Get-RipDemonRepoSource
$commitLabel = if ($source.Commit) { $source.Commit.Substring(0, 7) } else { 'main' }
Write-Host "  Source:   $($source.Branch) @ $commitLabel (v$($source.Version))" -ForegroundColor White
Write-Host "  Target:   $InstallRoot"
Write-Host ''

$workDir = Join-Path $env:TEMP ("ripdemon-webinstall-{0}" -f [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $workDir $source.Name
$extractDir = Join-Path $workDir 'extract'

try {
    New-Item -ItemType Directory -Force -Path $workDir, $extractDir | Out-Null

    Save-RipDemonFile -Uri $source.Url -OutFile $zipPath `
        -Label "Downloading RIP Demon from GitHub ($($source.Branch))"

    Write-Host '  Extracting package...' -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    $projectRoot = Resolve-RipDemonProjectRoot -ExtractDir $extractDir
    $installPs1 = Join-Path $projectRoot 'installer\Install.ps1'
    if (-not (Test-Path -LiteralPath $installPs1)) {
        throw "Downloaded repo is missing installer\Install.ps1 under $projectRoot"
    }

    Write-Host '  Running installer...' -ForegroundColor Cyan
    Write-Host ''

    $psArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $installPs1
        '-InstallRoot', $InstallRoot
    )
    if ($SkipWizard) { $psArgs += '-SkipWizard' }
    if ($SkipTools) { $psArgs += '-SkipTools' }

    & powershell.exe @psArgs
    $code = $LASTEXITCODE
    if (($code -eq 0 -or $null -eq $code) -and (Test-Path -LiteralPath $InstallRoot)) {
        Set-InstalledRipDemonCommit -InstallRoot $InstallRoot -Commit $source.Commit
    }
    exit $code
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $workDir
}
