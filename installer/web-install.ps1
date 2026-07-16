#Requires -Version 5.1
<#
.SYNOPSIS
  One-line installer: download the latest RIP Demon release and run Install.ps1.

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

function Get-RipDemonWebToolsScript {
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot '..\updater\RipDemon.Tools.ps1'
        if (Test-Path -LiteralPath $local) { return (Resolve-Path -LiteralPath $local).Path }
    }
    $url = 'https://raw.githubusercontent.com/opesoid/ripdemon/main/updater/RipDemon.Tools.ps1'
    $tmp = Join-Path $env:TEMP ("RipDemon.Tools.{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers @{
            'User-Agent' = 'RIP-Demon'
            'Accept'     = 'application/vnd.github.raw'
        }
    }
    finally {
        $ProgressPreference = $prev
    }
    if (-not (Test-Path -LiteralPath $tmp) -or ((Get-Item -LiteralPath $tmp).Length -lt 100)) {
        throw "Failed to download RipDemon.Tools.ps1 from $url"
    }
    return $tmp
}

$toolsPath = Get-RipDemonWebToolsScript
$toolsIsTemp = $toolsPath -like (Join-Path $env:TEMP '*')
try {
    . $toolsPath

    Write-RipDemonBanner -Title 'RIP Demon Web Installer'

    try {
        Assert-RipDemonWindowsX64
    } catch {
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ''
        exit 1
    }

    Write-Host '  Fetching latest release from GitHub...' -ForegroundColor Cyan
    $latest = Get-RipDemonLatestRelease
    Write-Host "  Release:  $($latest.Tag) ($($latest.Name))" -ForegroundColor White
    Write-Host "  Target:   $InstallRoot"
    Write-Host ''

    $workDir = Join-Path $env:TEMP ("ripdemon-webinstall-{0}" -f [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $workDir $latest.Name
    $extractDir = Join-Path $workDir 'extract'

    try {
        New-Item -ItemType Directory -Force -Path $workDir, $extractDir | Out-Null

        $mb = if ($latest.Size) { '{0:N0} MB' -f ($latest.Size / 1MB) } else { $null }
        Save-RipDemonFile -Uri $latest.Url -OutFile $zipPath `
            -Label "Downloading $($latest.Name)" `
            -ExpectedSize $mb -ExpectedSha256 $latest.Sha256 -ExpectedByteSize $latest.Size

        Write-Host '  Extracting package...' -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $projectRoot = Resolve-RipDemonProjectRoot -ExtractDir $extractDir
        $installPs1 = Join-Path $projectRoot 'installer\Install.ps1'
        if (-not (Test-Path -LiteralPath $installPs1)) {
            throw "Release package is missing installer\Install.ps1 under $projectRoot"
        }

        Write-Host '  Running installer...' -ForegroundColor Cyan
        Write-Host ''
        $installArgs = @{
            InstallRoot = $InstallRoot
            SkipWizard  = $SkipWizard
            SkipTools   = $SkipTools
        }
        & $installPs1 @installArgs
        exit $LASTEXITCODE
    }
    finally {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $workDir
    }
}
finally {
    if ($toolsIsTemp) {
        Remove-Item -Force -ErrorAction SilentlyContinue $toolsPath
    }
}
