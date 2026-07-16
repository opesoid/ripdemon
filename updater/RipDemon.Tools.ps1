# RIP Demon - shared tool download helpers
# Dot-source from Install.ps1 and Update.ps1

$ErrorActionPreference = 'Stop'

function Get-RipDemonRoot {
    param([string]$Override)
    if ($Override) { return $Override }
    if ($env:RIPDEMON_ROOT) { return $env:RIPDEMON_ROOT }
    return (Join-Path $env:LOCALAPPDATA 'RIP-Demon')
}

function Get-RipDemonOutputDirs {
    <#
    .SYNOPSIS
      Canonical MP3/MP4 output folders (defaults; user config.ini may override).
      Keep in sync with src\lib\ripdemon-config.cmd and RipDemon.Config.ps1.
    #>
    [pscustomobject]@{
        Mp3 = Join-Path $env:USERPROFILE 'Music\RIP Demon\MP3'
        Mp4 = Join-Path $env:USERPROFILE 'Videos\RIP Demon\MP4'
    }
}

function Write-RipDemonBanner {
    param([string]$Title = 'RIP Demon')
    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor DarkRed
    Write-Host "   $Title" -ForegroundColor Red
    Write-Host '  ========================================' -ForegroundColor DarkRed
    Write-Host ''
}

function Get-RipDemonGitHubHeaders {
    @{
        'User-Agent' = 'RIP-Demon'
        'Accept'     = 'application/vnd.github+json'
    }
}

function Assert-RipDemonWindowsX64 {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -and $arch -ine 'AMD64') {
        $hint = if ($arch -match 'ARM') {
            'ARM64 Windows is not supported yet (bundled deno/FFmpeg builds are x64-only). Use an x64 PC or x64 emulation environment.'
        } else {
            '32-bit Windows is not supported (bundled tools are x64-only).'
        }
        throw "RIP Demon requires 64-bit Intel/AMD Windows (detected: $arch). $hint"
    }
}

function Save-RipDemonFile {
    <#
    .SYNOPSIS
      Fast file download. Prefer curl.exe — Invoke-WebRequest progress UI is extremely slow.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$Label = 'Downloading...',
        [string]$ExpectedSize,
        [string]$ExpectedSha256,
        [long]$ExpectedByteSize = 0
    )

    $outDir = Split-Path -Parent $OutFile
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }

    $sizeHint = if ($ExpectedSize) { " (~$ExpectedSize)" } else { '' }
    Write-Host "  $Label$sizeHint" -ForegroundColor Yellow
    Write-Host '  This can take a few minutes on slow connections...' -ForegroundColor DarkGray

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        # --progress-bar shows a simple meter; avoid PowerShell's slow Write-Progress wrapper
        $args = @(
            '-L', '--fail', '--retry', '3', '--retry-delay', '2',
            '--connect-timeout', '30',
            '--progress-bar',
            '-o', $OutFile,
            $Uri
        )
        & curl.exe @args
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed (curl exit $LASTEXITCODE): $Uri"
        }
        if (-not (Test-Path $OutFile) -or ((Get-Item $OutFile).Length -lt 1KB)) {
            throw "Download produced an empty/missing file: $OutFile"
        }
    }
    else {
        # Fallback: hide progress (showing it makes Invoke-WebRequest dramatically slower)
        Write-Host '  curl.exe not found — using slower PowerShell download.' -ForegroundColor DarkYellow
        $prev = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        }
        finally {
            $ProgressPreference = $prev
        }
    }

    if ($ExpectedByteSize -gt 0) {
        $actual = (Get-Item -LiteralPath $OutFile).Length
        if ($actual -ne $ExpectedByteSize) {
            Remove-Item -Force -ErrorAction SilentlyContinue $OutFile
            throw "Download size mismatch for $OutFile (expected $ExpectedByteSize bytes, got $actual)."
        }
    }

    if ($ExpectedSha256) {
        Assert-RipDemonFileSha256 -Path $OutFile -ExpectedSha256 $ExpectedSha256
    }
}

function Assert-RipDemonFileSha256 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    $expected = $ExpectedSha256.Trim().ToLowerInvariant() -replace '^sha256:', ''
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Remove-Item -Force -ErrorAction SilentlyContinue $Path
        throw "SHA256 mismatch for $Path`n  expected: $expected`n  actual:   $actual"
    }
    Write-Host '  SHA256 verified.' -ForegroundColor DarkGray
}

function Get-AssetDigestSha256 {
    param($Asset)
    if (-not $Asset) { return $null }
    if ($Asset.digest -and ($Asset.digest -match '^sha256:([a-fA-F0-9]{64})$')) {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}

function Get-Sha256FromSumFile {
    param(
        [Parameter(Mandatory)][string]$SumFileUri,
        [Parameter(Mandatory)][string]$FileName
    )
    $tmp = Join-Path $env:TEMP ("ripdemon-sums-{0}.txt" -f [guid]::NewGuid().ToString('N'))
    try {
        $prev = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $SumFileUri -OutFile $tmp -UseBasicParsing -Headers (Get-RipDemonGitHubHeaders)
        }
        finally {
            $ProgressPreference = $prev
        }
        foreach ($line in Get-Content -LiteralPath $tmp) {
            $trim = $line.Trim()
            if (-not $trim -or $trim.StartsWith('#')) { continue }
            # GNU: "<hash>  <filename>" or "<hash> *<filename>"
            if ($trim -match '^([a-fA-F0-9]{64})\s+\*?(.+)$') {
                $hash = $Matches[1].ToLowerInvariant()
                $name = $Matches[2].Trim().TrimStart('*').Replace('\', '/').Split('/')[-1]
                if ($name -ieq $FileName) { return $hash }
            }
        }
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmp
    }
    return $null
}

function Get-YtDlpLatestRelease {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest' -Headers (Get-RipDemonGitHubHeaders)
    $asset = $release.assets | Where-Object { $_.name -eq 'yt-dlp.exe' } | Select-Object -First 1
    if (-not $asset) {
        throw 'Could not find yt-dlp.exe in the latest yt-dlp release.'
    }

    $sha = Get-AssetDigestSha256 -Asset $asset
    if (-not $sha) {
        $sumsAsset = $release.assets | Where-Object { $_.name -eq 'SHA2-256SUMS' } | Select-Object -First 1
        if ($sumsAsset) {
            $sha = Get-Sha256FromSumFile -SumFileUri $sumsAsset.browser_download_url -FileName 'yt-dlp.exe'
        }
    }
    if (-not $sha) {
        throw 'Could not obtain SHA256 for yt-dlp.exe (missing digest / SHA2-256SUMS).'
    }

    [pscustomobject]@{
        Tag     = $release.tag_name.TrimStart('v')
        Version = $release.tag_name.TrimStart('v')
        Url     = $asset.browser_download_url
        Size    = [long]$asset.size
        Sha256  = $sha
    }
}

function Get-InstalledYtDlpVersion {
    param([string]$YtDlpPath)
    if (-not (Test-Path $YtDlpPath)) { return $null }
    try {
        $out = & $YtDlpPath --version 2>$null
        if ($out) { return ($out | Select-Object -First 1).ToString().Trim() }
    } catch {}
    return $null
}

function Install-YtDlp {
    param(
        [Parameter(Mandatory)][string]$ToolsDir,
        [switch]$Force
    )
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    $dest = Join-Path $ToolsDir 'yt-dlp.exe'
    $latest = Get-YtDlpLatestRelease
    $current = Get-InstalledYtDlpVersion -YtDlpPath $dest

    if (-not $Force -and $current -and ($current -eq $latest.Version)) {
        Write-Host "  yt-dlp $current is already up to date." -ForegroundColor Green
        return [pscustomobject]@{ Updated = $false; Version = $current }
    }

    $label = if ($current) {
        "Updating yt-dlp $current -> $($latest.Version)"
    } else {
        "Downloading yt-dlp $($latest.Version)"
    }

    $tmp = Join-Path $ToolsDir 'yt-dlp.exe.new'
    $mb = if ($latest.Size) { '{0:N0} MB' -f ($latest.Size / 1MB) } else { $null }
    Save-RipDemonFile -Uri $latest.Url -OutFile $tmp -Label $label -ExpectedSize $mb `
        -ExpectedSha256 $latest.Sha256 -ExpectedByteSize $latest.Size
    Move-Item -Force -Path $tmp -Destination $dest
    Write-Host "  yt-dlp $($latest.Version) ready." -ForegroundColor Green
    return [pscustomobject]@{ Updated = $true; Version = $latest.Version }
}

function Get-FfmpegDownloadUrl {
    # Prefer shared build (~76MB) over static (~161MB) for faster installs
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/yt-dlp/FFmpeg-Builds/releases/latest' -Headers (Get-RipDemonGitHubHeaders)
    $asset = $release.assets | Where-Object {
        $_.name -match 'ffmpeg-.*?-win64-gpl-shared\.zip$'
    } | Select-Object -First 1
    if (-not $asset) {
        $asset = $release.assets | Where-Object {
            $_.name -match 'ffmpeg-.*?-win64-gpl\.zip$' -and $_.name -notmatch 'shared'
        } | Select-Object -First 1
    }
    if (-not $asset) {
        throw 'Could not find a win64 gpl FFmpeg zip in yt-dlp/FFmpeg-Builds releases.'
    }

    $sha = Get-AssetDigestSha256 -Asset $asset
    return [pscustomobject]@{
        Tag    = $release.tag_name
        Url    = $asset.browser_download_url
        Name   = $asset.name
        Size   = [long]$asset.size
        Sha256 = $sha
    }
}

function Get-InstalledFfmpegTag {
    param([string]$ToolsDir)
    $marker = Join-Path $ToolsDir 'ffmpeg.version'
    if (Test-Path -LiteralPath $marker) {
        return (Get-Content -LiteralPath $marker -Raw).Trim()
    }
    return $null
}

function Set-InstalledFfmpegTag {
    param(
        [Parameter(Mandatory)][string]$ToolsDir,
        [Parameter(Mandatory)][string]$Tag
    )
    Set-Content -Path (Join-Path $ToolsDir 'ffmpeg.version') -Value $Tag -NoNewline
}

function Install-Ffmpeg {
    param(
        [Parameter(Mandatory)][string]$ToolsDir,
        [switch]$Force
    )
    Assert-RipDemonWindowsX64
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    $ffmpeg = Join-Path $ToolsDir 'ffmpeg.exe'
    $ffprobe = Join-Path $ToolsDir 'ffprobe.exe'
    $info = Get-FfmpegDownloadUrl
    $currentTag = Get-InstalledFfmpegTag -ToolsDir $ToolsDir

    if (-not $Force -and (Test-Path $ffmpeg) -and (Test-Path $ffprobe) -and $currentTag -and ($currentTag -eq $info.Tag)) {
        Write-Host "  ffmpeg $($info.Tag) is already up to date." -ForegroundColor Green
        return [pscustomobject]@{ Updated = $false; Tag = $currentTag }
    }

    if (-not $Force -and (Test-Path $ffmpeg) -and (Test-Path $ffprobe) -and -not $currentTag) {
        # Legacy install without version marker — refresh once to pin a tag
        Write-Host '  ffmpeg present but untagged — refreshing to pin release tag.' -ForegroundColor Yellow
    }

    $mb = if ($info.Size) { '{0:N0} MB' -f ($info.Size / 1MB) } else { '~80 MB' }
    $zipPath = Join-Path $env:TEMP ("ripdemon-ffmpeg-{0}.zip" -f [guid]::NewGuid().ToString('N'))
    $extractDir = Join-Path $env:TEMP ("ripdemon-ffmpeg-{0}" -f [guid]::NewGuid().ToString('N'))

    try {
        $saveParams = @{
            Uri              = $info.Url
            OutFile          = $zipPath
            Label            = "Downloading FFmpeg $($info.Tag) (yt-dlp builds)"
            ExpectedSize     = $mb
            ExpectedByteSize = $info.Size
        }
        if ($info.Sha256) {
            $saveParams.ExpectedSha256 = $info.Sha256
        }
        else {
            Write-Host '  No SHA256 digest published for this FFmpeg asset — verifying size only.' -ForegroundColor DarkYellow
        }
        Save-RipDemonFile @saveParams

        Write-Host '  Extracting FFmpeg...' -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $binDir = Get-ChildItem -Path $extractDir -Recurse -Directory -Filter 'bin' |
            Where-Object { Test-Path (Join-Path $_.FullName 'ffmpeg.exe') } |
            Select-Object -First 1

        if (-not $binDir) {
            throw 'FFmpeg zip did not contain a bin\ffmpeg.exe.'
        }

        Copy-Item -Force (Join-Path $binDir.FullName 'ffmpeg.exe') $ffmpeg
        Copy-Item -Force (Join-Path $binDir.FullName 'ffprobe.exe') $ffprobe
        # Shared builds need companion DLLs next to the exes
        Get-ChildItem -Path $binDir.FullName -Filter '*.dll' -ErrorAction SilentlyContinue |
            ForEach-Object { Copy-Item -Force $_.FullName (Join-Path $ToolsDir $_.Name) }
        Set-InstalledFfmpegTag -ToolsDir $ToolsDir -Tag $info.Tag
        Write-Host "  ffmpeg $($info.Tag) ready." -ForegroundColor Green
        return [pscustomobject]@{ Updated = $true; Tag = $info.Tag }
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $zipPath
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $extractDir
    }
}

function Get-DenoDownloadUrl {
    Assert-RipDemonWindowsX64
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/denoland/deno/releases/latest' -Headers (Get-RipDemonGitHubHeaders)
    $assetName = 'deno-x86_64-pc-windows-msvc.zip'
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find $assetName in the latest Deno release."
    }

    $sha = Get-AssetDigestSha256 -Asset $asset
    if (-not $sha) {
        $sumName = "$assetName.sha256sum"
        $sumAsset = $release.assets | Where-Object { $_.name -eq $sumName } | Select-Object -First 1
        if ($sumAsset) {
            $sha = Get-Sha256FromSumFile -SumFileUri $sumAsset.browser_download_url -FileName $assetName
        }
    }
    if (-not $sha) {
        # Deno sometimes publishes bare .sha256sum content as "hash  filename"
        $sumUrl = "$($asset.browser_download_url).sha256sum"
        try {
            $sha = Get-Sha256FromSumFile -SumFileUri $sumUrl -FileName $assetName
        } catch {}
    }
    if (-not $sha) {
        throw "Could not obtain SHA256 for $assetName."
    }

    [pscustomobject]@{
        Tag    = $release.tag_name.TrimStart('v')
        Url    = $asset.browser_download_url
        Name   = $asset.name
        Size   = [long]$asset.size
        Sha256 = $sha
    }
}

function Get-InstalledDenoVersion {
    param([string]$DenoPath)
    if (-not (Test-Path $DenoPath)) { return $null }
    try {
        $out = & $DenoPath --version 2>$null
        $line = $out | Where-Object { $_ -match '^deno\s+' } | Select-Object -First 1
        if ($line -match 'deno\s+(\S+)') { return $Matches[1] }
        if ($out) { return ($out | Select-Object -First 1).ToString().Trim() }
    } catch {}
    return $null
}

function Install-Deno {
    param(
        [Parameter(Mandatory)][string]$ToolsDir,
        [switch]$Force
    )
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    $dest = Join-Path $ToolsDir 'deno.exe'
    $latest = Get-DenoDownloadUrl
    $current = Get-InstalledDenoVersion -DenoPath $dest

    if (-not $Force -and $current -and ($current -eq $latest.Tag)) {
        Write-Host "  deno $current is already up to date." -ForegroundColor Green
        return [pscustomobject]@{ Updated = $false; Version = $current }
    }

    $label = if ($current) {
        "Updating deno $current -> $($latest.Tag)"
    } else {
        "Downloading deno $($latest.Tag)"
    }

    $zipPath = Join-Path $env:TEMP ("ripdemon-deno-{0}.zip" -f [guid]::NewGuid().ToString('N'))
    $extractDir = Join-Path $env:TEMP ("ripdemon-deno-{0}" -f [guid]::NewGuid().ToString('N'))
    $mb = if ($latest.Size) { '{0:N0} MB' -f ($latest.Size / 1MB) } else { '~40 MB' }

    try {
        Save-RipDemonFile -Uri $latest.Url -OutFile $zipPath -Label $label -ExpectedSize $mb `
            -ExpectedSha256 $latest.Sha256 -ExpectedByteSize $latest.Size
        Write-Host '  Extracting deno...' -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $denoExe = Get-ChildItem -Path $extractDir -Recurse -Filter 'deno.exe' | Select-Object -First 1
        if (-not $denoExe) {
            throw 'Deno zip did not contain deno.exe.'
        }
        Copy-Item -Force $denoExe.FullName $dest
        $installed = Get-InstalledDenoVersion -DenoPath $dest
        Write-Host "  deno $(if ($installed) { $installed } else { $latest.Tag }) ready." -ForegroundColor Green
        return [pscustomobject]@{ Updated = $true; Version = $(if ($installed) { $installed } else { $latest.Tag }) }
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $zipPath
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $extractDir
    }
}

function Ensure-RipDemonTools {
    param(
        [Parameter(Mandatory)][string]$ToolsDir,
        [switch]$ForceYtDlp,
        [switch]$ForceFfmpeg,
        [switch]$ForceDeno
    )
    Assert-RipDemonWindowsX64
    $yt = Install-YtDlp -ToolsDir $ToolsDir -Force:$ForceYtDlp
    $ff = Install-Ffmpeg -ToolsDir $ToolsDir -Force:$ForceFfmpeg
    $deno = Install-Deno -ToolsDir $ToolsDir -Force:$ForceDeno
    return [pscustomobject]@{ YtDlp = $yt; Ffmpeg = $ff; Deno = $deno }
}

# --- RIP Demon app source (opesoid/ripdemon main branch) ---

$script:RipDemonGitHubRepo = 'opesoid/ripdemon'
$script:RipDemonGitHubBranch = 'main'

function Normalize-RipDemonVersion {
    param([string]$Version)
    if (-not $Version) { return $null }
    $v = $Version.Trim() -replace '^[vV]', ''
    if ($v -match '^(\d+\.\d+\.\d+)') { return $Matches[1] }
    return $v
}

function Compare-RipDemonVersion {
    <#
    .SYNOPSIS
      Compare two x.y.z versions. Returns -1 if A < B, 0 if equal, 1 if A > B.
    #>
    param(
        [Parameter(Mandatory)][string]$VersionA,
        [Parameter(Mandatory)][string]$VersionB
    )
    $a = Normalize-RipDemonVersion $VersionA
    $b = Normalize-RipDemonVersion $VersionB
    if (-not $a -or -not $b) {
        throw "Invalid version(s) for compare: '$VersionA' vs '$VersionB'"
    }
    try {
        $va = [version]$a
        $vb = [version]$b
    } catch {
        throw "Invalid version(s) for compare: '$VersionA' vs '$VersionB'"
    }
    if ($va -lt $vb) { return -1 }
    if ($va -gt $vb) { return 1 }
    return 0
}

function Get-RipDemonRepoSource {
    <#
    .SYNOPSIS
      Latest RIP Demon sources from the GitHub main branch (no Releases required).
    #>
    $repo = $script:RipDemonGitHubRepo
    $branch = $script:RipDemonGitHubBranch
    $headers = Get-RipDemonGitHubHeaders

    $versionUrl = "https://raw.githubusercontent.com/$repo/$branch/VERSION"
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        $versionRaw = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -Headers $headers).Content
    } catch {
        throw "Failed to read VERSION from $repo@$branch`: $($_.Exception.Message)"
    } finally {
        $ProgressPreference = $prev
    }

    $version = Normalize-RipDemonVersion $versionRaw
    if (-not $version) {
        throw "Could not parse VERSION from $repo@$branch."
    }

    $commit = $null
    try {
        $commitApi = "https://api.github.com/repos/$repo/commits/$branch"
        $commitInfo = Invoke-RestMethod -Uri $commitApi -Headers $headers
        if ($commitInfo.sha) {
            $commit = $commitInfo.sha.ToString().ToLowerInvariant()
        }
    } catch {
        Write-Host "  Warning: could not resolve $branch commit SHA ($($_.Exception.Message))." -ForegroundColor DarkYellow
    }

    $zipName = "ripdemon-$branch.zip"
    $zipUrl = "https://github.com/$repo/archive/refs/heads/$branch.zip"

    [pscustomobject]@{
        Branch  = $branch
        Version = $version
        Commit  = $commit
        Url     = $zipUrl
        Name    = $zipName
    }
}

function Get-InstalledRipDemonCommit {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $marker = Join-Path $InstallRoot 'source.commit'
    if (Test-Path -LiteralPath $marker) {
        return (Get-Content -LiteralPath $marker -Raw).Trim().ToLowerInvariant()
    }
    return $null
}

function Set-InstalledRipDemonCommit {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [string]$Commit
    )
    $marker = Join-Path $InstallRoot 'source.commit'
    if ($Commit) {
        Set-Content -Path $marker -Value $Commit -NoNewline
    }
}

function Resolve-RipDemonProjectRoot {
    param([Parameter(Mandatory)][string]$ExtractDir)
    if (Test-Path -LiteralPath (Join-Path $ExtractDir 'src\yt.cmd')) {
        return $ExtractDir
    }
    $child = Get-ChildItem -LiteralPath $ExtractDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'src\yt.cmd') } |
        Select-Object -First 1
    if ($child) { return $child.FullName }
    throw "Could not find RIP Demon project root under $ExtractDir (missing src\yt.cmd)."
}

function Copy-RipDemonAppFiles {
    <#
    .SYNOPSIS
      Copy app files from a project/release tree into an install root.
      Does not touch config.ini or tools\.
    #>
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$InstallRoot
    )

    $binDir     = Join-Path $InstallRoot 'bin'
    $libDir     = Join-Path $InstallRoot 'lib'
    $guiDir     = Join-Path $InstallRoot 'gui'
    $toolsDir   = Join-Path $InstallRoot 'tools'
    $updaterDir = Join-Path $InstallRoot 'updater'

    foreach ($d in @($InstallRoot, $binDir, $libDir, $guiDir, $toolsDir, $updaterDir)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }

    $srcYt   = Join-Path $ProjectRoot 'src\yt.cmd'
    $srcLib  = Join-Path $ProjectRoot 'src\lib'
    $srcGui  = Join-Path $ProjectRoot 'src\gui'
    $srcUpd  = Join-Path $ProjectRoot 'updater'
    $srcUnin = Join-Path $ProjectRoot 'installer\Uninstall.ps1'

    if (-not (Test-Path -LiteralPath $srcYt)) {
        throw "Missing source file: $srcYt - run installer from the RIP-Demon project folder."
    }

    $versionFile = Join-Path $ProjectRoot 'VERSION'
    if (-not (Test-Path -LiteralPath $versionFile)) {
        $versionFile = Join-Path $InstallRoot 'version.txt'
    }
    $version = if (Test-Path -LiteralPath $versionFile) {
        (Get-Content -LiteralPath $versionFile -Raw).Trim()
    } else {
        '1.0.0'
    }

    Copy-Item -Force $srcYt (Join-Path $binDir 'yt.cmd')
    Copy-Item -Force (Join-Path $srcLib '*') $libDir
    if (Test-Path -LiteralPath $srcGui) {
        Copy-Item -Force (Join-Path $srcGui '*') $guiDir
    }
    Copy-Item -Force (Join-Path $srcUpd 'Update.ps1') $updaterDir
    Copy-Item -Force (Join-Path $srcUpd 'RipDemon.Tools.ps1') $updaterDir
    if (Test-Path -LiteralPath $srcUnin) {
        Copy-Item -Force $srcUnin (Join-Path $InstallRoot 'Uninstall.ps1')
    }
    $uninCmd = Join-Path $ProjectRoot 'installer\Uninstall.cmd'
    if (Test-Path -LiteralPath $uninCmd) {
        Copy-Item -Force $uninCmd (Join-Path $InstallRoot 'Uninstall.cmd')
    }
    $updCmd = Join-Path $ProjectRoot 'installer\Update.cmd'
    if (Test-Path -LiteralPath $updCmd) {
        Copy-Item -Force $updCmd (Join-Path $InstallRoot 'Update.cmd')
    }
    Set-Content -Path (Join-Path $InstallRoot 'version.txt') -Value $version -NoNewline
    foreach ($doc in @('README.md', 'LICENSE', 'CHANGELOG.md')) {
        $src = Join-Path $ProjectRoot $doc
        if (Test-Path -LiteralPath $src) {
            Copy-Item -Force $src (Join-Path $InstallRoot $doc)
        }
    }

    return [pscustomobject]@{
        Version = $version
        BinDir  = $binDir
    }
}

function Install-RipDemonAppFromZip {
    <#
    .SYNOPSIS
      Extract a release zip and copy app files into InstallRoot (keeps config.ini / tools).
    #>
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$InstallRoot
    )

    $extractDir = Join-Path $env:TEMP ("ripdemon-app-{0}" -f [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
        Write-Host '  Extracting RIP Demon package...' -ForegroundColor Cyan
        Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force
        $projectRoot = Resolve-RipDemonProjectRoot -ExtractDir $extractDir
        $result = Copy-RipDemonAppFiles -ProjectRoot $projectRoot -InstallRoot $InstallRoot
        Write-Host "  Application files updated to $($result.Version)." -ForegroundColor Green
        return $result
    }
    finally {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $extractDir
    }
}

function Update-RipDemonApp {
    <#
    .SYNOPSIS
      Download RIP Demon from GitHub main and replace app files if changed (or -Force).
    #>
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [switch]$Force
    )

    $versionFile = Join-Path $InstallRoot 'version.txt'
    $current = if (Test-Path -LiteralPath $versionFile) {
        (Get-Content -LiteralPath $versionFile -Raw).Trim()
    } else {
        $null
    }
    $currentCommit = Get-InstalledRipDemonCommit -InstallRoot $InstallRoot

    Write-Host '  Checking GitHub main for RIP Demon updates...' -ForegroundColor Cyan
    $latest = Get-RipDemonRepoSource

    $sameVersion = $false
    if ($current) {
        try {
            $sameVersion = (Compare-RipDemonVersion -VersionA $current -VersionB $latest.Version) -eq 0
        } catch {
            $sameVersion = ($current -eq $latest.Version)
        }
    }
    $sameCommit = $latest.Commit -and $currentCommit -and ($currentCommit -eq $latest.Commit)

    if (-not $Force -and $current -and $sameVersion -and ($sameCommit -or -not $latest.Commit)) {
        $label = if ($currentCommit) { "$current ($($currentCommit.Substring(0, [Math]::Min(7, $currentCommit.Length))))" } else { $current }
        Write-Host "  RIP Demon $label is already up to date." -ForegroundColor Green
        return [pscustomobject]@{
            Updated = $false
            Version = $current
            Latest  = $latest.Version
            Commit  = $currentCommit
        }
    }

    if ($current) {
        $from = if ($currentCommit) { "$current@$($currentCommit.Substring(0, [Math]::Min(7, $currentCommit.Length)))" } else { $current }
        $to = if ($latest.Commit) { "$($latest.Version)@$($latest.Commit.Substring(0, 7))" } else { $latest.Version }
        if ($Force) {
            Write-Host "  Force-refreshing RIP Demon $from -> $to (main)" -ForegroundColor Yellow
        } else {
            Write-Host "  Updating RIP Demon $from -> $to (main)" -ForegroundColor Yellow
        }
    }
    else {
        $to = if ($latest.Commit) { "$($latest.Version)@$($latest.Commit.Substring(0, 7))" } else { $latest.Version }
        Write-Host "  Installing RIP Demon $to from main..." -ForegroundColor Yellow
    }

    $zipPath = Join-Path $env:TEMP ("ripdemon-update-{0}.zip" -f [guid]::NewGuid().ToString('N'))
    try {
        Save-RipDemonFile -Uri $latest.Url -OutFile $zipPath `
            -Label "Downloading RIP Demon from GitHub ($($latest.Branch))"

        $result = Install-RipDemonAppFromZip -ZipPath $zipPath -InstallRoot $InstallRoot
        Set-InstalledRipDemonCommit -InstallRoot $InstallRoot -Commit $latest.Commit
        Register-RipDemonUninstall -InstallRoot $InstallRoot -Version $result.Version | Out-Null

        return [pscustomobject]@{
            Updated = $true
            Version = $result.Version
            Latest  = $latest.Version
            Commit  = $latest.Commit
        }
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $zipPath
    }
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Entry)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $parts = $userPath.Split(';') | Where-Object { $_ -and $_.Trim() -ne '' }
    $normalized = $Entry.TrimEnd('\')
    $exists = $parts | Where-Object { $_.TrimEnd('\') -ieq $normalized }
    if ($exists) {
        Write-Host "  PATH already contains: $Entry" -ForegroundColor Green
        return $false
    }
    $newPath = if ($userPath.Trim() -eq '') { $Entry } else { "$userPath;$Entry" }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = "$Entry;$env:Path"
    Write-Host "  Added to User PATH: $Entry" -ForegroundColor Green
    return $true
}

function Remove-UserPathEntry {
    param([Parameter(Mandatory)][string]$Entry)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return $false }
    $normalized = $Entry.TrimEnd('\')
    $parts = $userPath.Split(';') | Where-Object {
        $_ -and $_.Trim() -ne '' -and ($_.TrimEnd('\') -ine $normalized)
    }
    $newPath = ($parts -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "  Removed from User PATH: $Entry" -ForegroundColor Yellow
    return $true
}

function New-RipDemonStartMenuShortcut {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$BinDir
    )
    $programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\RIP Demon'
    New-Item -ItemType Directory -Force -Path $programs | Out-Null

    $ws = New-Object -ComObject WScript.Shell

    $helpShortcut = Join-Path $programs 'RIP Demon Help.lnk'
    $sc = $ws.CreateShortcut($helpShortcut)
    $sc.TargetPath = 'cmd.exe'
    $sc.Arguments = '/k yt help'
    $sc.WorkingDirectory = $env:USERPROFILE
    $sc.Description = 'RIP Demon - yt help'
    $sc.Save()

    $promptShortcut = Join-Path $programs 'RIP Demon Command Prompt.lnk'
    $sc2 = $ws.CreateShortcut($promptShortcut)
    $sc2.TargetPath = 'cmd.exe'
    $sc2.Arguments = '/k echo RIP Demon && yt version'
    $sc2.WorkingDirectory = $env:USERPROFILE
    $sc2.Description = 'RIP Demon Command Prompt'
    $sc2.Save()

    $dirs = Get-RipDemonOutputDirs
    New-Item -ItemType Directory -Force -Path $dirs.Mp3, $dirs.Mp4 | Out-Null

    $mp3Shortcut = Join-Path $programs 'MP3 Downloads.lnk'
    $scMp3 = $ws.CreateShortcut($mp3Shortcut)
    $scMp3.TargetPath = $dirs.Mp3
    $scMp3.Description = 'RIP Demon MP3 output folder'
    $scMp3.Save()

    $mp4Shortcut = Join-Path $programs 'MP4 Downloads.lnk'
    $scMp4 = $ws.CreateShortcut($mp4Shortcut)
    $scMp4.TargetPath = $dirs.Mp4
    $scMp4.Description = 'RIP Demon MP4 output folder'
    $scMp4.Save()

    $guiPs1 = Join-Path $InstallRoot 'gui\RipDemon.Gui.ps1'
    if (Test-Path -LiteralPath $guiPs1) {
        $guiShortcut = Join-Path $programs 'RIP Demon.lnk'
        $scGui = $ws.CreateShortcut($guiShortcut)
        $scGui.TargetPath = 'powershell.exe'
        $scGui.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$guiPs1`""
        $scGui.WorkingDirectory = $InstallRoot
        $scGui.Description = 'RIP Demon download window'
        $scGui.Save()
    }

    $uninstallCmd = Join-Path $InstallRoot 'Uninstall.cmd'
    if (Test-Path $uninstallCmd) {
        $unShortcut = Join-Path $programs 'Uninstall RIP Demon.lnk'
        $sc3 = $ws.CreateShortcut($unShortcut)
        $sc3.TargetPath = $uninstallCmd
        $sc3.WorkingDirectory = $InstallRoot
        $sc3.Description = 'Uninstall RIP Demon'
        $sc3.Save()
    }

    Write-Host '  Start Menu shortcuts created.' -ForegroundColor Green
}

function Clear-RipDemonShellLeftovers {
    <#
    .SYNOPSIS
      Removes obsolete Explorer/SendTo hooks from older RIP Demon builds (no longer used).
    #>
    param([switch]$Quiet)

    $removed = $false
    foreach ($ext in @('.txt', '.url', '.list')) {
        foreach ($verb in @('RIPDemonMP3', 'RIPDemonMP4')) {
            $path = "HKCU:\Software\Classes\$ext\shell\$verb"
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                $removed = $true
            }
        }
    }

    $sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
    foreach ($name in @('RIP Demon MP3.lnk', 'RIP Demon MP4.lnk')) {
        $p = Join-Path $sendTo $name
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            $removed = $true
        }
    }

    $marker = 'HKCU:\Software\RIP-Demon'
    if (Test-Path -LiteralPath $marker) {
        Remove-Item -LiteralPath $marker -Recurse -Force -ErrorAction SilentlyContinue
        $removed = $true
    }

    if ($removed -and -not $Quiet) {
        Write-Host '  Cleared obsolete Explorer/SendTo leftovers.' -ForegroundColor DarkGray
    }
    return $removed
}

function Invoke-RipDemonFirstRunWizard {
    <#
    .SYNOPSIS
      Interactive first-run prompts; writes config.ini.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [switch]$Skip
    )

    $configLib = Join-Path $InstallRoot 'lib\RipDemon.Config.ps1'
    if (-not (Test-Path -LiteralPath $configLib)) {
        Write-Host '  Wizard skipped (config library missing).' -ForegroundColor Yellow
        return $null
    }
    . $configLib

    $defaults = Get-RipDemonDefaultOutputDirs
    if ($Skip) {
        $path = Write-RipDemonUserConfig -InstallRoot $InstallRoot `
            -Mp3Dir $defaults.Mp3 -Mp4Dir $defaults.Mp4 `
            -Quality '1080' -CookiesBrowser '' `
            -NoPlaylist:$false -OpenAfter:$false -SponsorBlock:$false
        Write-Host "  Wrote default config: $path" -ForegroundColor Green
        return (Get-RipDemonConfig -InstallRoot $InstallRoot)
    }

    Write-Host ''
    Write-Host '  -------- First-run setup --------' -ForegroundColor Cyan
    Write-Host '  Press Enter to accept the default in [brackets].' -ForegroundColor DarkGray
    Write-Host ''

    $mp3 = Read-Host "  MP3 folder [$($defaults.Mp3)]"
    if (-not $mp3) { $mp3 = $defaults.Mp3 }
    $mp4 = Read-Host "  MP4 folder [$($defaults.Mp4)]"
    if (-not $mp4) { $mp4 = $defaults.Mp4 }

    $quality = Read-Host '  Default MP4 quality: 720 / 1080 / best [1080]'
    if (-not $quality) { $quality = '1080' }
    $quality = $quality.Trim().ToLowerInvariant()
    if ($quality -notin @('720', '1080', 'best')) { $quality = '1080' }

    $cookies = Read-Host '  Default cookies browser (chrome/edge/firefox or blank) []'
    if (-not $cookies) { $cookies = '' }

    $noPl = Read-Host '  Always use --no-playlist? (y/N)'
    $open = Read-Host '  Open output folder after download? (y/N)'

    $path = Write-RipDemonUserConfig -InstallRoot $InstallRoot `
        -Mp3Dir $mp3.Trim() -Mp4Dir $mp4.Trim() `
        -Quality $quality -CookiesBrowser $cookies.Trim() `
        -NoPlaylist:($noPl -match '^[yY]') `
        -OpenAfter:($open -match '^[yY]') `
        -SponsorBlock:$false

    Write-Host "  Saved config: $path" -ForegroundColor Green
    return (Get-RipDemonConfig -InstallRoot $InstallRoot)
}

function Register-RipDemonUninstall {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$Version
    )
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RIP-Demon'
    New-Item -Path $key -Force | Out-Null
    $uninstallCmd = Join-Path $InstallRoot 'Uninstall.cmd'
    $uninstallPs1 = Join-Path $InstallRoot 'Uninstall.ps1'
    $uninstallString = if (Test-Path $uninstallCmd) {
        "`"$uninstallCmd`""
    } else {
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallPs1`""
    }
    $quietString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallPs1`" -Quiet"

    Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'RIP Demon'
    Set-ItemProperty -Path $key -Name 'DisplayVersion' -Value $Version
    Set-ItemProperty -Path $key -Name 'Publisher' -Value 'Opes'
    Set-ItemProperty -Path $key -Name 'URLInfoAbout' -Value 'https://opes.dev'
    Set-ItemProperty -Path $key -Name 'HelpLink' -Value 'https://opes.dev'
    Set-ItemProperty -Path $key -Name 'InstallLocation' -Value $InstallRoot
    Set-ItemProperty -Path $key -Name 'DisplayIcon' -Value (Join-Path $InstallRoot 'tools\yt-dlp.exe')
    Set-ItemProperty -Path $key -Name 'UninstallString' -Value $uninstallString
    Set-ItemProperty -Path $key -Name 'QuietUninstallString' -Value $quietString
    Set-ItemProperty -Path $key -Name 'NoModify' -Value 1 -Type DWord
    Set-ItemProperty -Path $key -Name 'NoRepair' -Value 1 -Type DWord
    Write-Host '  Registered in Apps & features.' -ForegroundColor Green
}

function Unregister-RipDemonUninstall {
    param(
        [string]$InstallRoot
    )
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RIP-Demon'
    if (-not (Test-Path -LiteralPath $key)) { return $false }

    if ($InstallRoot) {
        $registered = $null
        try {
            $registered = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallLocation
        } catch {}
        if ($registered) {
            $want = $InstallRoot.TrimEnd('\')
            $have = $registered.TrimEnd('\')
            if ($have -ine $want) {
                Write-Host "  Skipping Apps & features removal (registered install is elsewhere: $registered)" -ForegroundColor DarkYellow
                return $false
            }
        }
    }

    Remove-Item -LiteralPath $key -Recurse -Force
    Write-Host '  Removed Apps & features entry.' -ForegroundColor Yellow
    return $true
}

function Remove-RipDemonStartMenu {
    param(
        [string]$InstallRoot
    )
    $programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\RIP Demon'
    if (-not (Test-Path -LiteralPath $programs)) { return $false }

    if ($InstallRoot) {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RIP-Demon'
        if (Test-Path -LiteralPath $key) {
            $registered = $null
            try {
                $registered = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallLocation
            } catch {}
            if ($registered) {
                $want = $InstallRoot.TrimEnd('\')
                $have = $registered.TrimEnd('\')
                if ($have -ine $want) {
                    Write-Host '  Skipping Start Menu removal (belongs to another install).' -ForegroundColor DarkYellow
                    return $false
                }
            }
        }
    }

    Remove-Item -LiteralPath $programs -Recurse -Force
    Write-Host '  Start Menu shortcuts removed.' -ForegroundColor Yellow
    return $true
}
