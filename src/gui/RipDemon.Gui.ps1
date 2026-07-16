#Requires -Version 5.1
<#
.SYNOPSIS
  Minimal WinForms download window for RIP Demon.
#>
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$GuiDir = $PSScriptRoot
$InstallRoot = Split-Path -Parent $GuiDir
# Repo layout: src\gui -> parent is src, install root is parent of src
if (-not (Test-Path (Join-Path $InstallRoot 'bin\yt.cmd'))) {
    $maybe = Split-Path -Parent $InstallRoot
    if (Test-Path (Join-Path $maybe 'bin\yt.cmd')) { $InstallRoot = $maybe }
    elseif (Test-Path (Join-Path $InstallRoot 'yt.cmd')) {
        # running from repo src\gui with no install — use LOCALAPPDATA if present
        $fallback = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
        if (Test-Path (Join-Path $fallback 'bin\yt.cmd')) { $InstallRoot = $fallback }
    }
}

$LibDir = Join-Path $InstallRoot 'lib'
if (-not (Test-Path (Join-Path $LibDir 'RipDemon.Config.ps1'))) {
    $LibDir = Join-Path (Split-Path -Parent $GuiDir) 'lib'
}
. (Join-Path $LibDir 'RipDemon.Config.ps1')

$YtCmd = Join-Path $InstallRoot 'bin\yt.cmd'
if (-not (Test-Path -LiteralPath $YtCmd)) {
    [System.Windows.Forms.MessageBox]::Show(
        "RIP Demon is not installed (missing bin\yt.cmd).`nRun Install.cmd first.",
        'RIP Demon',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}

$cfg = Get-RipDemonConfig -InstallRoot $InstallRoot -DefaultConfigPath (Join-Path $LibDir 'config.default.ini')

function Get-ClipboardUrl {
    try {
        $t = [System.Windows.Forms.Clipboard]::GetText()
        if (-not $t) { return '' }
        $first = ($t -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1
        if ($first -match '^https?://' -or $first -match 'youtube\.com|youtu\.be') { return $first }
    } catch {}
    return ''
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'RIP Demon'
$form.Size = New-Object System.Drawing.Size(560, 380)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'RIP Demon'
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$lblTitle.Location = New-Object System.Drawing.Point(16, 12)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$lblBrand = New-Object System.Windows.Forms.LinkLabel
$lblBrand.Text = 'by Opes - opes.dev'
$lblBrand.Location = New-Object System.Drawing.Point(140, 18)
$lblBrand.AutoSize = $true
$lblBrand.LinkColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblBrand.ActiveLinkColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
$lblBrand.Add_LinkClicked({ Start-Process 'https://opes.dev' })
$form.Controls.Add($lblBrand)

$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = 'URL'
$lblUrl.Location = New-Object System.Drawing.Point(16, 52)
$lblUrl.AutoSize = $true
$form.Controls.Add($lblUrl)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(16, 72)
$txtUrl.Size = New-Object System.Drawing.Size(510, 24)
$txtUrl.Text = Get-ClipboardUrl
$form.Controls.Add($txtUrl)

$grpMode = New-Object System.Windows.Forms.GroupBox
$grpMode.Text = 'Format'
$grpMode.Location = New-Object System.Drawing.Point(16, 110)
$grpMode.Size = New-Object System.Drawing.Size(160, 70)
$form.Controls.Add($grpMode)

$rbMp3 = New-Object System.Windows.Forms.RadioButton
$rbMp3.Text = 'MP3'
$rbMp3.Location = New-Object System.Drawing.Point(16, 28)
$rbMp3.Checked = $true
$grpMode.Controls.Add($rbMp3)

$rbMp4 = New-Object System.Windows.Forms.RadioButton
$rbMp4.Text = 'MP4'
$rbMp4.Location = New-Object System.Drawing.Point(80, 28)
$grpMode.Controls.Add($rbMp4)

$lblQ = New-Object System.Windows.Forms.Label
$lblQ.Text = 'MP4 quality'
$lblQ.Location = New-Object System.Drawing.Point(200, 120)
$lblQ.AutoSize = $true
$form.Controls.Add($lblQ)

$cmbQuality = New-Object System.Windows.Forms.ComboBox
$cmbQuality.DropDownStyle = 'DropDownList'
$cmbQuality.Location = New-Object System.Drawing.Point(200, 142)
$cmbQuality.Size = New-Object System.Drawing.Size(120, 24)
[void]$cmbQuality.Items.AddRange(@('720', '1080', 'best'))
$qi = @('720', '1080', 'best').IndexOf($cfg.Quality)
if ($qi -lt 0) { $qi = 1 }
$cmbQuality.SelectedIndex = $qi
$form.Controls.Add($cmbQuality)

$chkOpen = New-Object System.Windows.Forms.CheckBox
$chkOpen.Text = 'Open folder when done'
$chkOpen.Location = New-Object System.Drawing.Point(340, 120)
$chkOpen.AutoSize = $true
$chkOpen.Checked = [bool]$cfg.OpenAfter
$form.Controls.Add($chkOpen)

$chkNoPl = New-Object System.Windows.Forms.CheckBox
$chkNoPl.Text = 'No playlist'
$chkNoPl.Location = New-Object System.Drawing.Point(340, 148)
$chkNoPl.AutoSize = $true
$chkNoPl.Checked = [bool]$cfg.NoPlaylist
$form.Controls.Add($chkNoPl)

$lblCookies = New-Object System.Windows.Forms.Label
$lblCookies.Text = 'Cookies browser (optional)'
$lblCookies.Location = New-Object System.Drawing.Point(16, 196)
$lblCookies.AutoSize = $true
$form.Controls.Add($lblCookies)

$cmbCookies = New-Object System.Windows.Forms.ComboBox
$cmbCookies.DropDownStyle = 'DropDown'
$cmbCookies.Location = New-Object System.Drawing.Point(16, 216)
$cmbCookies.Size = New-Object System.Drawing.Size(160, 24)
[void]$cmbCookies.Items.AddRange(@('', 'chrome', 'edge', 'firefox', 'brave', 'opera'))
$cmbCookies.Text = $cfg.CookiesBrowser
$form.Controls.Add($cmbCookies)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = 'Paste'
$btnPaste.Location = New-Object System.Drawing.Point(200, 214)
$btnPaste.Size = New-Object System.Drawing.Size(80, 28)
$btnPaste.Add_Click({ $txtUrl.Text = Get-ClipboardUrl })
$form.Controls.Add($btnPaste)

$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = 'Download'
$btnGo.Location = New-Object System.Drawing.Point(300, 214)
$btnGo.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($btnGo)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Close'
$btnClose.Location = New-Object System.Drawing.Point(420, 214)
$btnClose.Size = New-Object System.Drawing.Size(100, 28)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "MP3 -> $($cfg.Mp3Dir)"
$lblStatus.Location = New-Object System.Drawing.Point(16, 260)
$lblStatus.Size = New-Object System.Drawing.Size(510, 40)
$form.Controls.Add($lblStatus)

$appVer = '1.0.0'
$verFile = Join-Path $InstallRoot 'version.txt'
if (Test-Path -LiteralPath $verFile) { $appVer = (Get-Content -LiteralPath $verFile -Raw).Trim() }

$lblFoot = New-Object System.Windows.Forms.Label
$lblFoot.Text = "RIP Demon $appVer  |  opes.dev"
$lblFoot.ForeColor = [System.Drawing.Color]::Gray
$lblFoot.Location = New-Object System.Drawing.Point(16, 310)
$lblFoot.AutoSize = $true
$form.Controls.Add($lblFoot)

$btnGo.Add_Click({
    $url = $txtUrl.Text.Trim()
    if (-not $url) {
        $url = Get-ClipboardUrl
        $txtUrl.Text = $url
    }
    if (-not $url) {
        [System.Windows.Forms.MessageBox]::Show('Paste a media URL first.', 'RIP Demon', 'OK', 'Warning') | Out-Null
        return
    }

    $mode = if ($rbMp3.Checked) { 'mp3' } else { 'mp4' }
    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add($mode)
    if ($mode -eq 'mp4') {
        $argList.Add('--quality')
        $argList.Add([string]$cmbQuality.SelectedItem)
    }
    if ($chkOpen.Checked) { $argList.Add('--open') }
    if ($chkNoPl.Checked) { $argList.Add('--no-playlist') }
    if ($cmbCookies.Text.Trim()) {
        $argList.Add('--cookies-from-browser')
        $argList.Add($cmbCookies.Text.Trim())
    }
    $argList.Add($url)

    $lblStatus.Text = "Downloading $mode..."
    $btnGo.Enabled = $false
    $form.Refresh()

    $p = Start-Process -FilePath $YtCmd -ArgumentList $argList.ToArray() -Wait -PassThru -NoNewWindow
    $btnGo.Enabled = $true
    if ($p.ExitCode -eq 0) {
        $dir = if ($mode -eq 'mp3') { $cfg.Mp3Dir } else { $cfg.Mp4Dir }
        $lblStatus.Text = "Done. Saved to $dir"
    } else {
        $lblStatus.Text = "Failed (exit $($p.ExitCode)). Try yt update or cookies."
    }
})

[void]$form.ShowDialog()
exit 0
