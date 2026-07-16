#Requires -Version 5.1
<#
.SYNOPSIS
  Local smoke checks for RIP Demon (no tool downloads).
#>
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$failed = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  OK  $Message" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $Message" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ''
Write-Host 'RIP Demon smoke tests' -ForegroundColor Cyan
Write-Host ''

# --- Required repo files ---
$required = @(
    'VERSION',
    'README.md',
    'LICENSE',
    'CHANGELOG.md',
    'src\yt.cmd',
    'src\lib\ripdemon-config.cmd',
    'src\lib\RipDemon.Cli.ps1',
    'src\lib\RipDemon.Config.ps1',
    'src\lib\config.default.ini',
    'src\gui\RipDemon.Gui.ps1',
    'installer\Install.ps1',
    'installer\Install.cmd',
    'installer\Uninstall.ps1',
    'installer\Uninstall.cmd',
    'installer\Update.cmd',
    'updater\Update.ps1',
    'updater\RipDemon.Tools.ps1',
    'build\Build-Release.ps1',
    'build\RIP-Demon.iss'
)
foreach ($rel in $required) {
    Assert-True (Test-Path (Join-Path $ProjectRoot $rel)) "exists: $rel"
}

# --- VERSION / AppId sanity ---
$version = (Get-Content (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
Assert-True ($version -match '^\d+\.\d+\.\d+$') "VERSION is semver ($version)"

$iss = Get-Content (Join-Path $ProjectRoot 'build\RIP-Demon.iss') -Raw
Assert-True ($iss -match 'AppId=\{\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') 'Inno AppId is a valid GUID'
Assert-True ($iss -notmatch 'Update-AppFromGitHub|OWNER/RIP-Demon') 'Inno script has no self-update leftovers'
Assert-True ($iss -notmatch '\[Icons\]') 'Inno does not duplicate Start Menu [Icons]'

$tools = Get-Content (Join-Path $ProjectRoot 'updater\RipDemon.Tools.ps1') -Raw
Assert-True ($tools -notmatch 'function Update-AppFromGitHub') 'self-update function removed'
Assert-True ($tools -match 'Assert-RipDemonFileSha256') 'SHA256 verification present'
Assert-True ($tools -match 'ffmpeg\.version') 'ffmpeg version marker present'
Assert-True ($tools -match 'function Get-RipDemonOutputDirs') 'shared output dirs helper present'
Assert-True ($tools -notmatch 'function Register-RipDemonShellIntegration') 'shell Register removed'
Assert-True ($tools -match 'function Clear-RipDemonShellLeftovers') 'shell leftover cleanup present'
Assert-True ($tools -match 'function Invoke-RipDemonFirstRunWizard') 'first-run wizard present'
Assert-True ($tools -match "Publisher' -Value 'Opes'") 'Apps & features publisher is Opes'
Assert-True ($tools -match 'opes\.dev') 'branding URL opes.dev present'

$readme = Get-Content (Join-Path $ProjectRoot 'README.md') -Raw
Assert-True ($readme -match 'opes\.dev') 'README mentions opes.dev'
Assert-True ($readme -match 'Version 1\.0\.0|currently \*\*1\.0\.0\*\*|Version \| \*\*1\.0\.0\*\*') 'README documents 1.0.0'

$license = Get-Content (Join-Path $ProjectRoot 'LICENSE') -Raw
Assert-True ($license -match 'Opes') 'LICENSE copyright is Opes'

$update = Get-Content (Join-Path $ProjectRoot 'updater\Update.ps1') -Raw
Assert-True ($update -notmatch 'Update-AppFromGitHub') 'Update.ps1 does not call self-update'

$yt = Get-Content (Join-Path $ProjectRoot 'src\yt.cmd') -Raw
Assert-True ($yt -match 'RipDemon\.Cli\.ps1') 'yt.cmd forwards to RipDemon.Cli.ps1'
Assert-True ($yt -match 'version') 'yt.cmd supports version'

$cli = Get-Content (Join-Path $ProjectRoot 'src\lib\RipDemon.Cli.ps1') -Raw
Assert-True ($cli -match '--no-playlist') 'CLI supports --no-playlist'
Assert-True ($cli -match 'cookies-from-browser') 'CLI supports cookies-from-browser'
Assert-True ($cli -match 'output-dir') 'CLI supports --output-dir'
Assert-True ($cli -match '--open') 'CLI supports --open'
Assert-True ($cli -match 'Get-RipDemonClipboardText') 'CLI supports clipboard'
Assert-True ($cli -match 'sponsorblock') 'CLI supports sponsorblock'
Assert-True ($cli -match "'info'") 'CLI supports info command'

Assert-True (-not (Test-Path (Join-Path $ProjectRoot 'skills-lock.json'))) 'skills-lock.json removed'

# --- Config / Tools path agreement ---
. (Join-Path $ProjectRoot 'updater\RipDemon.Tools.ps1')
$dirs = Get-RipDemonOutputDirs
$config = Get-Content (Join-Path $ProjectRoot 'src\lib\ripdemon-config.cmd') -Raw
Assert-True ($config -match [regex]::Escape('Music\RIP Demon\MP3')) 'config mentions MP3 path'
Assert-True ($config -match [regex]::Escape('Videos\RIP Demon\MP4')) 'config mentions MP4 path'
Assert-True ($dirs.Mp3 -match 'Music\\RIP Demon\\MP3$') "Get-RipDemonOutputDirs MP3 ($($dirs.Mp3))"
Assert-True ($dirs.Mp4 -match 'Videos\\RIP Demon\\MP4$') "Get-RipDemonOutputDirs MP4 ($($dirs.Mp4))"

. (Join-Path $ProjectRoot 'src\lib\RipDemon.Config.ps1')
$cfgObj = Get-RipDemonConfig -InstallRoot (Join-Path $env:TEMP 'ripdemon-no-such') -DefaultConfigPath (Join-Path $ProjectRoot 'src\lib\config.default.ini')
Assert-True ($cfgObj.Quality -eq '1080') 'default quality is 1080'
Assert-True ($cfgObj.Mp3Dir -eq $dirs.Mp3) 'Config.ps1 default MP3 matches Tools'

# --- Fake install layout: help / unknown command exit codes ---
$fakeRoot = Join-Path $env:TEMP ("ripdemon-smoke-{0}" -f [guid]::NewGuid().ToString('N'))
$fakeBin = Join-Path $fakeRoot 'bin'
$fakeLib = Join-Path $fakeRoot 'lib'
$fakeGui = Join-Path $fakeRoot 'gui'
$fakeTools = Join-Path $fakeRoot 'tools'
$fakeUpdater = Join-Path $fakeRoot 'updater'
New-Item -ItemType Directory -Force -Path $fakeBin, $fakeLib, $fakeGui, $fakeTools, $fakeUpdater | Out-Null
Copy-Item (Join-Path $ProjectRoot 'src\yt.cmd') (Join-Path $fakeBin 'yt.cmd')
Copy-Item (Join-Path $ProjectRoot 'src\lib\*') $fakeLib
Copy-Item (Join-Path $ProjectRoot 'src\gui\*') $fakeGui
Set-Content -Path (Join-Path $fakeRoot 'version.txt') -Value $version -NoNewline
Write-RipDemonUserConfig -InstallRoot $fakeRoot | Out-Null

$ytCmd = Join-Path $fakeBin 'yt.cmd'
cmd /c "`"$ytCmd`" help" | Out-Null
Assert-True ($LASTEXITCODE -eq 0) 'yt help exits 0'

cmd /c "`"$ytCmd`" nosuchcommand" 2>$null | Out-Null
Assert-True ($LASTEXITCODE -ne 0) 'yt unknown command exits non-zero'

cmd /c "`"$ytCmd`" config" | Out-Null
Assert-True ($LASTEXITCODE -eq 0) 'yt config exits 0'

# mp3 with no URL and empty-ish clipboard should fail (no yt-dlp either if URL somehow present)
cmd /c "`"$ytCmd`" mp3" 2>$null | Out-Null
Assert-True ($LASTEXITCODE -ne 0) 'yt mp3 without usable URL exits non-zero'

cmd /c "`"$ytCmd`" version" | Out-Null
Assert-True ($LASTEXITCODE -eq 0) 'yt version exits 0'

Remove-Item -Recurse -Force $fakeRoot -ErrorAction SilentlyContinue

# --- Release zip contents (optional) ---
if (-not $SkipBuild) {
    Write-Host ''
    Write-Host 'Building release zip...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot 'build\Build-Release.ps1')
    $zip = Join-Path $ProjectRoot "dist\RIP-Demon-$version-windows.zip"
    Assert-True (Test-Path $zip) "release zip exists ($zip)"

    $probe = Join-Path $env:TEMP ("ripdemon-zip-{0}" -f [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $probe | Out-Null
    Expand-Archive -Path $zip -DestinationPath $probe -Force
    $stage = Get-ChildItem $probe -Directory | Select-Object -First 1
    Assert-True ($null -ne $stage) 'zip has staged folder'
    if ($stage) {
        foreach ($inner in @(
                'Install.cmd',
                'VERSION',
                'src\yt.cmd',
                'src\lib\RipDemon.Cli.ps1',
                'src\gui\RipDemon.Gui.ps1',
                'installer\Install.ps1',
                'updater\RipDemon.Tools.ps1',
                'LICENSE'
            )) {
            Assert-True (Test-Path (Join-Path $stage.FullName $inner)) "zip contains $inner"
        }
    }
    Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "FAILED: $failed check(s)" -ForegroundColor Red
    exit 1
}
Write-Host 'All smoke checks passed.' -ForegroundColor Green
exit 0
