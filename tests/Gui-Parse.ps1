#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$gui = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\gui\RipDemon.Gui.ps1'
$code = Get-Content -LiteralPath $gui -Raw
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_.ToString() -ForegroundColor Red }
    exit 1
}
if ($code -match '[^\x00-\x7F]') {
    Write-Host 'FAIL: GUI still contains non-ASCII characters' -ForegroundColor Red
    exit 1
}
Write-Host 'GUI parse OK (ASCII-only).' -ForegroundColor Green

# Installed copy if present
$installed = Join-Path $env:LOCALAPPDATA 'RIP-Demon\gui\RipDemon.Gui.ps1'
if (Test-Path -LiteralPath $installed) {
    $icode = Get-Content -LiteralPath $installed -Raw
    $ierr = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($icode, [ref]$null, [ref]$ierr)
    if ($ierr -and $ierr.Count -gt 0) {
        Write-Host 'FAIL: installed GUI has parse errors' -ForegroundColor Red
        $ierr | ForEach-Object { Write-Host $_.ToString() -ForegroundColor Red }
        exit 1
    }
    Write-Host 'Installed GUI parse OK.' -ForegroundColor Green
}
exit 0
