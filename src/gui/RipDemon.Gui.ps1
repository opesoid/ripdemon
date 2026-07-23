#Requires -Version 5.1
<#
.SYNOPSIS
  WinForms download window for RIP Demon - all CLI options in a simple layout.
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

$YtDlp = Join-Path $InstallRoot 'tools\yt-dlp.exe'
$ToolsDir = Join-Path $InstallRoot 'tools'
Initialize-RipDemonToolsPath -ToolsDir $ToolsDir

$Mp4Formats = @{
    '720'  = 'bv*[height=720][fps=60]+ba/bv*[height=720][fps>=50]+ba/bv*[height=720]+ba/bv*[height<=720]+ba/b'
    '1080' = 'bv*[height=1080][fps=60]+ba/bv*[height=1080][fps>=50]+ba/bv*[height=1080]+ba/bv*[height<=1080]+ba/b'
    'best' = 'bv*+ba/b'
}

$appVer = '1.0.2'
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
$form.Size = New-Object System.Drawing.Size(640, 600)
$form.MinimumSize = New-Object System.Drawing.Size(640, 600)
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
$hdr.Size = New-Object System.Drawing.Size(640, 78)
$hdr.BackColor = $cPanel
$form.Controls.Add($hdr)

$lblTitle = New-Label 'RIP Demon' 20 10 (New-Object System.Drawing.Font('Segoe UI Semibold', 16)) $cText
$hdr.Controls.Add($lblTitle)

$lblBrand = New-Object System.Windows.Forms.LinkLabel
$lblBrand.Text = "by Opes  |  v$appVer  |  opes.dev"
$lblBrand.Location = New-Object System.Drawing.Point(20, 42)
$lblBrand.Size = New-Object System.Drawing.Size(600, 22)
$lblBrand.AutoSize = $false
$lblBrand.LinkColor = $cMuted
$lblBrand.ActiveLinkColor = $cAccentHi
$lblBrand.VisitedLinkColor = $cMuted
$lblBrand.BackColor = [System.Drawing.Color]::Transparent
$lblBrand.Add_LinkClicked({ Start-Process 'https://opes.dev' })
$hdr.Controls.Add($lblBrand)

# URL
$form.Controls.Add((New-Label 'Video URL' 20 92 $null $cMuted))

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(20, 112)
$txtUrl.Size = New-Object System.Drawing.Size(480, 28)
$txtUrl.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$txtUrl.Text = Get-ClipboardUrl
Style-TextBox $txtUrl
$form.Controls.Add($txtUrl)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = 'Paste'
$btnPaste.Location = New-Object System.Drawing.Point(510, 110)
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
$form.Controls.Add((New-Label 'Format' 20 156 $null $cMuted))

$btnMp3 = New-Object System.Windows.Forms.Button
$btnMp3.Text = 'MP3  |  Audio'
$btnMp3.Location = New-Object System.Drawing.Point(20, 176)
$btnMp3.Size = New-Object System.Drawing.Size(290, 40)
$btnMp3.Tag = 'mp3'
Style-Button $btnMp3 -Primary
$form.Controls.Add($btnMp3)

$btnMp4 = New-Object System.Windows.Forms.Button
$btnMp4.Text = 'MP4  |  Video'
$btnMp4.Location = New-Object System.Drawing.Point(320, 176)
$btnMp4.Size = New-Object System.Drawing.Size(290, 40)
$btnMp4.Tag = 'mp4'
Style-Button $btnMp4 -Ghost
$form.Controls.Add($btnMp4)

$script:SelectedMode = 'mp3'

# Options panel
$pnlOpts = New-Object System.Windows.Forms.Panel
$pnlOpts.Location = New-Object System.Drawing.Point(20, 232)
$pnlOpts.Size = New-Object System.Drawing.Size(590, 170)
$pnlOpts.BackColor = $cPanel
$form.Controls.Add($pnlOpts)

$pnlOpts.Controls.Add((New-Label 'Options' 16 10 $null $cMuted))

# Left column
$lblQ = New-Label 'MP4 quality (1080p60)' 16 36 $null $cMuted
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

# Middle column - toggles
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

# Right column - MP4 extras
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
        $lblStatus.Text = "Thumbnail only -> $dir"
    } elseif ($isMp4) {
        $lblStatus.Text = "MP4 -> $dir"
    } else {
        $lblStatus.Text = "MP3 -> $dir"
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
$btnGo.Location = New-Object System.Drawing.Point(20, 418)
$btnGo.Size = New-Object System.Drawing.Size(200, 40)
$btnGo.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
Style-Button $btnGo -Primary
$form.Controls.Add($btnGo)
$form.AcceptButton = $btnGo

$btnFolderMp3 = New-Object System.Windows.Forms.Button
$btnFolderMp3.Text = 'MP3 folder'
$btnFolderMp3.Location = New-Object System.Drawing.Point(232, 418)
$btnFolderMp3.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnFolderMp3 -Ghost
$btnFolderMp3.Add_Click({
    New-Item -ItemType Directory -Force -Path $cfg.Mp3Dir | Out-Null
    Start-Process explorer.exe $cfg.Mp3Dir
})
$form.Controls.Add($btnFolderMp3)

$btnFolderMp4 = New-Object System.Windows.Forms.Button
$btnFolderMp4.Text = 'MP4 folder'
$btnFolderMp4.Location = New-Object System.Drawing.Point(350, 418)
$btnFolderMp4.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnFolderMp4 -Ghost
$btnFolderMp4.Add_Click({
    New-Item -ItemType Directory -Force -Path $cfg.Mp4Dir | Out-Null
    Start-Process explorer.exe $cfg.Mp4Dir
})
$form.Controls.Add($btnFolderMp4)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Close'
$btnClose.Location = New-Object System.Drawing.Point(500, 418)
$btnClose.Size = New-Object System.Drawing.Size(110, 40)
Style-Button $btnClose -Ghost
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Location = New-Object System.Drawing.Point(20, 468)
$lblProgress.Size = New-Object System.Drawing.Size(590, 18)
$lblProgress.ForeColor = $cMuted
$lblProgress.BackColor = [System.Drawing.Color]::Transparent
$lblProgress.Text = 'Ready'
$form.Controls.Add($lblProgress)

$pbDownload = New-Object System.Windows.Forms.ProgressBar
$pbDownload.Location = New-Object System.Drawing.Point(20, 488)
$pbDownload.Size = New-Object System.Drawing.Size(590, 22)
$pbDownload.Minimum = 0
$pbDownload.Maximum = 100
$pbDownload.Value = 0
$pbDownload.Style = 'Continuous'
$form.Controls.Add($pbDownload)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 516)
$lblStatus.Size = New-Object System.Drawing.Size(590, 36)
$lblStatus.ForeColor = $cMuted
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblStatus)

function Reset-DownloadProgressUi {
    $script:pbDownload.Style = 'Continuous'
    $script:pbDownload.Value = 0
    $script:lblProgress.Text = 'Ready'
    $script:lastProgressPct = -1
    $script:lastProgressUiUtc = [datetime]::MinValue
}

function Update-DownloadProgressLine {
    param([string]$Line)
    if (-not $Line) { return }
    $t = $Line -replace '\x1b\[[0-9;]*m', ''
    $t = $t.Trim()
    if (-not $t) { return }

    if ($t -match '^\[download\]\s+([\d.]+)%\s+of\s+(\S+)\s+at\s+(\S+)(?:\s+ETA\s+(\S+))?') {
        $pct = [int][double]$Matches[1]
        $now = [datetime]::UtcNow
        if (($pct -eq $script:lastProgressPct) -and (($now - $script:lastProgressUiUtc).TotalMilliseconds -lt 100)) {
            return
        }
        $script:lastProgressPct = $pct
        $script:lastProgressUiUtc = $now
        $script:pbDownload.Style = 'Continuous'
        $script:pbDownload.Value = [Math]::Min(100, [Math]::Max(0, $pct))
        $eta = if ($Matches[4]) { $Matches[4] } else { '...' }
        $script:lblProgress.Text = "$($Matches[1])% of $($Matches[2]) at $($Matches[3]) - ETA $eta"
        return
    }
    if ($t -match '^\[download\]\s+([\d.]+)%') {
        $pct = [int][double]$Matches[1]
        $now = [datetime]::UtcNow
        if (($pct -eq $script:lastProgressPct) -and (($now - $script:lastProgressUiUtc).TotalMilliseconds -lt 100)) {
            return
        }
        $script:lastProgressPct = $pct
        $script:lastProgressUiUtc = $now
        $script:pbDownload.Style = 'Continuous'
        $script:pbDownload.Value = [Math]::Min(100, [Math]::Max(0, $pct))
        $script:lblProgress.Text = "$($Matches[1])% downloaded"
        return
    }
    if ($t -match '^\[(download|ExtractAudio|Merger|ffmpeg|Metadata|SponsorBlock)\]') {
        $now = [datetime]::UtcNow
        if (($now - $script:lastProgressUiUtc).TotalMilliseconds -lt 100) { return }
        $script:lastProgressUiUtc = $now
        $short = $t
        if ($short.Length -gt 72) { $short = $short.Substring(0, 72) + '...' }
        $script:lblProgress.Text = $short
    }
}

function Invoke-RipDemonGuiYtDlpProcess {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$ArgumentList,
        [scriptblock]$OnLine = $null,
        [scriptblock]$OnStatus = $null
    )

    $argLine = ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') { '"{0}"' -f ($_ -replace '"', '""') } else { $_ }
    }) -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $YtDlp
    $psi.Arguments = $argLine
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    # Ensure deno/ffmpeg side tools resolve (PS 5.1 has no ArgumentList API).
    try {
        $psi.EnvironmentVariables['Path'] = "$ToolsDir;" + $psi.EnvironmentVariables['Path']
    } catch {}

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    # Async reads avoid the classic stdout/stderr ReadLine deadlock when one stream blocks.
    $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    $onData = {
        param($sender, $e)
        if ($null -ne $e.Data) {
            [void]$queue.Enqueue($e.Data)
        }
    }
    $proc.add_OutputDataReceived($onData)
    $proc.add_ErrorDataReceived($onData)
    [void]$proc.Start()
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()

    $buffer = New-RipDemonLineBuffer -Capacity 200
    $line = $null
    while (-not $proc.HasExited) {
        $got = $false
        while ($queue.TryDequeue([ref]$line)) {
            $got = $true
            Add-RipDemonLineBuffer -Buffer $buffer -Line $line
            if ($OnLine) { & $OnLine $line }
        }
        if (-not $got) {
            Start-Sleep -Milliseconds 40
        }
    }
    $proc.WaitForExit()
    $deadline = [datetime]::UtcNow.AddMilliseconds(1500)
    do {
        while ($queue.TryDequeue([ref]$line)) {
            Add-RipDemonLineBuffer -Buffer $buffer -Line $line
            if ($OnLine) { & $OnLine $line }
        }
        if (-not $queue.IsEmpty) {
            Start-Sleep -Milliseconds 20
        }
    } while ((-not $queue.IsEmpty) -and ([datetime]::UtcNow -lt $deadline))

    return [pscustomobject]@{
        ExitCode = [int]$proc.ExitCode
        Output   = (Get-RipDemonLineBufferText -Buffer $buffer)
    }
}

function New-RipDemonGuiDownloadArgs {
    param(
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][bool]$NoPlaylist,
        [Parameter(Mandatory)][string]$Cookies,
        [Parameter(Mandatory)][bool]$ThumbnailOnly,
        [Parameter(Mandatory)][string]$Quality,
        [Parameter(Mandatory)][bool]$SponsorBlock,
        [Parameter(Mandatory)][bool]$Subs,
        [Parameter(Mandatory)][string]$SubsLang,
        [Parameter(Mandatory)][string]$OutDir
    )

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $template = Join-Path $OutDir '%(title)s [%(id)s].%(ext)s'

    $yargs = New-Object System.Collections.Generic.List[string]
    $yargs.Add('--ffmpeg-location'); $yargs.Add($ToolsDir)
    $yargs.Add('--no-mtime')
    $yargs.Add('--newline')
    $yargs.Add('--progress')
    $yargs.Add('-o'); $yargs.Add($template)

    if ($NoPlaylist) { $yargs.Add('--no-playlist') }
    $cookiesEnabled = ($Cookies -and $Cookies -ne '(none)')
    if ($cookiesEnabled) {
        $yargs.Add('--cookies-from-browser'); $yargs.Add($Cookies)
    }

    if ($ThumbnailOnly) {
        $yargs.Add('--skip-download')
        $yargs.Add('--write-thumbnail')
        $yargs.Add('--convert-thumbnails'); $yargs.Add('jpg')
    }
    elseif ($Mode -eq 'mp3') {
        $yargs.Add('-x')
        $yargs.Add('--audio-format'); $yargs.Add('mp3')
        $yargs.Add('--audio-quality'); $yargs.Add('0')
        $yargs.Add('--embed-thumbnail')
        $yargs.Add('--embed-metadata')
    }
    else {
        $fmt = $Mp4Formats[$Quality]
        if (-not $fmt) { $fmt = $Mp4Formats['1080'] }
        $yargs.Add('-f'); $yargs.Add($fmt)
        $yargs.Add('--merge-output-format'); $yargs.Add('mp4')
        $yargs.Add('--embed-metadata')
        if ($SponsorBlock) {
            $yargs.Add('--sponsorblock-remove'); $yargs.Add('default')
        }
        if ($Subs) {
            $yargs.Add('--write-subs')
            $yargs.Add('--embed-subs')
            if ($SubsLang) {
                $yargs.Add('--sub-langs'); $yargs.Add($SubsLang)
            } else {
                $yargs.Add('--sub-langs'); $yargs.Add('en.*,en')
            }
        }
    }

    $yargs.Add('--')
    $yargs.Add($Url)

    return [pscustomobject]@{
        ArgumentList   = $yargs
        CookiesEnabled = $cookiesEnabled
        Cookies        = $Cookies
        OutDir         = $OutDir
    }
}

function Invoke-RipDemonGuiDownload {
    param(
        [Parameter(Mandatory)]$Job,
        [scriptblock]$OnLine = $null,
        [scriptblock]$OnStatus = $null
    )

    if (-not (Test-Path -LiteralPath $YtDlp)) {
        throw 'yt-dlp not found. Run: yt update'
    }

    $yargs = $Job.ArgumentList
    $cookiesEnabled = [bool]$Job.CookiesEnabled
    $cookies = [string]$Job.Cookies

    $result = Invoke-RipDemonGuiYtDlpProcess -ArgumentList $yargs -OnLine $OnLine
    if ($result.ExitCode -eq 0) {
        return [pscustomobject]@{ ExitCode = 0; CookieFallback = $false; CookieError = $false }
    }

    if ($cookiesEnabled -and (Test-RipDemonCookieDecryptError -Text $result.Output)) {
        if ($OnStatus) {
            & $OnStatus "Cookie decrypt failed ($cookies). Retrying without cookies..."
        }
        Remove-RipDemonCookiesFromBrowserArgs -ArgumentList $yargs
        $retry = Invoke-RipDemonGuiYtDlpProcess -ArgumentList $yargs -OnLine $OnLine
        return [pscustomobject]@{
            ExitCode       = [int]$retry.ExitCode
            CookieFallback = $true
            CookieError    = $true
        }
    }

    return [pscustomobject]@{
        ExitCode       = [int]$result.ExitCode
        CookieFallback = $false
        CookieError    = (Test-RipDemonCookieDecryptError -Text $result.Output)
    }
}

Update-ModeUi
Set-StatusHint
Reset-DownloadProgressUi

$script:downloadWorker = New-Object System.ComponentModel.BackgroundWorker
$script:downloadWorker.WorkerReportsProgress = $true
$script:downloadWorker.WorkerSupportsCancellation = $false
$script:downloadBusy = $false

$script:downloadWorker.add_DoWork({
    param($sender, $e)
    $job = $e.Argument
    $worker = $sender
    $onLine = {
        param($line)
        $worker.ReportProgress(0, @{ Kind = 'line'; Text = [string]$line })
    }.GetNewClosure()
    $onStatus = {
        param($text)
        $worker.ReportProgress(0, @{ Kind = 'status'; Text = [string]$text })
    }.GetNewClosure()
    try {
        $e.Result = Invoke-RipDemonGuiDownload -Job $job -OnLine $onLine -OnStatus $onStatus
    } catch {
        $e.Result = [pscustomobject]@{
            ExitCode       = 1
            CookieFallback = $false
            CookieError    = $false
            ErrorMessage   = $_.Exception.Message
        }
    }
})

$script:downloadWorker.add_ProgressChanged({
    param($sender, $e)
    $msg = $e.UserState
    if ($null -eq $msg) { return }
    if ($msg.Kind -eq 'status') {
        $script:lblStatus.ForeColor = $cMuted
        $script:lblStatus.Text = [string]$msg.Text
        $script:lblProgress.Text = 'Retrying...'
        $script:pbDownload.Value = 0
        return
    }
    if ($msg.Kind -eq 'line') {
        Update-DownloadProgressLine ([string]$msg.Text)
    }
})

$script:downloadWorker.add_RunWorkerCompleted({
    param($sender, $e)
    $script:downloadBusy = $false
    $script:btnGo.Enabled = $true
    $script:btnMp3.Enabled = $true
    $script:btnMp4.Enabled = $true
    $script:btnPaste.Enabled = $true
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
    Update-ModeUi

    if ($e.Error) {
        $script:lblProgress.Text = 'Error'
        $script:lblStatus.ForeColor = $cAccentHi
        $script:lblStatus.Text = "Error: $($e.Error.Message)"
        return
    }

    $result = $e.Result
    if ($result.ErrorMessage) {
        $script:lblProgress.Text = 'Error'
        $script:lblStatus.ForeColor = $cAccentHi
        $script:lblStatus.Text = "Error: $($result.ErrorMessage)"
        return
    }

    $exitCode = [int]$result.ExitCode
    $dir = [string]$script:downloadOutDir
    if ($exitCode -eq 0) {
        $script:pbDownload.Value = 100
        $script:lblProgress.Text = 'Complete'
        $script:lblStatus.ForeColor = $cOk
        if ($result.CookieFallback) {
            $script:lblStatus.Text = "Done (cookies skipped) - saved to $dir"
        } else {
            $script:lblStatus.Text = "Done - saved to $dir"
        }
        if ($script:downloadOpenAfter) {
            try { Start-Process -FilePath 'explorer.exe' -ArgumentList $dir | Out-Null } catch {}
        }
    } else {
        $script:lblProgress.Text = 'Failed'
        $script:lblStatus.ForeColor = $cAccentHi
        if ($result.CookieFallback) {
            $script:lblStatus.Text = "Failed (exit $exitCode) after skipping cookies (DPAPI). Try firefox for age-gated videos, or (none)."
        } elseif ($result.CookieError) {
            $script:lblStatus.Text = 'Failed: Chrome/Edge cookie decrypt (DPAPI). Set Cookies browser to (none) or firefox.'
        } else {
            $script:lblStatus.Text = "Failed (exit $exitCode). Try yt update, or cookies via firefox for age-gated videos."
        }
    }
})

$btnGo.Add_Click({
    if ($script:downloadBusy -or $script:downloadWorker.IsBusy) { return }

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
    $outDir = if ($mode -eq 'mp3') { $cfg.Mp3Dir } else { $cfg.Mp4Dir }
    $job = New-RipDemonGuiDownloadArgs `
        -Mode $mode `
        -Url $url `
        -NoPlaylist ([bool]$chkNoPl.Checked) `
        -Cookies ($cmbCookies.Text.Trim()) `
        -ThumbnailOnly ([bool]$chkThumb.Checked) `
        -Quality ([string]$cmbQuality.SelectedItem) `
        -SponsorBlock ([bool]$chkSponsor.Checked) `
        -Subs ([bool]$chkSubs.Checked) `
        -SubsLang ($cmbSubsLang.Text.Trim()) `
        -OutDir $outDir

    $script:downloadOutDir = $outDir
    $script:downloadOpenAfter = [bool]$chkOpen.Checked
    $script:downloadBusy = $true

    $lblStatus.ForeColor = $cMuted
    $lblStatus.Text = "Starting $mode download..."
    $lblProgress.Text = 'Connecting...'
    $pbDownload.Value = 0
    $script:lastProgressPct = -1
    $script:lastProgressUiUtc = [datetime]::MinValue
    $btnGo.Enabled = $false
    $btnMp3.Enabled = $false
    $btnMp4.Enabled = $false
    $btnPaste.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting

    $script:downloadWorker.RunWorkerAsync($job)
})


$form.Add_Shown({
    if (-not $txtUrl.Text) { $txtUrl.Text = Get-ClipboardUrl }
    $txtUrl.Focus()
    $txtUrl.SelectAll()
})

[void]$form.ShowDialog()
exit 0
