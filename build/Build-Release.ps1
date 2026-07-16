#Requires -Version 5.1
<#
.SYNOPSIS
  Packs a local Windows release zip (and optionally builds Inno Setup installer).
#>
param()

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
$distDir = Join-Path $ProjectRoot 'dist'
$stageName = "RIP-Demon-$version-windows"
$stageDir = Join-Path $distDir $stageName
$zipPath = Join-Path $distDir "$stageName.zip"

Write-Host "Building RIP Demon $version ..." -ForegroundColor Cyan

if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Stage release contents
$copyMap = @(
    @{ Src = 'VERSION'; Dst = 'VERSION' }
    @{ Src = 'README.md'; Dst = 'README.md' }
    @{ Src = 'LICENSE'; Dst = 'LICENSE' }
    @{ Src = 'CHANGELOG.md'; Dst = 'CHANGELOG.md' }
    @{ Src = 'src'; Dst = 'src' }
    @{ Src = 'installer'; Dst = 'installer' }
    @{ Src = 'updater'; Dst = 'updater' }
    @{ Src = 'build\RIP-Demon.iss'; Dst = 'build\RIP-Demon.iss' }
)

foreach ($item in $copyMap) {
    $src = Join-Path $ProjectRoot $item.Src
    $dst = Join-Path $stageDir $item.Dst
    $dstParent = Split-Path -Parent $dst
    if (-not (Test-Path $dstParent)) {
        New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
    }
    if (-not (Test-Path $src)) {
        Write-Host "  Skipping missing: $($item.Src)" -ForegroundColor DarkYellow
        continue
    }
    if (Test-Path $src -PathType Container) {
        Copy-Item -Recurse -Force $src $dst
    } else {
        Copy-Item -Force $src $dst
    }
}

# Root launcher for unzipped users
$rootInstall = @"
@echo off
cd /d "%~dp0"
call "%~dp0installer\Install.cmd" %*
"@
Set-Content -Path (Join-Path $stageDir 'Install.cmd') -Value $rootInstall -Encoding ASCII

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path $stageDir -DestinationPath $zipPath -Force
Write-Host "Created: $zipPath" -ForegroundColor Green

# Optional Inno Setup compile
$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$setupPath = Join-Path $distDir "RIP-Demon-Setup-$version.exe"
if ($iscc) {
    Write-Host "Compiling Inno Setup installer..." -ForegroundColor Cyan
    $iss = Join-Path $ProjectRoot 'build\RIP-Demon.iss'
    & $iscc "/DMyAppVersion=$version" $iss
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Inno Setup build OK." -ForegroundColor Green
    } else {
        Write-Host "Inno Setup build failed (exit $LASTEXITCODE)." -ForegroundColor Yellow
    }
} else {
    Write-Host "Inno Setup not found - skipped Setup.exe (zip is ready)." -ForegroundColor DarkGray
}

# SHA256SUMS.txt for web install / self-update verification
$sumsPath = Join-Path $distDir 'SHA256SUMS.txt'
$sumsLines = New-Object System.Collections.Generic.List[string]
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sumsLines.Add("$zipHash  $(Split-Path -Leaf $zipPath)")
if (Test-Path -LiteralPath $setupPath) {
    $setupHash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumsLines.Add("$setupHash  $(Split-Path -Leaf $setupPath)")
}
Set-Content -Path $sumsPath -Value ($sumsLines -join "`n") -Encoding ascii -NoNewline
Add-Content -Path $sumsPath -Value "`n" -Encoding ascii
Write-Host "Created: $sumsPath" -ForegroundColor Green

# Cleanup stage folder (keep zip + sums)
Remove-Item -Recurse -Force $stageDir
Write-Host "Done." -ForegroundColor Green
