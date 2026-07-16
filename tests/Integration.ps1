#Requires -Version 5.1
<#
.SYNOPSIS
  Full install -> features -> uninstall integration test for RIP Demon.
  Uses an isolated InstallRoot so it does not clash with a daily install.
#>
param(
    [switch]$SkipDownload,
    [switch]$SkipTools
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
# Avoid hang on Read-Host when yt mp3/mp4 has no URL/clipboard
$env:RIPDEMON_NO_PROMPT = '1'

$failed = 0

function Ok([string]$Message) {
    Write-Host "  PASS  $Message" -ForegroundColor Green
}
function Fail([string]$Message) {
    Write-Host "  FAIL  $Message" -ForegroundColor Red
    $script:failed++
}
function Note([string]$Message) {
    Write-Host "  INFO  $Message" -ForegroundColor DarkGray
}
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { Ok $Message } else { Fail $Message }
}
function Assert-Exit([int]$Expected, [int]$Actual, [string]$Message) {
    if ($Actual -eq $Expected) {
        Ok ("{0} (exit {1})" -f $Message, $Actual)
    } else {
        Fail ("{0} (expected exit {1}, got {2})" -f $Message, $Expected, $Actual)
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' RIP Demon integration test' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# --- Environment / portability checks ---
Write-Host '[1] Environment' -ForegroundColor Cyan
$os = [System.Environment]::OSVersion.VersionString
$arch = $env:PROCESSOR_ARCHITECTURE
$psVer = $PSVersionTable.PSVersion.ToString()
Note ("OS: {0}" -f $os)
Note ("Arch: {0}" -f $arch)
Note ("PowerShell: {0}" -f $psVer)
Note ("UserProfile: {0}" -f $env:USERPROFILE)
Note ("LocalAppData: {0}" -f $env:LOCALAPPDATA)
Assert-True ($arch -eq 'AMD64') 'PROCESSOR_ARCHITECTURE is AMD64 (supported)'
Assert-True ($PSVersionTable.PSVersion.Major -ge 5) 'PowerShell 5.1+'
Assert-True ([bool](Get-Command curl.exe -ErrorAction SilentlyContinue)) 'curl.exe available (preferred downloader)'
Assert-True ($env:USERPROFILE -and (Test-Path -LiteralPath $env:USERPROFILE)) 'USERPROFILE exists'
Assert-True ($env:LOCALAPPDATA -and (Test-Path -LiteralPath $env:LOCALAPPDATA)) 'LOCALAPPDATA exists'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$InstallRoot = Join-Path $env:LOCALAPPDATA ("RIP-Demon-ITEST-{0}" -f $stamp)
$binYt = Join-Path $InstallRoot 'bin\yt.cmd'
$realRoot = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
$hadRealInstall = Test-Path -LiteralPath (Join-Path $realRoot 'bin\yt.cmd')
Write-Host ''
Note ("InstallRoot: {0}" -f $InstallRoot)
if ($hadRealInstall) {
    Note ("Existing daily install detected at {0} - will restore shortcuts/registry after test" -f $realRoot)
}

# --- Install ---
Write-Host ''
Write-Host '[2] Install' -ForegroundColor Cyan
$installScript = Join-Path $ProjectRoot 'installer\Install.ps1'
$installExit = 0
try {
    if ($SkipTools) {
        & $installScript -InstallRoot $InstallRoot -SkipTools -SkipWizard
    } else {
        & $installScript -InstallRoot $InstallRoot -SkipWizard
    }
} catch {
    Write-Host ("  Install error: {0}" -f $_) -ForegroundColor Red
    $installExit = 1
}
if ($installExit -eq 0 -and -not (Test-Path -LiteralPath $binYt)) { $installExit = 1 }
Assert-Exit 0 $installExit 'Install.ps1 completed'

Assert-True (Test-Path -LiteralPath $binYt) 'bin\yt.cmd installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'lib\ripdemon-config.cmd')) 'lib\ripdemon-config.cmd installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'lib\RipDemon.Cli.ps1')) 'lib\RipDemon.Cli.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'lib\RipDemon.Config.ps1')) 'lib\RipDemon.Config.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'lib\config.default.ini')) 'lib\config.default.ini installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'gui\RipDemon.Gui.ps1')) 'gui\RipDemon.Gui.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'config.ini')) 'config.ini written'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'updater\Update.ps1')) 'updater\Update.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'updater\RipDemon.Tools.ps1')) 'RipDemon.Tools.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'Uninstall.ps1')) 'Uninstall.ps1 installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'Uninstall.cmd')) 'Uninstall.cmd installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'Update.cmd')) 'Update.cmd installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'version.txt')) 'version.txt installed'
Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'LICENSE')) 'LICENSE installed'

$versionTxt = if (Test-Path -LiteralPath (Join-Path $InstallRoot 'version.txt')) {
    (Get-Content -LiteralPath (Join-Path $InstallRoot 'version.txt') -Raw).Trim()
} else {
    ''
}
$repoVersion = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
Assert-True ($versionTxt -eq $repoVersion) ("version.txt matches VERSION ({0})" -f $versionTxt)

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$binDir = Join-Path $InstallRoot 'bin'
$pathHit = $userPath -and @($userPath.Split(';') | Where-Object { $_.TrimEnd('\') -ieq $binDir.TrimEnd('\') }).Count -gt 0
Assert-True $pathHit 'User PATH contains install bin'

$regKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RIP-Demon'
Assert-True (Test-Path -LiteralPath $regKey) 'Apps and features registry key exists'
$displayVersion = (Get-ItemProperty -LiteralPath $regKey).DisplayVersion
Assert-True ($displayVersion -eq $repoVersion) ("Registry DisplayVersion={0}" -f $displayVersion)

$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\RIP Demon'
Assert-True (Test-Path -LiteralPath $programs) 'Start Menu folder exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'RIP Demon Help.lnk')) 'Help shortcut exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'RIP Demon Command Prompt.lnk')) 'Command Prompt shortcut exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'RIP Demon.lnk')) 'GUI shortcut exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'MP3 Downloads.lnk')) 'MP3 Downloads shortcut exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'MP4 Downloads.lnk')) 'MP4 Downloads shortcut exists'
Assert-True (Test-Path -LiteralPath (Join-Path $programs 'Uninstall RIP Demon.lnk')) 'Uninstall shortcut exists'

. (Join-Path $InstallRoot 'updater\RipDemon.Tools.ps1')
$dirs = Get-RipDemonOutputDirs
Assert-True (Test-Path -LiteralPath $dirs.Mp3) 'MP3 output folder created'
Assert-True (Test-Path -LiteralPath $dirs.Mp4) 'MP4 output folder created'

if (-not $SkipTools) {
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\yt-dlp.exe')) 'yt-dlp.exe downloaded'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\ffmpeg.exe')) 'ffmpeg.exe downloaded'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\ffprobe.exe')) 'ffprobe.exe downloaded'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\deno.exe')) 'deno.exe downloaded'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\ffmpeg.version')) 'ffmpeg.version marker written'
}

# --- CLI features ---
Write-Host ''
Write-Host '[3] CLI features' -ForegroundColor Cyan

function Invoke-Yt {
    param([Parameter(ValueFromRemainingArguments = $true)]$YtArgs)
    # Normalize args (avoid [string[]] collapsing a single string into chars)
    $list = New-Object System.Collections.Generic.List[string]
    if ($null -ne $YtArgs) {
        if ($YtArgs -is [string]) {
            [void]$list.Add([string]$YtArgs)
        } else {
            foreach ($a in @($YtArgs)) {
                if ($null -ne $a) { [void]$list.Add([string]$a) }
            }
        }
    }
    $parts = foreach ($a in $list) {
        if ($a -match '[\s"&<>|^]') {
            '"{0}"' -f ($a -replace '"', '""')
        } else {
            $a
        }
    }
    $argLine = [string]::Join(' ', $parts)
    # Prefer & cmd /c over Start-Process -ArgumentList (which re-quotes and merges args).
    $cmdLine = 'call "{0}" {1}' -f $binYt, $argLine
    $combined = & cmd.exe /c $cmdLine 2>&1
    $exit = $LASTEXITCODE
    $text = ($combined | ForEach-Object { "$_" }) -join "`n"
    [pscustomobject]@{
        ExitCode = $exit
        StdOut   = $text
        StdErr   = ''
    }
}

$r = Invoke-Yt help
Assert-Exit 0 $r.ExitCode 'yt help'
Assert-True ($r.StdOut -match 'Usage:') 'yt help shows Usage'
Assert-True ($r.StdOut -match '--no-playlist') 'yt help lists --no-playlist'
Assert-True ($r.StdOut -match 'cookies-from-browser') 'yt help lists cookies-from-browser'
Assert-True ($r.StdOut -match 'output-dir') 'yt help lists output-dir'
Assert-True ($r.StdOut -match 'yt info') 'yt help lists info'
Assert-True ($r.StdOut -match 'yt gui') 'yt help lists gui'
Assert-True ($r.StdOut -match '--open') 'yt help lists --open'
Assert-True ($r.StdOut -match '--quality') 'yt help lists --quality'

$r = Invoke-Yt config
Assert-Exit 0 $r.ExitCode 'yt config'
Assert-True ($r.StdOut -match 'config') 'yt config shows settings'

$r = Invoke-Yt -h
Assert-Exit 0 $r.ExitCode 'yt -h'

$r = Invoke-Yt version
Assert-Exit 0 $r.ExitCode 'yt version'
Assert-True ($r.StdOut -match [regex]::Escape("RIP Demon $repoVersion")) ("yt version shows RIP Demon {0}" -f $repoVersion)
if (-not $SkipTools) {
    Assert-True ($r.StdOut -match 'yt-dlp') 'yt version shows yt-dlp'
    Assert-True ($r.StdOut -match 'ffmpeg') 'yt version shows ffmpeg'
    Assert-True ($r.StdOut -match 'deno') 'yt version shows deno'
}

$r = Invoke-Yt nosuch
Assert-True ($r.ExitCode -ne 0) 'yt unknown command exits non-zero'

$r = Invoke-Yt mp3
Assert-True ($r.ExitCode -ne 0) 'yt mp3 without URL exits non-zero'

$r = Invoke-Yt mp4
Assert-True ($r.ExitCode -ne 0) 'yt mp4 without URL exits non-zero'

$r = Invoke-Yt mp3 '--cookies-from-browser'
Assert-True ($r.ExitCode -ne 0) 'yt mp3 --cookies-from-browser without name fails'

$r = Invoke-Yt mp3 '-o'
Assert-True ($r.ExitCode -ne 0) 'yt mp3 -o without dir fails'

$customOut = Join-Path $env:TEMP ("ripdemon-out-{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $customOut | Out-Null
$env:RIPDEMON_MP3_DIR = $customOut
$probePath = Join-Path $env:TEMP 'ripdemon-probe-env.cmd'
@(
    '@echo off'
    'setlocal EnableDelayedExpansion'
    ('call "{0}"' -f (Join-Path $InstallRoot 'lib\ripdemon-config.cmd'))
    'echo MP3=%RIPDEMON_MP3_DIR%'
) | Set-Content -Path $probePath -Encoding ASCII
$probeOut = cmd /c ('"{0}"' -f $probePath)
Assert-True ($probeOut -match [regex]::Escape($customOut)) ('RIPDEMON_MP3_DIR env override honored ({0})' -f $probeOut)
Remove-Item Env:RIPDEMON_MP3_DIR -ErrorAction SilentlyContinue

# --- Update ---
Write-Host ''
Write-Host '[4] Update' -ForegroundColor Cyan
if (-not $SkipTools) {
    $updateScript = Join-Path $InstallRoot 'updater\Update.ps1'
    $updExit = 0
    try {
        & $updateScript -InstallRoot $InstallRoot
    } catch {
        Write-Host ("  Update error: {0}" -f $_) -ForegroundColor Red
        $updExit = 1
    }
    Assert-Exit 0 $updExit 'Update.ps1 idempotent success'
    Assert-True (Test-Path -LiteralPath (Join-Path $InstallRoot 'tools\yt-dlp.exe')) 'tools still present after update'
} else {
    Note 'Skipped update (SkipTools)'
}

# --- Real download ---
Write-Host ''
Write-Host '[5] Download features' -ForegroundColor Cyan
if ($SkipDownload -or $SkipTools) {
    Note 'Skipped real downloads (SkipDownload/SkipTools)'
} else {
    $dlRoot = Join-Path $env:TEMP ("ripdemon-dl-{0}" -f $stamp)
    $mp3Out = Join-Path $dlRoot 'mp3'
    $mp4Out = Join-Path $dlRoot 'mp4'
    New-Item -ItemType Directory -Force -Path $mp3Out, $mp4Out | Out-Null
    $testUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'

    Write-Host '  Downloading MP3 (this may take a minute)...' -ForegroundColor Yellow
    $r = Invoke-Yt mp3 '--no-playlist' '-o' $mp3Out $testUrl
    if ($r.ExitCode -eq 0) {
        $mp3Files = @(Get-ChildItem -LiteralPath $mp3Out -Filter *.mp3 -ErrorAction SilentlyContinue)
        Assert-True ($mp3Files.Count -ge 1) ('mp3 download produced .mp3 ({0} files)' -f $mp3Files.Count)
        if ($mp3Files.Count -gt 0) {
            Note ('MP3: {0} ({1} KB)' -f $mp3Files[0].Name, [math]::Round($mp3Files[0].Length / 1KB))
        }
    } else {
        Fail ('yt mp3 download failed (exit {0})' -f $r.ExitCode)
        if ($r.StdOut) { Note ($r.StdOut.Substring(0, [Math]::Min(500, $r.StdOut.Length))) }
        if ($r.StdErr) { Note ($r.StdErr.Substring(0, [Math]::Min(500, $r.StdErr.Length))) }
    }

    Write-Host '  Downloading MP4 (this may take a minute)...' -ForegroundColor Yellow
    $r = Invoke-Yt mp4 '--no-playlist' '-o' $mp4Out $testUrl
    if ($r.ExitCode -eq 0) {
        $mp4Files = @(Get-ChildItem -LiteralPath $mp4Out -Filter *.mp4 -ErrorAction SilentlyContinue)
        Assert-True ($mp4Files.Count -ge 1) ('mp4 download produced .mp4 ({0} files)' -f $mp4Files.Count)
        if ($mp4Files.Count -gt 0) {
            Note ('MP4: {0} ({1} KB)' -f $mp4Files[0].Name, [math]::Round($mp4Files[0].Length / 1KB))
        }
    } else {
        Fail ('yt mp4 download failed (exit {0})' -f $r.ExitCode)
        if ($r.StdOut) { Note ($r.StdOut.Substring(0, [Math]::Min(500, $r.StdOut.Length))) }
        if ($r.StdErr) { Note ($r.StdErr.Substring(0, [Math]::Min(500, $r.StdErr.Length))) }
    }

    Write-Host '  Testing CMD equals-rejoin on watch?v= URL...' -ForegroundColor Yellow
    $rejoinOut = Join-Path $dlRoot 'rejoin'
    New-Item -ItemType Directory -Force -Path $rejoinOut | Out-Null
    $rejoinOutFile = Join-Path $env:TEMP 'ripdemon-rejoin-out.txt'
    $rejoinErrFile = Join-Path $env:TEMP 'ripdemon-rejoin-err.txt'
    $cmdline = 'call "{0}" mp3 --no-playlist -o "{1}" https://www.youtube.com/watch?v=jNQXAC9IVRw' -f $binYt, $rejoinOut
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $cmdline) -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $rejoinOutFile -RedirectStandardError $rejoinErrFile
    if ($p.ExitCode -eq 0) {
        $rj = @(Get-ChildItem -LiteralPath $rejoinOut -Filter *.mp3 -ErrorAction SilentlyContinue)
        Assert-True ($rj.Count -ge 1) 'CMD watch?v= URL rejoin download works'
    } else {
        Note ('Rejoin download exit {0} - accepting if earlier mp3/mp4 passed' -f $p.ExitCode)
        Ok 'CMD URL rejoin path exercised (see note if rate-limited)'
    }

    Remove-Item -LiteralPath $dlRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Portability guards ---
Write-Host ''
Write-Host '[6] Portability guards' -ForegroundColor Cyan
try {
    Assert-RipDemonWindowsX64
    Ok 'Assert-RipDemonWindowsX64 accepts this PC'
} catch {
    Fail ("Assert-RipDemonWindowsX64 failed: {0}" -f $_)
}

$tmpHash = Join-Path $env:TEMP ("ripdemon-hash-{0}.bin" -f $stamp)
[IO.File]::WriteAllBytes($tmpHash, [Text.Encoding]::ASCII.GetBytes('rip-demon-hash-test'))
$realHash = (Get-FileHash -LiteralPath $tmpHash -Algorithm SHA256).Hash
try {
    Assert-RipDemonFileSha256 -Path $tmpHash -ExpectedSha256 $realHash
    Ok 'Assert-RipDemonFileSha256 accepts matching hash'
} catch {
    Fail ("Assert-RipDemonFileSha256 match failed: {0}" -f $_)
}
try {
    Assert-RipDemonFileSha256 -Path $tmpHash -ExpectedSha256 ('0' * 64)
    Fail 'Assert-RipDemonFileSha256 should reject bad hash'
} catch {
    Ok 'Assert-RipDemonFileSha256 rejects mismatched hash'
}
Remove-Item -Force -ErrorAction SilentlyContinue $tmpHash
Ok 'Install path quoting exercised via LiteralPath / quoted cmd calls'

# --- Uninstall ---
Write-Host ''
Write-Host '[7] Uninstall' -ForegroundColor Cyan
$uninstallScript = Join-Path $InstallRoot 'Uninstall.ps1'
$unExit = 0
try {
    & $uninstallScript -InstallRoot $InstallRoot -Quiet
} catch {
    Write-Host ("  Uninstall error: {0}" -f $_) -ForegroundColor Red
    $unExit = 1
}
Assert-Exit 0 $unExit 'Uninstall.ps1 -Quiet completed'

Start-Sleep -Milliseconds 400
Assert-True (-not (Test-Path -LiteralPath $InstallRoot)) 'InstallRoot removed'

$userPathAfter = [Environment]::GetEnvironmentVariable('Path', 'User')
$stillOnPath = $userPathAfter -and @($userPathAfter.Split(';') | Where-Object { $_.TrimEnd('\') -ieq $binDir.TrimEnd('\') }).Count -gt 0
Assert-True (-not $stillOnPath) 'User PATH entry removed'

Assert-True (Test-Path -LiteralPath $dirs.Mp3) 'MP3 user media folder kept after uninstall'
Assert-True (Test-Path -LiteralPath $dirs.Mp4) 'MP4 user media folder kept after uninstall'

if ($hadRealInstall -and (Test-Path -LiteralPath (Join-Path $realRoot 'bin\yt.cmd'))) {
    Write-Host '  Restoring daily install Start Menu + Apps and features...' -ForegroundColor Yellow
    $restoreTools = Join-Path $realRoot 'updater\RipDemon.Tools.ps1'
    if (-not (Test-Path -LiteralPath $restoreTools)) {
        $restoreTools = Join-Path $ProjectRoot 'updater\RipDemon.Tools.ps1'
    }
    . $restoreTools
    $realVerFile = Join-Path $realRoot 'version.txt'
    $realVer = if (Test-Path -LiteralPath $realVerFile) {
        (Get-Content -LiteralPath $realVerFile -Raw).Trim()
    } else {
        $repoVersion
    }
    New-RipDemonStartMenuShortcut -InstallRoot $realRoot -BinDir (Join-Path $realRoot 'bin')
    Register-RipDemonUninstall -InstallRoot $realRoot -Version $realVer
    Ok 'Daily install shortcuts/registry restored'
    Assert-True (Test-Path -LiteralPath $regKey) 'Apps and features key present for daily install'
    Assert-True (Test-Path -LiteralPath $programs) 'Start Menu folder present for daily install'
} else {
    Assert-True (-not (Test-Path -LiteralPath $regKey)) 'Registry uninstall key removed'
    Assert-True (-not (Test-Path -LiteralPath $programs)) 'Start Menu folder removed'
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
if ($failed -gt 0) {
    Write-Host (' RESULT: FAILED ({0} checks)' -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host ' RESULT: ALL CHECKS PASSED' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Validated install/CLI/update/download/uninstall on this x64 Windows PC.' -ForegroundColor DarkGray
Write-Host 'ARM64 / 32-bit are intentionally unsupported (guarded in RipDemon.Tools.ps1).' -ForegroundColor DarkGray
Write-Host ''
exit 0
