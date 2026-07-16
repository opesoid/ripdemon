#Requires -Version 5.1
<#
.SYNOPSIS
  One-line installer: download RIP Demon from GitHub main and run Install.ps1.

.DESCRIPTION
  Recommended:

    irm https://raw.githubusercontent.com/opesoid/ripdemon/main/installer/web-install.ps1 | iex

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

function Import-RipDemonWebTools {
    $content = $null
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot '..\updater\RipDemon.Tools.ps1'
        if (Test-Path -LiteralPath $local) {
            $content = Get-Content -LiteralPath $local -Raw
        }
    }
    if (-not $content) {
        $url = 'https://raw.githubusercontent.com/opesoid/ripdemon/main/updater/RipDemon.Tools.ps1'
        $prev = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{
                    'User-Agent' = 'RIP-Demon'
                    'Accept'     = 'application/vnd.github.raw'
                }).Content
        }
        finally {
            $ProgressPreference = $prev
        }
    }
    if (-not $content -or $content.Length -lt 100) {
        throw 'Failed to load RipDemon.Tools.ps1 helper script.'
    }
    # Scriptblock avoids writing a temp .ps1 that Restricted policy would block.
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
