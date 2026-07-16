#Requires -Version 5.1
# Shared config helpers — dot-source from Cli, GUI, Install

function Get-RipDemonDefaultOutputDirs {
    [pscustomobject]@{
        Mp3 = Join-Path $env:USERPROFILE 'Music\RIP Demon\MP3'
        Mp4 = Join-Path $env:USERPROFILE 'Videos\RIP Demon\MP4'
    }
}

function Get-RipDemonConfigPath {
    param([string]$InstallRoot)
    if (-not $InstallRoot) {
        $InstallRoot = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
    }
    return (Join-Path $InstallRoot 'config.ini')
}

function Read-RipDemonIni {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    $section = ''
    foreach ($raw in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim().ToLowerInvariant()
            continue
        }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim().ToLowerInvariant()
            $val = $Matches[2].Trim()
            $map["$section.$key"] = $val
        }
    }
    return $map
}

function Get-RipDemonIniBool {
    param([string]$Value, [bool]$Default = $false)
    if ($null -eq $Value -or $Value -eq '') { return $Default }
    switch -Regex ($Value.Trim()) {
        '^(1|true|yes|on)$' { return $true }
        '^(0|false|no|off)$' { return $false }
        default { return $Default }
    }
}

function Test-RipDemonCookieDecryptError {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    # Chrome/Edge App-Bound Encryption often breaks --cookies-from-browser on Windows.
    # See https://github.com/yt-dlp/yt-dlp/issues/10927
    return [bool]($Text -match '(?i)Failed to decrypt with DPAPI|failed to decrypt.*(cookie|DPAPI)|Could not copy Chrome cookie|Aborting since cookies could not be decrypted')
}

function Remove-RipDemonCookiesFromBrowserArgs {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$ArgumentList
    )
    for ($i = $ArgumentList.Count - 2; $i -ge 0; $i--) {
        if ($ArgumentList[$i] -eq '--cookies-from-browser') {
            $ArgumentList.RemoveAt($i + 1)
            $ArgumentList.RemoveAt($i)
        }
    }
}

function Get-RipDemonConfig {
    param(
        [string]$InstallRoot,
        [string]$DefaultConfigPath
    )
    if (-not $InstallRoot) {
        $InstallRoot = Join-Path $env:LOCALAPPDATA 'RIP-Demon'
    }
    $configPath = Get-RipDemonConfigPath -InstallRoot $InstallRoot
    $defaults = Get-RipDemonDefaultOutputDirs
    $ini = @{}
    if ($DefaultConfigPath -and (Test-Path -LiteralPath $DefaultConfigPath)) {
        $ini = Read-RipDemonIni -Path $DefaultConfigPath
    }
    if (Test-Path -LiteralPath $configPath) {
        $user = Read-RipDemonIni -Path $configPath
        foreach ($k in @($user.Keys)) { $ini[$k] = $user[$k] }
    }

    $mp3 = $ini['paths.mp3_dir']
    $mp4 = $ini['paths.mp4_dir']
    if (-not $mp3) { $mp3 = $defaults.Mp3 }
    if (-not $mp4) { $mp4 = $defaults.Mp4 }
    if ($env:RIPDEMON_MP3_DIR) { $mp3 = $env:RIPDEMON_MP3_DIR }
    if ($env:RIPDEMON_MP4_DIR) { $mp4 = $env:RIPDEMON_MP4_DIR }

    $quality = '1080'
    if ($ini['defaults.quality']) { $quality = $ini['defaults.quality'].Trim().ToLowerInvariant() }
    if ($quality -notin @('720', '1080', 'best')) { $quality = '1080' }

    [pscustomobject]@{
        InstallRoot    = $InstallRoot
        ConfigPath     = $configPath
        Mp3Dir         = $mp3
        Mp4Dir         = $mp4
        Quality        = $quality
        CookiesBrowser = $(if ($ini['defaults.cookies_browser']) { $ini['defaults.cookies_browser'].Trim() } else { '' })
        NoPlaylist     = (Get-RipDemonIniBool $ini['defaults.no_playlist'] $false)
        OpenAfter      = (Get-RipDemonIniBool $ini['defaults.open_after'] $false)
        SponsorBlock   = (Get-RipDemonIniBool $ini['defaults.sponsorblock'] $false)
    }
}

function Write-RipDemonUserConfig {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [string]$Mp3Dir,
        [string]$Mp4Dir,
        [string]$Quality = '1080',
        [string]$CookiesBrowser = '',
        [bool]$NoPlaylist = $false,
        [bool]$OpenAfter = $false,
        [bool]$SponsorBlock = $false
    )
    $defaults = Get-RipDemonDefaultOutputDirs
    if (-not $Mp3Dir) { $Mp3Dir = $defaults.Mp3 }
    if (-not $Mp4Dir) { $Mp4Dir = $defaults.Mp4 }
    $path = Get-RipDemonConfigPath -InstallRoot $InstallRoot
    $tf = { param($b) if ($b) { 'true' } else { 'false' } }
    $lines = @(
        '; RIP Demon user settings (by Opes - https://opes.dev)',
        '; Edit this file, run yt config, or re-run the installer wizard.',
        '',
        '[paths]',
        "mp3_dir=$Mp3Dir",
        "mp4_dir=$Mp4Dir",
        '',
        '[defaults]',
        "quality=$Quality",
        "cookies_browser=$CookiesBrowser",
        "no_playlist=$(& $tf $NoPlaylist)",
        "open_after=$(& $tf $OpenAfter)",
        "sponsorblock=$(& $tf $SponsorBlock)",
        ''
    )
    Set-Content -Path $path -Value $lines -Encoding UTF8
    return $path
}
