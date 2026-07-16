#Requires -Version 5.1
<#
.SYNOPSIS
  Regression: web-install must work when executed via iex/scriptblock (not -File).
#>
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$webInstall = Join-Path $ProjectRoot 'installer\web-install.ps1'
$installRoot = Join-Path $env:TEMP ("ripdemon-iex-test-{0}" -f [guid]::NewGuid().ToString('N'))

Write-Host 'Testing web-install via child iex/scriptblock (same path as irm|iex)...' -ForegroundColor Cyan

# Child process: web-install calls exit, which would kill this harness if in-process.
$child = @"
`$ErrorActionPreference = 'Stop'
`$src = Get-Content -LiteralPath '$($webInstall.Replace("'", "''"))' -Raw
& ([scriptblock]::Create(`$src)) -SkipWizard -SkipTools -InstallRoot '$($installRoot.Replace("'", "''"))'
"@

& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $child
if ($LASTEXITCODE -ne 0) {
    throw "FAIL: web-install child exited $LASTEXITCODE"
}

$yt = Join-Path $installRoot 'bin\yt.cmd'
if (-not (Test-Path -LiteralPath $yt)) {
    throw "FAIL: missing $yt"
}
$tools = Join-Path $installRoot 'updater\RipDemon.Tools.ps1'
if (-not (Test-Path -LiteralPath $tools)) {
    throw "FAIL: missing $tools"
}

Write-Host 'Running yt version...' -ForegroundColor Cyan
& cmd.exe /c "`"$yt`" version"
if ($LASTEXITCODE -ne 0) {
    throw "FAIL: yt version exited $LASTEXITCODE"
}

# Clean install artifacts from this test root
$unin = Join-Path $installRoot 'Uninstall.ps1'
if (Test-Path -LiteralPath $unin) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $unin -Quiet
}
Remove-Item -Recurse -Force $installRoot -ErrorAction SilentlyContinue
Write-Host 'Web-install iex path OK.' -ForegroundColor Green
