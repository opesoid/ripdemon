#Requires -Version 5.1
<#
.SYNOPSIS
  One-line installer: download RIP Demon from GitHub main and run Install.ps1.

.DESCRIPTION
  Recommended (jsDelivr — avoids stale GitHub raw CDN cache):

    irm https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/installer/web-install.ps1 | iex

  With flags (download first, then run):

    powershell -NoProfile -ExecutionPolicy Bypass -File .\web-install.ps1 -SkipWizard
#>
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'RIP-Demon'),
    [switch]$SkipTools,
    [switch]$SkipWizard
)

$ErrorActionPreference = 'Stop'

# irm|iex runs in the caller's session — Restricted policy blocks .ps1 on disk.
# Process scope only affects this PowerShell process (no admin, no permanent change).
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {
    # Continue; helpers load via scriptblock and Install.ps1 is launched with -ExecutionPolicy Bypass.
}

function Get-RipDemonRemoteText {
    param([Parameter(Mandatory)][string[]]$Urls)
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        foreach ($url in $Urls) {
            try {
                if ($url -match 'api\.github\.com/.+/contents/') {
                    $resp = Invoke-RestMethod -Uri $url -Headers @{
                        'User-Agent' = 'RIP-Demon'
                        'Accept'     = 'application/vnd.github+json'
                    }
                    if ($resp.content) {
                        $b64 = ($resp.content -replace '\s', '')
                        $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
                        if ($text -and $text.Length -gt 100) { return $text }
                    }
                }
                else {
                    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{
                        'User-Agent' = 'RIP-Demon'
                        'Cache-Control' = 'no-cache'
                    }
                    $text = if ($resp.Content -is [byte[]]) {
                        [Text.Encoding]::UTF8.GetString($resp.Content)
                    } else {
                        [string]$resp.Content
                    }
                    if ($text -and $text.Length -gt 100) { return $text }
                }
            } catch {
                # try next URL
            }
        }
    }
    finally {
        $ProgressPreference = $prev
    }
    throw 'Failed to download RipDemon.Tools.ps1 helper script.'
}

function Import-RipDemonWebTools {
    $content = $null
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot '..\updater\RipDemon.Tools.ps1'
        if (Test-Path -LiteralPath $local) {
            $content = Get-Content -LiteralPath $local -Raw
        }
    }
    if (-not $content) {
        # Prefer GitHub API / jsDelivr — raw.githubusercontent.com/main is often CDN-stale after pushes.
        $content = Get-RipDemonRemoteText -Urls @(
            'https://api.github.com/repos/opesoid/ripdemon/contents/updater/RipDemon.Tools.ps1?ref=main'
            'https://cdn.jsdelivr.net/gh/opesoid/ripdemon@main/updater/RipDemon.Tools.ps1'
            'https://raw.githubusercontent.com/opesoid/ripdemon/main/updater/RipDemon.Tools.ps1'
        )
    }
    . ([scriptblock]::Create($content))
}

Import-RipDemonWebTools

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

    # Child process with Bypass so Install.ps1 is not blocked by Restricted policy.
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
    if ($code -eq 0 -or $null -eq $code) {
        Set-InstalledRipDemonCommit -InstallRoot $InstallRoot -Commit $source.Commit
    }
    exit $code
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $workDir
}
