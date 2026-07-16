#Requires -Version 5.1
<#
.SYNOPSIS
  Uninstalls RIP Demon for the current user.
#>
param(
    [string]$InstallRoot,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Prefer the folder this script lives in (handles spaces in usernames like "Bill Clinton")
if (-not $InstallRoot) {
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'version.txt'))) {
        $InstallRoot = $PSScriptRoot
    } elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'bin\yt.cmd'))) {
        $InstallRoot = $PSScriptRoot
    } else {
        $InstallRoot = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
    }
}

$toolsPs1 = Join-Path $InstallRoot 'updater\RipDemon.Tools.ps1'
if (Test-Path -LiteralPath $toolsPs1) {
    . $toolsPs1
} else {
    function Write-RipDemonBanner { param($Title) Write-Host "`n  $Title`n" }
    function Remove-UserPathEntry {
        param([string]$Entry)
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $userPath) { return }
        $normalized = $Entry.TrimEnd('\')
        $parts = $userPath.Split(';') | Where-Object { $_ -and ($_.TrimEnd('\') -ine $normalized) }
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    }
    function Unregister-RipDemonUninstall {
        param([string]$InstallRoot)
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RIP-Demon'
        if (Test-Path -LiteralPath $key) {
            if ($InstallRoot) {
                try {
                    $registered = (Get-ItemProperty -LiteralPath $key).InstallLocation
                    if ($registered -and ($registered.TrimEnd('\') -ine $InstallRoot.TrimEnd('\'))) {
                        return $false
                    }
                } catch {}
            }
            Remove-Item -LiteralPath $key -Recurse -Force
        }
        return $true
    }
    function Remove-RipDemonStartMenu {
        param([string]$InstallRoot)
        $programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\RIP Demon'
        if (Test-Path -LiteralPath $programs) {
            Remove-Item -LiteralPath $programs -Recurse -Force
        }
    }
    function Clear-RipDemonShellLeftovers {
        param([switch]$Quiet)
        foreach ($ext in @('.txt', '.url', '.list')) {
            foreach ($verb in @('RIPDemonMP3', 'RIPDemonMP4')) {
                $path = "HKCU:\Software\Classes\$ext\shell\$verb"
                if (Test-Path -LiteralPath $path) {
                    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        $sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
        foreach ($name in @('RIP Demon MP3.lnk', 'RIP Demon MP4.lnk')) {
            $p = Join-Path $sendTo $name
            if (Test-Path -LiteralPath $p) {
                Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            }
        }
        $marker = 'HKCU:\Software\RIP-Demon'
        if (Test-Path -LiteralPath $marker) {
            Remove-Item -LiteralPath $marker -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not $Quiet) {
    Write-RipDemonBanner -Title 'RIP Demon Uninstaller'
    Write-Host "  This will remove: $InstallRoot"
    Write-Host ''
    $answer = Read-Host '  Type YES to uninstall'
    if ($answer -ne 'YES') {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

$binDir = Join-Path $InstallRoot 'bin'

Write-Host '  Removing PATH entry...' -ForegroundColor Cyan
Remove-UserPathEntry -Entry $binDir | Out-Null

if (Get-Command Clear-RipDemonShellLeftovers -ErrorAction SilentlyContinue) {
    Clear-RipDemonShellLeftovers -Quiet | Out-Null
}

Write-Host '  Removing Start Menu shortcuts...' -ForegroundColor Cyan
Remove-RipDemonStartMenu -InstallRoot $InstallRoot | Out-Null

Write-Host '  Unregistering Apps & features...' -ForegroundColor Cyan
Unregister-RipDemonUninstall -InstallRoot $InstallRoot | Out-Null

Write-Host '  Removing files...' -ForegroundColor Cyan
if (Test-Path -LiteralPath $InstallRoot) {
    try {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    } catch {
        Start-Sleep -Milliseconds 500
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host '  RIP Demon has been uninstalled.' -ForegroundColor Green
Write-Host '  Your downloaded MP3/MP4 files were kept.' -ForegroundColor DarkGray
Write-Host ''
if (-not $Quiet) {
    Write-Host '  Open a new terminal so PATH refreshes.'
    Write-Host ''
}
