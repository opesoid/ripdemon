#Requires -Version 5.1
<#
.SYNOPSIS
  RIP Demon CLI engine (download, info, config). Invoked by bin\yt.cmd.
  Uses $args only (no param [string[]] — that splits a single string into chars).
#>

$ErrorActionPreference = 'Stop'

$LibDir = $PSScriptRoot
$InstallRoot = Split-Path -Parent $LibDir
$ToolsDir = Join-Path $InstallRoot 'tools'
$YtDlp = Join-Path $ToolsDir 'yt-dlp.exe'
$DefaultConfigPath = Join-Path $LibDir 'config.default.ini'

. (Join-Path $LibDir 'RipDemon.Config.ps1')

$Mp4Formats = @{
    '720'  = 'bv*[height=720][fps=60]+ba/bv*[height=720][fps>=50]+ba/bv*[height=720]+ba/bv*[height<=720]+ba/b'
    '1080' = 'bv*[height=1080][fps=60]+ba/bv*[height=1080][fps>=50]+ba/bv*[height=1080]+ba/bv*[height<=1080]+ba/b'
    'best' = 'bv*+ba/b'
}

function Test-RipDemonUrlLike {
    param([string]$Text)
    if (-not $Text) { return $false }
    $t = $Text.Trim()
    if ($t -match '^https?://') { return $true }
    if ($t -match '^(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)/') { return $true }
    return $false
}

function Normalize-RipDemonUrl {
    param([string]$Text)
    $t = $Text.Trim()
    if ($t -match '^https?://') { return $t }
    return "https://$t"
}

function Get-RipDemonClipboardText {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $text = [System.Windows.Forms.Clipboard]::GetText()
        if ($text) { return $text.Trim() }
    } catch {}
    try {
        $clip = Get-Clipboard -Raw -ErrorAction Stop
        if ($clip) { return $clip.Trim() }
    } catch {}
    return $null
}

function ConvertTo-RipDemonArgList {
    param($Tokens)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Tokens) {
        Write-Output -NoEnumerate $out
        return
    }
    # Strings are IEnumerable of chars — never foreach a bare string.
    if ($Tokens -is [string]) {
        [void]$out.Add([string]$Tokens)
        Write-Output -NoEnumerate $out
        return
    }
    # Already a List[string] from a prior call
    if ($Tokens -is [System.Collections.Generic.List[string]]) {
        Write-Output -NoEnumerate $Tokens
        return
    }
    # Mistaken nested array (e.g. Object[]{ string[] }) — flatten one level
    if ($Tokens -is [System.Array] -and $Tokens.Count -eq 1 -and $Tokens[0] -is [System.Array] -and $Tokens[0] -isnot [string]) {
        ConvertTo-RipDemonArgList -Tokens $Tokens[0]
        return
    }
    if ($Tokens -is [System.Collections.IEnumerable]) {
        foreach ($t in $Tokens) {
            if ($null -eq $t) { continue }
            if ($t -is [string]) {
                [void]$out.Add($t)
            } elseif ($t -is [System.Array] -and $t -isnot [string]) {
                foreach ($inner in $t) {
                    if ($null -ne $inner) { [void]$out.Add([string]$inner) }
                }
            } else {
                [void]$out.Add([string]$t)
            }
        }
        # Char-split repair: many 1-length tokens -> one word
        if ($out.Count -gt 1 -and ($out | Where-Object { $_.Length -eq 1 }).Count -eq $out.Count) {
            $joined = -join $out
            $out.Clear()
            [void]$out.Add($joined)
        }
        Write-Output -NoEnumerate $out
        return
    }
    [void]$out.Add([string]$Tokens)
    Write-Output -NoEnumerate $out
}

function Repair-RipDemonArgList {
    param($Tokens)
    $Tokens = ConvertTo-RipDemonArgList $Tokens
    $out = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $Tokens.Count) {
        $cur = [string]$Tokens[$i]
        if ($cur -match '^https?://' -or $cur -match '^ytsearch:') {
            while (($i + 1) -lt $Tokens.Count) {
                $next = [string]$Tokens[$i + 1]
                if ($next -match '^-' -or $next -match '^https?://' -or $next -eq '--') { break }
                if (($next -match '\.(txt|list|url)$') -and (Test-Path -LiteralPath $next)) { break }
                if ($cur -match '[=?&]$|watch\?v$|list$|t$' -or ($next -match '^[A-Za-z0-9_-]+$' -and $cur -match 'https?://')) {
                    $cur = "$cur=$next"
                    $i++
                    continue
                }
                break
            }
            [void]$out.Add($cur)
        } else {
            [void]$out.Add($cur)
        }
        $i++
    }
    Write-Output -NoEnumerate $out
}

function Get-RipDemonTargetsFromTextFile {
    param([string]$Path)
    $urls = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
        if (Test-RipDemonUrlLike $t) { $urls += (Normalize-RipDemonUrl $t) }
    }
    return $urls
}

function Resolve-RipDemonTargets {
    param($Tokens)
    $Tokens = ConvertTo-RipDemonArgList $Tokens
    $urls = New-Object System.Collections.Generic.List[string]
    foreach ($t in $Tokens) {
        if (-not $t) { continue }
        $t = [string]$t
        if ((Test-Path -LiteralPath $t) -and ($t -match '\.(txt|list)$')) {
            foreach ($u in (Get-RipDemonTargetsFromTextFile -Path $t)) { [void]$urls.Add($u) }
            continue
        }
        if ((Test-Path -LiteralPath $t) -and ($t -match '\.url$')) {
            foreach ($line in Get-Content -LiteralPath $t) {
                if ($line -match '^URL=(.+)$') {
                    $u = $Matches[1].Trim()
                    if (Test-RipDemonUrlLike $u) { [void]$urls.Add((Normalize-RipDemonUrl $u)) }
                }
            }
            continue
        }
        if (Test-RipDemonUrlLike $t) { [void]$urls.Add((Normalize-RipDemonUrl $t)) }
    }
    Write-Output -NoEnumerate $urls
}

function Show-RipDemonUsage {
    $ver = '1.0.0'
    $vf = Join-Path $InstallRoot 'version.txt'
    if (Test-Path -LiteralPath $vf) { $ver = (Get-Content -LiteralPath $vf -Raw).Trim() }
    Write-Host ''
    Write-Host "  RIP Demon $ver - media downloader (yt-dlp)"
    Write-Host '  by Opes - https://opes.dev'
    Write-Host ''
    Write-Host '  Usage:'
    Write-Host '    yt mp3 [options] [url|file ...]   Best-quality MP3'
    Write-Host '    yt mp4 [options] [url|file ...]   Video MP4 (quality preset)'
    Write-Host '    yt info [options] <url>           Show title, duration, formats'
    Write-Host '    yt gui                            Open the download window'
    Write-Host '    yt config                         Show config path and settings'
    Write-Host '    yt update                         Update RIP Demon + yt-dlp / ffmpeg / deno'
    Write-Host '    yt version                        Show versions'
    Write-Host '    yt uninstall                      Remove RIP Demon'
    Write-Host '    yt help                           Show this help'
    Write-Host ''
    Write-Host '  Omit the URL to use the clipboard when it looks like a link.'
    Write-Host '  Pass a .txt file (one URL per line) or multiple URLs to batch download.'
    Write-Host '  Works with YouTube and most sites supported by yt-dlp.'
    Write-Host ''
    Write-Host '  Options (mp3 / mp4 / info):'
    Write-Host '    --no-playlist                      Single video only'
    Write-Host '    --cookies-from-browser <name>      chrome, edge, firefox, ...'
    Write-Host '    -o <dir>  /  --output-dir <dir>   Override output folder'
    Write-Host '    --open                             Open output folder when done'
    Write-Host '    --quality <720|1080|best>          MP4 quality preset'
    Write-Host '    --720  /  --1080  /  --best        Shorthand quality presets'
    Write-Host '    --subs [lang]                      Write + embed subtitles (mp4)'
    Write-Host '    --sponsorblock                     Remove SponsorBlock segments (mp4)'
    Write-Host '    --thumbnail-only                   Save thumbnail only'
    Write-Host '    --                               Pass remaining args to yt-dlp'
    Write-Host ''
    Write-Host '  Config:  %LOCALAPPDATA%\RIP-Demon\config.ini'
    Write-Host '  Env:     RIPDEMON_MP3_DIR, RIPDEMON_MP4_DIR'
    Write-Host ''
    Write-Host '  Examples:'
    Write-Host '    yt mp3'
    Write-Host '    yt mp4 --1080 --open "https://youtu.be/VIDEO_ID"'
    Write-Host '    yt mp3 urls.txt'
    Write-Host '    yt mp4 --subs en --sponsorblock <url>'
    Write-Host '    yt info <url>'
    Write-Host '    yt mp3 -- --download-archive archive.txt <url>'
    Write-Host ''
}

function Invoke-RipDemonYtDlp {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Label = 'Downloading'
    )
    if (-not (Test-Path -LiteralPath $YtDlp)) {
        Write-Host "Error: yt-dlp not found at `"$YtDlp`"" -ForegroundColor Red
        Write-Host 'Run: yt update'
        return 1
    }
    $env:Path = "$ToolsDir;$env:Path"
    Write-Host ''
    Write-Host "  $Label..." -ForegroundColor Cyan
    & $YtDlp @Arguments
    # PS 5.1 can leave $LASTEXITCODE $null after a successful native exe — treat null as 0.
    $code = $LASTEXITCODE
    if ($null -eq $code) {
        $code = if ($?) { 0 } else { 1 }
    }
    return [int]$code
}

function Get-RipDemonMp4Format {
    param([string]$Quality)
    $q = $Quality.ToLowerInvariant()
    if ($Mp4Formats.ContainsKey($q)) { return $Mp4Formats[$q] }
    return $Mp4Formats['1080']
}

function Invoke-RipDemonDownload {
    param(
        [Parameter(Mandatory)][ValidateSet('mp3', 'mp4')][string]$Mode,
        [string[]]$Targets,
        [hashtable]$Opt
    )

    if (-not $Targets -or $Targets.Count -eq 0) {
        Write-Host 'Error: missing URL.' -ForegroundColor Red
        Write-Host 'Paste a link and run again, or: yt mp3 <url>'
        Write-Host 'Tip: quote URLs that contain & :  yt mp3 "https://...&list=..."'
        Show-RipDemonUsage
        return 1
    }

    $outDir = if ($Mode -eq 'mp3') { $Opt.Mp3Dir } else { $Opt.Mp4Dir }
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }

    $template = Join-Path $outDir '%(title)s [%(id)s].%(ext)s'
    $exit = 0
    $n = 0
    foreach ($url in $Targets) {
        $n++
        $prefix = if ($Targets.Count -gt 1) { "[$n/$($Targets.Count)] " } else { '' }
        Write-Host ''
        Write-Host "  ${prefix}URL: $url" -ForegroundColor White

        $yargs = New-Object System.Collections.Generic.List[string]
        $yargs.Add('--ffmpeg-location'); $yargs.Add($ToolsDir)
        $yargs.Add('--no-mtime')
        $yargs.Add('-o'); $yargs.Add($template)

        if ($Opt.NoPlaylist) { $yargs.Add('--no-playlist') }
        if ($Opt.CookiesBrowser) {
            $yargs.Add('--cookies-from-browser'); $yargs.Add($Opt.CookiesBrowser)
        }

        if ($Opt.ThumbnailOnly) {
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
            $yargs.Add('-f'); $yargs.Add((Get-RipDemonMp4Format -Quality $Opt.Quality))
            $yargs.Add('--merge-output-format'); $yargs.Add('mp4')
            $yargs.Add('--embed-metadata')
            if ($Opt.SponsorBlock) {
                $yargs.Add('--sponsorblock-remove'); $yargs.Add('default')
            }
            if ($Opt.Subs) {
                $yargs.Add('--write-subs')
                $yargs.Add('--embed-subs')
                if ($Opt.SubsLang) {
                    $yargs.Add('--sub-langs'); $yargs.Add($Opt.SubsLang)
                } else {
                    $yargs.Add('--sub-langs'); $yargs.Add('en.*,en')
                }
            }
        }

        if ($Opt.Passthrough) {
            foreach ($p in $Opt.Passthrough) { $yargs.Add([string]$p) }
        }
        $yargs.Add('--')
        $yargs.Add($url)

        $code = Invoke-RipDemonYtDlp -Arguments $yargs.ToArray() -Label "${prefix}Downloading"
        if ($code -ne 0) {
            $exit = $code
            Write-Host ''
            Write-Host '  Download failed.' -ForegroundColor Red
            Write-Host '  Try: yt update'
            Write-Host '       yt mp3 --cookies-from-browser chrome <url>'
            Write-Host '       Quote URLs that contain &'
            continue
        }

        Write-Host ''
        Write-Host '  Done.' -ForegroundColor Green
        Write-Host "  Saved to: $outDir" -ForegroundColor Green
    }

    if ($Opt.OpenAfter -and $exit -eq 0) {
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList $outDir | Out-Null } catch {}
    }

    return $exit
}

function Invoke-RipDemonInfo {
    param(
        [string[]]$Targets,
        [hashtable]$Opt
    )
    if (-not $Targets -or $Targets.Count -eq 0) {
        Write-Host 'Error: missing URL for yt info.' -ForegroundColor Red
        return 1
    }

    $exit = 0
    foreach ($url in $Targets) {
        Write-Host ''
        Write-Host "  URL: $url" -ForegroundColor White
        $yargs = New-Object System.Collections.Generic.List[string]
        $yargs.Add('--ffmpeg-location'); $yargs.Add($ToolsDir)
        $yargs.Add('--no-download')
        $yargs.Add('--print'); $yargs.Add('TITLE:%(title)s')
        $yargs.Add('--print'); $yargs.Add('ID:%(id)s')
        $yargs.Add('--print'); $yargs.Add('DURATION:%(duration_string)s')
        $yargs.Add('--print'); $yargs.Add('UPLOADER:%(uploader)s')
        $yargs.Add('--print'); $yargs.Add('URL:%(webpage_url)s')
        if ($Opt.NoPlaylist) { $yargs.Add('--no-playlist') }
        if ($Opt.CookiesBrowser) {
            $yargs.Add('--cookies-from-browser'); $yargs.Add($Opt.CookiesBrowser)
        }
        foreach ($p in $Opt.Passthrough) { $yargs.Add($p) }
        $yargs.Add('--')
        $yargs.Add($url)

        $code = Invoke-RipDemonYtDlp -Arguments $yargs.ToArray() -Label 'Fetching info'
        if ($code -ne 0) { $exit = $code; continue }

        Write-Host ''
        Write-Host '  Available formats:' -ForegroundColor Cyan
        $listArgs = New-Object System.Collections.Generic.List[string]
        $listArgs.Add('--ffmpeg-location'); $listArgs.Add($ToolsDir)
        if ($Opt.NoPlaylist) { $listArgs.Add('--no-playlist') }
        if ($Opt.CookiesBrowser) {
            $listArgs.Add('--cookies-from-browser'); $listArgs.Add($Opt.CookiesBrowser)
        }
        $listArgs.Add('-F')
        $listArgs.Add('--')
        $listArgs.Add($url)
        & $YtDlp @($listArgs.ToArray())
        $fmtCode = $LASTEXITCODE
        if ($null -eq $fmtCode) { $fmtCode = if ($?) { 0 } else { 1 } }
        if ($fmtCode -ne 0) { $exit = [int]$fmtCode }
    }
    return $exit
}

function Show-RipDemonConfig {
    $cfg = Get-RipDemonConfig -InstallRoot $InstallRoot -DefaultConfigPath $DefaultConfigPath
    Write-Host ''
    Write-Host '  RIP Demon config' -ForegroundColor Cyan
    Write-Host '  by Opes - https://opes.dev' -ForegroundColor DarkGray
    Write-Host "  File: $($cfg.ConfigPath)"
    if (-not (Test-Path -LiteralPath $cfg.ConfigPath)) {
        Write-Host '  (no user config yet — using defaults)' -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host "  mp3_dir:         $($cfg.Mp3Dir)"
    Write-Host "  mp4_dir:         $($cfg.Mp4Dir)"
    Write-Host "  quality:         $($cfg.Quality)"
    Write-Host "  cookies_browser: $(if ($cfg.CookiesBrowser) { $cfg.CookiesBrowser } else { '(none)' })"
    Write-Host "  no_playlist:     $($cfg.NoPlaylist)"
    Write-Host "  open_after:      $($cfg.OpenAfter)"
    Write-Host "  sponsorblock:    $($cfg.SponsorBlock)"
    Write-Host ''
    return 0
}

function Parse-RipDemonCli {
    param($Raw)

    $tokens = Repair-RipDemonArgList -Tokens $Raw
    if ($tokens.Count -eq 0) {
        return @{ Command = 'help'; Opt = $null }
    }

    $cmd = ([string]$tokens[0]).ToLowerInvariant()
    $rest = New-Object System.Collections.Generic.List[string]
    for ($ri = 1; $ri -lt $tokens.Count; $ri++) {
        [void]$rest.Add([string]$tokens[$ri])
    }

    $cfg = Get-RipDemonConfig -InstallRoot $InstallRoot -DefaultConfigPath $DefaultConfigPath
    $opt = @{
        Mp3Dir         = $cfg.Mp3Dir
        Mp4Dir         = $cfg.Mp4Dir
        Quality        = $cfg.Quality
        CookiesBrowser = $cfg.CookiesBrowser
        NoPlaylist     = [bool]$cfg.NoPlaylist
        OpenAfter      = [bool]$cfg.OpenAfter
        SponsorBlock   = [bool]$cfg.SponsorBlock
        Subs           = $false
        SubsLang       = $null
        ThumbnailOnly  = $false
        Passthrough    = New-Object System.Collections.Generic.List[string]
        Targets        = @()
    }

    $positional = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $rest.Count) {
        $a = [string]$rest[$i]
        if ($a -eq '--') {
            $i++
            while ($i -lt $rest.Count) {
                [void]$opt.Passthrough.Add($rest[$i])
                $i++
            }
            break
        }
        if ($a -eq '--no-playlist') { $opt.NoPlaylist = $true; $i++; continue }
        if ($a -eq '--open') { $opt.OpenAfter = $true; $i++; continue }
        if ($a -eq '--sponsorblock') { $opt.SponsorBlock = $true; $i++; continue }
        if ($a -eq '--thumbnail-only') { $opt.ThumbnailOnly = $true; $i++; continue }
        if ($a -eq '--720') { $opt.Quality = '720'; $i++; continue }
        if ($a -eq '--1080') { $opt.Quality = '1080'; $i++; continue }
        if ($a -eq '--best') { $opt.Quality = 'best'; $i++; continue }
        if ($a -eq '--quality') {
            if (($i + 1) -ge $rest.Count) { throw 'Error: --quality requires 720, 1080, or best.' }
            $q = $rest[$i + 1].ToLowerInvariant()
            if ($q -notin @('720', '1080', 'best')) { throw "Error: unknown quality '$q' (use 720, 1080, best)." }
            $opt.Quality = $q
            $i += 2
            continue
        }
        if ($a -eq '--cookies-from-browser') {
            if (($i + 1) -ge $rest.Count) { throw 'Error: --cookies-from-browser requires a browser name (e.g. chrome, edge, firefox).' }
            $opt.CookiesBrowser = $rest[$i + 1]
            $i += 2
            continue
        }
        if ($a -eq '-o' -or $a -eq '--output-dir') {
            if (($i + 1) -ge $rest.Count) { throw 'Error: -o / --output-dir requires an output directory.' }
            $opt.Mp3Dir = $rest[$i + 1]
            $opt.Mp4Dir = $rest[$i + 1]
            $i += 2
            continue
        }
        if ($a -eq '--subs') {
            $opt.Subs = $true
            if (($i + 1) -lt $rest.Count -and $rest[$i + 1] -notmatch '^-' -and -not (Test-RipDemonUrlLike $rest[$i + 1]) -and -not ((Test-Path -LiteralPath $rest[$i + 1]) -and $rest[$i + 1] -match '\.(txt|list|url)$')) {
                $opt.SubsLang = $rest[$i + 1]
                $i += 2
            } else {
                $i++
            }
            continue
        }
        $positional.Add($a)
        $i++
    }

    $targets = Resolve-RipDemonTargets -Tokens $positional
    if ($targets.Count -eq 0 -and $cmd -in @('mp3', 'mp4', 'info')) {
        $clip = Get-RipDemonClipboardText
        if ($clip) {
            $first = ($clip -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1
            if ($first -and (Test-RipDemonUrlLike $first)) {
                $targets = @((Normalize-RipDemonUrl $first))
                Write-Host "  Using clipboard: $($targets[0])" -ForegroundColor DarkGray
            }
        }
    }

    $opt.Targets = @($targets)
    return @{ Command = $cmd; Opt = $opt }
}

# --- Main --------------------------------------------------------------------

try {
    # $args from powershell -File script.ps1 arg1 arg2
    $normalized = ConvertTo-RipDemonArgList -Tokens $args

    $parsed = Parse-RipDemonCli -Raw $normalized
    $cmd = $parsed.Command

    switch ($cmd) {
        { $_ -in @('help', '-h', '--help', '/?') } { Show-RipDemonUsage; exit 0 }
        'config' { exit (Show-RipDemonConfig) }
        'mp3' { exit (Invoke-RipDemonDownload -Mode mp3 -Targets $parsed.Opt.Targets -Opt $parsed.Opt) }
        'mp4' { exit (Invoke-RipDemonDownload -Mode mp4 -Targets $parsed.Opt.Targets -Opt $parsed.Opt) }
        'info' { exit (Invoke-RipDemonInfo -Targets $parsed.Opt.Targets -Opt $parsed.Opt) }
        'gui' {
            $gui = Join-Path $InstallRoot 'gui\RipDemon.Gui.ps1'
            if (-not (Test-Path -LiteralPath $gui)) {
                Write-Host 'Error: GUI script not found. Re-run the installer.' -ForegroundColor Red
                exit 1
            }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gui
            exit $LASTEXITCODE
        }
        default {
            Write-Host "Error: unknown command '$cmd'." -ForegroundColor Red
            Write-Host ''
            Show-RipDemonUsage
            exit 1
        }
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
