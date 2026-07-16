#Requires -Version 5.1
<#
.SYNOPSIS
  WinForms download window for RIP Demon — all CLI options in a simple layout.
#>
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$GuiDir = $PSScriptRoot
$InstallRoot = Split-Path -Parent $GuiDir
# Repo layout: src\gui -> parent is src, install root is parent of src
if (-not (Test-Path (Join-Path $InstallRoot 'bin\yt.cmd'))) {
    $maybe = Split-Path -Parent $InstallRoot
    if (Test-Path (Join-Path $maybe 'bin\yt.cmd')) { $InstallRoot = $maybe }
    elseif (Test-Path (Join-Path $InstallRoot 'yt.cmd')) {
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

$appVer = '1.0.1'
$verFile = Join-Path $InstallRoot 'version.txt'
if (Test-Path -LiteralPath $verFile) { $appVer = (Get-Content -LiteralPath $verFile -Raw).Trim() }

# --- Theme ---
$cBg       = [System.Drawing.Color]::FromArgb(24, 24, 28)
$cPanel    = [System.Drawing.Color]::FromArgb(36, 36, 42)
$cInput    = [System.Drawing.Color]::FromArgb(48, 48, 56)
$cText     = [System.Drawing.Color]::FromArgb(235, 235, 240)
$cMuted    = [System.Drawing.Color]::FromArgb(150, 150, 160)
$cAccent   = [System.Drawing.Color]::FromArgb(200, 50, 50)
$cAccentHi = [System.Drawing.Color]::FromArgb(230, 70, 70)
$cOk       = [System.Drawing.Color]::FromArgb(80, 180, 100)
$cBorder   = [System.Drawing.Color]::FromArgb(60, 60, 70)

function Get-ClipboardUrl {
    try {
        $t = [System.Windows.Forms.Clipboard]::GetText()
        if (-not $t) { return '' }
        $first = ($t -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1
        if ($first -match '^https?://' -or $first -match 'youtube\.com|youtu\.be') { return $first }
    } catch {}
    return ''
}

function New-Label([string]$Text, [int]$X, [int]$Y, [System.Drawing.Font]$Font = $null, [System.Drawing.Color]$Color = $cText) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.AutoSize = $true
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    if ($Font) { $l.Font = $Font }
    return $l
}

function Style-TextBox($tb) {
    $tb.BackColor = $cInput
    $tb.ForeColor = $cText
    $tb.BorderStyle = 'FixedSingle'
}

function Style-Combo($cmb) {
    $cmb.BackColor = $cInput
    $cmb.ForeColor = $cText
    $cmb.FlatStyle = 'Flat'
}

function Style-Check($chk) {
    $chk.ForeColor = $cText
    $chk.BackColor = [System.Drawing.Color]::Transparent
    $chk.AutoSize = $true
}

function Style-Button($btn, [switch]$Primary, [switch]$Ghost) {
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    if ($Primary) {
        $btn.BackColor = $cAccent
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatAppearance.MouseOverBackColor = $cAccentHi
    } elseif ($Ghost) {
        $btn.BackColor = $cInput
        $btn.ForeColor = $cText
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = $cBorder
        $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
    } else {
        $btn.BackColor = $cPanel
        $btn.ForeColor = $cText
        $btn.FlatAppearance.MouseOverBackColor = $cInput
    }
}

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "RIP Demon $appVer"
$form.Size = New-Object System.Drawing.Size(640, 560)
$form.MinimumSize = New-Object System.Drawing.Size(640, 560)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = $cBg
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.KeyPreview = $true

# Window / taskbar icon (prefer installed assets\icon.ico)
foreach ($logoCand in @(
        (Join-Path $InstallRoot 'assets\icon.ico'),
        (Join-Path $InstallRoot 'assets\icon.png'),
        (Join-Path $InstallRoot 'assets\ripdemon.png'),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $GuiDir)) 'assets\icon.ico'),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $GuiDir)) 'assets\icon.png'),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $GuiDir)) 'assets\ripdemon.png')
    )) {
    if (Test-Path -LiteralPath $logoCand) {
        try {
            if ($logoCand -like '*.ico') {
                $form.Icon = New-Object System.Drawing.Icon $logoCand
            } else {
                $bmp = New-Object System.Drawing.Bitmap $logoCand
                $form.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
            }
        } catch {}
        break
    }
}

# Header
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Location = New-Object System.Drawing.Point(0, 0)
$hdr.Size = New-Object System.Drawing.Size(640, 64)
$hdr.BackColor = $cPanel
$form.Controls.Add($hdr)

$lblTitle = New-Label 'RIP Demon' 20 12 (New-Object System.Drawing.Font('Segoe UI Semibold', 16)) $cText
$hdr.Controls.Add($lblTitle)

$lblBrand = New-Object System.Windows.Forms.LinkLabel
$lblBrand.Text = "by Opes  ·  v$appVer  ·  opes.dev"
$lblBrand.Location = New-Object System.Drawing.Point(20, 40)
$lblBrand.AutoSize = $true
$lblBrand.LinkColor = $cMuted
$lblBrand.ActiveLinkColor = $cAccentHi
$lblBrand.VisitedLinkColor = $cMuted
$lblBrand.BackColor = [System.Drawing.Color]::Transparent
$lblBrand.Add_LinkClicked({ Start-Process 'https://opes.dev' })
$hdr.Controls.Add($lblBrand)

# URL
$form.Controls.Add((New-Label 'Video URL' 20 80 $null $cMuted))

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(20, 100)
$txtUrl.Size = New-Object System.Drawing.Size(480, 28)
$txtUrl.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$txtUrl.Text = Get-ClipboardUrl
Style-TextBox $txtUrl
$form.Controls.Add($txtUrl)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = 'Paste'
$btnPaste.Location = New-Object System.Drawing.Point(510, 98)
$btnPaste.Size = New-Object System.Drawing.Size(100, 32)
Style-Button $btnPaste -Ghost
$btnPaste.Add_Click({
    $txtUrl.Text = Get-ClipboardUrl
    if (-not $txtUrl.Text) {
        try { $txtUrl.Text = [System.Windows.Forms.Clipboard]::GetText().Trim() } catch {}
    }
})
$form.Controls.Add($btnPaste)

# Format
$form.Controls.Add((New-Label 'Format' 20 144 $null $cMuted))

$btnMp3 = New-Object System.Windows.Forms.Button
$btnMp3.Text = 'MP3  ·  Audio'
$btnMp3.Location = New-Object System.Drawing.Point(20, 164)
$btnMp3.Size = New-Object System.Drawing.Size(290, 40)
$btnMp3.Tag = 'mp3'
Style-Button $btnMp3 -Primary
$form.Controls.Add($btnMp3)

$btnMp4 = New-Object System.Windows.Forms.Button
$btnMp4.Text = 'MP4  ·  Video'
$btnMp4.Location = New-Object System.Drawing.Point(320, 164)
$btnMp4.Size = New-Object System.Drawing.Size(290, 40)
$btnMp4.Tag = 'mp4'
Style-Button $btnMp4 -Ghost
$form.Controls.Add($btnMp4)

$script:SelectedMode = 'mp3'

# Options panel
$pnlOpts = New-Object System.Windows.Forms.Panel
$pnlOpts.Location = New-Object System.Drawing.Point(20, 220)
$pnlOpts.Size = New-Object System.Drawing.Size(590, 170)
$pnlOpts.BackColor = $cPanel
$form.Controls.Add($pnlOpts)

$pnlOpts.Controls.Add((New-Label 'Options' 16 10 $null $cMuted))

# Left column
$lblQ = New-Label 'MP4 quality' 16 36 $null $cMuted
$pnlOpts.Controls.Add($lblQ)

$cmbQuality = New-Object System.Windows.Forms.ComboBox
$cmbQuality.DropDownStyle = 'DropDownList'
$cmbQuality.Location = New-Object System.Drawing.Point(16, 56)
$cmbQuality.Size = New-Object System.Drawing.Size(160, 28)
[void]$cmbQuality.Items.AddRange(@('720', '1080', 'best'))
$qi = @('720', '1080', 'best').IndexOf([string]$cfg.Quality)
if ($qi -lt 0) { $qi = 1 }
$cmbQuality.SelectedIndex = $qi
Style-Combo $cmbQuality
$pnlOpts.Controls.Add($cmbQuality)

$lblCookies = New-Label 'Cookies browser' 16 94 $null $cMuted
$pnlOpts.Controls.Add($lblCookies)

$cmbCookies = New-Object System.Windows.Forms.ComboBox
$cmbCookies.DropDownStyle = 'DropDown'
$cmbCookies.Location = New-Object System.Drawing.Point(16, 114)
$cmbCookies.Size = New-Object System.Drawing.Size(160, 28)
[void]$cmbCookies.Items.AddRange(@('(none)', 'chrome', 'edge', 'firefox', 'brave', 'opera'))
if ($cfg.CookiesBrowser) {
    $cmbCookies.Text = [string]$cfg.CookiesBrowser
} else {
    $cmbCookies.SelectedIndex = 0
}
Style-Combo $cmbCookies
$pnlOpts.Controls.Add($cmbCookies)

# Middle column — toggles
$chkNoPl = New-Object System.Windows.Forms.CheckBox
$chkNoPl.Text = 'No playlist (this video only)'
$chkNoPl.Location = New-Object System.Drawing.Point(200, 54)
$chkNoPl.Checked = [bool]$cfg.NoPlaylist
Style-Check $chkNoPl
$pnlOpts.Controls.Add($chkNoPl)

$chkOpen = New-Object System.Windows.Forms.CheckBox
$chkOpen.Text = 'Open folder when done'
$chkOpen.Location = New-Object System.Drawing.Point(200, 82)
$chkOpen.Checked = [bool]$cfg.OpenAfter
Style-Check $chkOpen
$pnlOpts.Controls.Add($chkOpen)

$chkThumb = New-Object System.Windows.Forms.CheckBox
$chkThumb.Text = 'Thumbnail only (skip media)'
$chkThumb.Location = New-Object System.Drawing.Point(200, 110)
$chkThumb.Checked = $false
Style-Check $chkThumb
$pnlOpts.Controls.Add($chkThumb)

# Right column — MP4 extras
$chkSubs = New-Object System.Windows.Forms.CheckBox
$chkSubs.Text = 'Subtitles'
$chkSubs.Location = New-Object System.Drawing.Point(430, 54)
$chkSubs.Checked = $false
Style-Check $chkSubs
$pnlOpts.Controls.Add($chkSubs)

$cmbSubsLang = New-Object System.Windows.Forms.ComboBox
$cmbSubsLang.DropDownStyle = 'DropDown'
$cmbSubsLang.Location = New-Object System.Drawing.Point(430, 80)
$cmbSubsLang.Size = New-Object System.Drawing.Size(140, 28)
[void]$cmbSubsLang.Items.AddRange(@('en', 'es', 'fr', 'de', 'pt', 'ja', 'ko', 'zh-Hans'))
$cmbSubsLang.Text = 'en'
Style-Combo $cmbSubsLang
$pnlOpts.Controls.Add($cmbSubsLang)

$chkSponsor = New-Object System.Windows.Forms.CheckBox
$chkSponsor.Text = 'SponsorBlock remove'
$chkSponsor.Location = New-Object System.Drawing.Point(430, 118)
$chkSponsor.Checked = [bool]$cfg.SponsorBlock
Style-Check $chkSponsor
$pnlOpts.Controls.Add($chkSponsor)

function Set-StatusHint {
    $isMp4 = ($script:SelectedMode -eq 'mp4')
    $dir = if ($isMp4) { $cfg.Mp4Dir } else { $cfg.Mp3Dir }
    $lblStatus.ForeColor = $cMuted
    if ($chkThumb.Checked) {
        $lblStatus.Text = "Thumbnail only → $dir"
    } elseif ($isMp4) {
        $lblStatus.Text = "MP4 → $dir"
    } else {
        $lblStatus.Text = "MP3 → $dir"
    }
}

function Update-ModeUi {
    $isMp4 = ($script:SelectedMode -eq 'mp4')

    if ($isMp4) {
        Style-Button $btnMp4 -Primary
        Style-Button $btnMp3 -Ghost
        $cmbQuality.Enabled = -not $chkThumb.Checked
        $chkSubs.Enabled = -not $chkThumb.Checked
        $cmbSubsLang.Enabled = ($chkSubs.Checked -and -not $chkThumb.Checked)
        $chkSponsor.Enabled = -not $chkThumb.Checked
    } else {
        Style-Button $btnMp3 -Primary
        Style-Button $btnMp4 -Ghost
        $cmbQuality.Enabled = $false
        $chkSubs.Enabled = $false
        $cmbSubsLang.Enabled = $false
        $chkSponsor.Enabled = $false
    }
}

$btnMp3.Add_Click({
    $script:SelectedMode = 'mp3'
    Update-ModeUi
    Set-StatusHint
})
$btnMp4.Add_Click({
    $script:SelectedMode = 'mp4'
    Update-ModeUi
    Set-StatusHint
})
$chkSubs.Add_CheckedChanged({ Update-ModeUi })
$chkThumb.Add_CheckedChanged({
    Update-ModeUi
    Set-StatusHint
})

# Actions
$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = 'Download'
$btnGo.Location = New-Object System.Drawing.Point(20, 408)
$btnGo.Size = New-Object System.Drawing.Size(200, 40)
$btnGo.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
Style-Button $btnGo -Primary
$form.Controls.Add($btnGo)
$form.AcceptButton = $btnGo

$btnFolderMp3 = New-Object System.Windows.Forms.Button
$btnFolderMp3.Text = 'MP3 folder'
$btnFolderMp3.Location = New-Object System.Drawing.Point(232, 408)
$btnFolderMp3.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnFolderMp3 -Ghost
$btnFolderMp3.Add_Click({
    New-Item -ItemType Directory -Force -Path $cfg.Mp3Dir | Out-Null
    Start-Process explorer.exe $cfg.Mp3Dir
})
$form.Controls.Add($btnFolderMp3)

$btnFolderMp4 = New-Object System.Windows.Forms.Button
$btnFolderMp4.Text = 'MP4 folder'
$btnFolderMp4.Location = New-Object System.Drawing.Point(350, 408)
$btnFolderMp4.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnFolderMp4 -Ghost
$btnFolderMp4.Add_Click({
    New-Item -ItemType Directory -Force -Path $cfg.Mp4Dir | Out-Null
    Start-Process explorer.exe $cfg.Mp4Dir
})
$form.Controls.Add($btnFolderMp4)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Close'
$btnClose.Location = New-Object System.Drawing.Point(500, 408)
$btnClose.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnClose -Ghost
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 460)
$lblStatus.Size = New-Object System.Drawing.Size(590, 40)
$lblStatus.ForeColor = $cMuted
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblStatus)

Update-ModeUi
Set-StatusHint

$btnGo.Add_Click({
    $url = $txtUrl.Text.Trim()
    if (-not $url) {
        $url = Get-ClipboardUrl
        $txtUrl.Text = $url
    }
    if (-not $url) {
        [System.Windows.Forms.MessageBox]::Show(
            'Paste a media URL first (or copy a link and click Paste).',
            'RIP Demon',
            'OK',
            'Warning'
        ) | Out-Null
        return
    }

    $mode = $script:SelectedMode
    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add($mode)

    if ($chkThumb.Checked) {
        $argList.Add('--thumbnail-only')
    }
    else {
        if ($mode -eq 'mp4') {
            $argList.Add('--quality')
            $argList.Add([string]$cmbQuality.SelectedItem)
            if ($chkSubs.Checked) {
                $argList.Add('--subs')
                $lang = $cmbSubsLang.Text.Trim()
                if ($lang) { $argList.Add($lang) }
            }
            if ($chkSponsor.Checked) { $argList.Add('--sponsorblock') }
        }
    }

    if ($chkOpen.Checked) { $argList.Add('--open') }
    if ($chkNoPl.Checked) { $argList.Add('--no-playlist') }

    $cookies = $cmbCookies.Text.Trim()
    if ($cookies -and $cookies -ne '(none)') {
        $argList.Add('--cookies-from-browser')
        $argList.Add($cookies)
    }

    $argList.Add($url)

    $lblStatus.ForeColor = $cMuted
    $lblStatus.Text = "Downloading $mode..."
    $btnGo.Enabled = $false
    $btnMp3.Enabled = $false
    $btnMp4.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $form.Refresh()

    try {
        $p = Start-Process -FilePath $YtCmd -ArgumentList $argList.ToArray() -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -eq 0) {
            $dir = if ($mode -eq 'mp3') { $cfg.Mp3Dir } else { $cfg.Mp4Dir }
            $lblStatus.ForeColor = $cOk
            $lblStatus.Text = "Done — saved to $dir"
        } else {
            $lblStatus.ForeColor = $cAccentHi
            $lblStatus.Text = "Failed (exit $($p.ExitCode)). Try yt update, or enable cookies for age-gated videos."
        }
    } catch {
        $lblStatus.ForeColor = $cAccentHi
        $lblStatus.Text = "Error: $($_.Exception.Message)"
    } finally {
        $btnGo.Enabled = $true
        $btnMp3.Enabled = $true
        $btnMp4.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        Update-ModeUi
    }
})


$form.Add_Shown({
    if (-not $txtUrl.Text) { $txtUrl.Text = Get-ClipboardUrl }
    $txtUrl.Focus()
    $txtUrl.SelectAll()
})

[void]$form.ShowDialog()
exit 0
