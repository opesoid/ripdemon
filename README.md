<p align="center">
  <img src="assets/ripdemon.png" alt="RIP Demon" width="666">
</p>

# RIP Demon

**Version 1.0.0** · by [Opes](https://opes.dev)

Windows tool for downloading audio and video with short `yt` commands. Built on [yt-dlp](https://github.com/yt-dlp/yt-dlp), with bundled **ffmpeg** and **deno**. Tuned for YouTube; works with most sites yt-dlp supports.

| | |
|---|---|
| Author | [Opes](https://opes.dev) |
| Version | **1.0.0** (see [`VERSION`](VERSION)) |
| License | [MIT](LICENSE) |
| Platform | Windows 10+ **x64** (Intel/AMD) |
| Install | `%LOCALAPPDATA%\RIP-Demon\` (per-user, no admin) |
| Config | `%LOCALAPPDATA%\RIP-Demon\config.ini` |
| MP3 output | `%USERPROFILE%\Music\RIP Demon\MP3\` (configurable) |
| MP4 output | `%USERPROFILE%\Videos\RIP Demon\MP4\` (configurable) |

---

## Table of contents

1. [Features](#features)
2. [Requirements](#requirements)
3. [Install](#install)
4. [Quick start](#quick-start)
5. [Commands](#commands)
6. [Options](#options)
7. [Examples](#examples)
8. [Configuration](#configuration)
9. [GUI](#gui)
10. [Output files](#output-files)
11. [Update](#update)
12. [Uninstall](#uninstall)
13. [Install layout](#install-layout)
14. [Build & test](#build--test)
15. [Repository layout](#repository-layout)
16. [Troubleshooting](#troubleshooting)
17. [Credits & license](#credits--license)

---

## Features

- **Simple CLI** — `yt mp3`, `yt mp4`, `yt info`, `yt gui`, `yt config`, `yt update`
- **Clipboard mode** — omit the URL; RIP Demon uses a copied link when it looks like one
- **Batch** — multiple URLs, or a `.txt` / `.list` file (one URL per line), or `.url` shortcuts
- **MP3** — best-quality extract + convert, embedded thumbnail and metadata
- **MP4** — quality presets **720**, **1080** (default), **best**, with sensible fallbacks
- **Extras** — subtitles, SponsorBlock removal, thumbnail-only, yt-dlp passthrough (`--`)
- **Config file** + first-run installer wizard
- **Minimal GUI** (`yt gui` / Start Menu)
- **One-line install** — `irm ... | iex` from GitHub (release zip, SHA256 verified)
- **Self-update** — `yt update` upgrades RIP Demon and yt-dlp / ffmpeg / deno
- **Tool updates** — yt-dlp, ffmpeg, deno from official releases (SHA256 verified)
- **Clean lifecycle** — Apps & features, Start Menu, quiet uninstall; media files kept

---

## Requirements

- Windows 10 or later (**64-bit x64** Intel/AMD)
- PowerShell 5.1+ (included with Windows)
- Internet access for first install / tool updates (~100–150 MB)

**Not supported:** ARM64 and 32-bit Windows (bundled deno and FFmpeg builds are x64-only). The installer exits with a clear error on unsupported architectures.

---

## Install

### One-line (recommended)

In **PowerShell** (Windows 10+):

```powershell
irm https://raw.githubusercontent.com/opesoid/ripdemon/main/installer/web-install.ps1 | iex
```

This downloads the **latest GitHub Release** zip, verifies **SHA256**, then runs the installer (wizard + tool downloads). Requires a published release on [opesoid/ripdemon](https://github.com/opesoid/ripdemon/releases).

Silent defaults (no wizard):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/opesoid/ripdemon/main/installer/web-install.ps1))) -SkipWizard
```

### From a release zip

Use the **`.cmd`** launchers. Double-clicking `.ps1` files often fails because of PowerShell execution policy.

1. Download and unzip a release (or [build one](#build--test)).
2. Double-click **`Install.cmd`** in the zip root (or `installer\Install.cmd` in this repo).
3. Answer the short first-run prompts (or press Enter for defaults).
4. Wait for tool downloads (FFmpeg and deno can take a few minutes).
5. In that same installer window (PATH is primed), or in a **new** terminal:

```bat
yt version
yt gui
```

### From this repository

```bat
installer\Install.cmd
```

### Installer flags

```powershell
# Defaults only (no wizard) — useful for scripts/CI
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install.ps1 -SkipWizard

# Skip downloading yt-dlp / ffmpeg / deno
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install.ps1 -SkipTools -SkipWizard

# Custom install directory
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install.ps1 -InstallRoot "D:\Apps\RIP-Demon" -SkipWizard
```

| Flag | Meaning |
|------|---------|
| `-SkipWizard` | Write default `config.ini` without interactive prompts |
| `-SkipTools` | Copy app files and PATH only; run `yt update` later for tools |
| `-InstallRoot <path>` | Install somewhere other than `%LOCALAPPDATA%\RIP-Demon` |

### What install does

1. Copies application files into the install root
2. Runs the first-run wizard and writes `config.ini`
3. Downloads **yt-dlp**, **ffmpeg**, and **deno** into `tools\` (checksum verified)
4. Adds `bin\` to your **User PATH**
5. Creates Start Menu shortcuts (including the GUI)
6. Registers an uninstaller in **Settings → Apps** (publisher: Opes)

---

## Quick start

```bat
yt mp3
yt mp4 --open "https://youtu.be/VIDEO_ID"
yt info "https://www.youtube.com/watch?v=VIDEO_ID"
yt gui
yt config
```

1. Copy a video link.
2. Run `yt mp3` or `yt mp4` (no URL needed if the clipboard holds the link).
3. Find files under your Music / Videos **RIP Demon** folders (or paths from `yt config`).

---

## Commands

| Command | Description |
|---------|-------------|
| `yt mp3 [options] [url\|file ...]` | Best-quality MP3 |
| `yt mp4 [options] [url\|file ...]` | MP4 using the quality preset |
| `yt info [options] <url>` | Title, duration, uploader, format list |
| `yt gui` | Open the download window |
| `yt config` | Show config path and active settings |
| `yt update` | Update RIP Demon + yt-dlp / ffmpeg / deno |
| `yt version` | Show RIP Demon and tool versions |
| `yt uninstall` | Remove RIP Demon |
| `yt help` | Show help |

If you omit the URL for `mp3` / `mp4` / `info`, RIP Demon uses the **clipboard** when it looks like a link.

Pass a **`.txt` / `.list`** file (one URL per line, `#` comments allowed) or multiple URLs to download in sequence. Internet shortcut **`.url`** files are also accepted.

---

## Options

Options apply to `mp3`, `mp4`, and (where relevant) `info`.

| Option | Meaning |
|--------|---------|
| `--no-playlist` | Download only the linked video, not the playlist |
| `--cookies-from-browser <name>` | Use browser cookies (`chrome`, `edge`, `firefox`, `brave`, `opera`, …) |
| `-o <dir>` / `--output-dir <dir>` | Override output folder for this run |
| `--open` | Open the output folder when the download succeeds |
| `--quality <720\|1080\|best>` | MP4 quality preset |
| `--720` / `--1080` / `--best` | Shorthand quality presets |
| `--subs [lang]` | Write and embed subtitles (mp4; default English) |
| `--sponsorblock` | Remove SponsorBlock segments (mp4) |
| `--thumbnail-only` | Save thumbnail only (skip media) |
| `--` | Pass all following arguments straight to yt-dlp |

### Environment variables

| Variable | Meaning |
|----------|---------|
| `RIPDEMON_MP3_DIR` | Override MP3 output directory |
| `RIPDEMON_MP4_DIR` | Override MP4 output directory |
| `RIPDEMON_ROOT` | Override install root (PowerShell helpers / updater) |

CLI flags and env vars override `config.ini`.

---

## Examples

```bat
REM Clipboard
yt mp3
yt mp4

REM Single URL (quote when the URL contains &)
yt mp3 "https://www.youtube.com/watch?v=VIDEO_ID"
yt mp4 --1080 --open "https://youtu.be/VIDEO_ID"

REM Playlist link but only this video
yt mp3 --no-playlist "https://www.youtube.com/watch?v=VIDEO_ID&list=PLxxxx"

REM Restricted / age-gated
yt mp4 --cookies-from-browser chrome https://www.youtube.com/watch?v=VIDEO_ID

REM Batch
yt mp3 urls.txt
yt mp3 url1 url2 url3

REM Subtitles + SponsorBlock
yt mp4 --subs en --sponsorblock https://www.youtube.com/watch?v=VIDEO_ID

REM Custom folder
yt mp3 -o D:\Music\Imports https://youtu.be/VIDEO_ID

REM Inspect before downloading
yt info https://youtu.be/VIDEO_ID

REM Advanced yt-dlp flags
yt mp3 -- --download-archive archive.txt https://youtu.be/VIDEO_ID

REM App
yt gui
yt config
yt version
yt update
```

Unquoted `watch?v=ID` often still works in CMD (RIP Demon rejoins `=`-split arguments), but **quoting is the safest habit**.

---

## Configuration

Path: `%LOCALAPPDATA%\RIP-Demon\config.ini`

Created by the installer wizard (or defaults with `-SkipWizard`). Edit by hand, or inspect with `yt config`.

```ini
; RIP Demon user settings
; Edit this file, run yt config, or re-run the installer wizard.

[paths]
; Leave blank to use Music/Videos defaults
mp3_dir=
mp4_dir=

[defaults]
; mp4 quality preset: 720 | 1080 | best
quality=1080
; Browser for cookies when empty = off (chrome, edge, firefox, …)
cookies_browser=
; true = always pass --no-playlist
no_playlist=false
; true = open the output folder after a successful download
open_after=false
; true = remove SponsorBlock segments (mp4)
sponsorblock=false
```

Defaults template in the install: `lib\config.default.ini`.

---

## GUI

```bat
yt gui
```

Or **Start Menu → RIP Demon → RIP Demon**.

The window supports:

- Paste / clipboard URL
- MP3 or MP4
- MP4 quality preset
- Optional cookies browser
- No-playlist and open-folder toggles

It runs the same `yt` CLI under the hood.

Start Menu also includes Help, Command Prompt, MP3/MP4 folder shortcuts, and Uninstall.

---

## Output files

Default naming:

```text
Title [VIDEO_ID].mp3
Title [VIDEO_ID].mp4
```

| Mode | Behavior |
|------|----------|
| **mp3** | Extract audio → MP3 (`--audio-quality 0`), embed thumbnail + metadata |
| **mp4** | Preset format ladder (default prefer 1080p60 with fallbacks); merge to MP4 with metadata |

Sites other than YouTube may work when yt-dlp supports them; quality ladders are still video-oriented.

---

## Update

```bat
yt update
```

Or double-click `%LOCALAPPDATA%\RIP-Demon\Update.cmd`.

This:

1. Checks [GitHub Releases](https://github.com/opesoid/ripdemon/releases) for a newer RIP Demon zip (SHA256 verified) and replaces app files — **`config.ini` and `tools\` are kept**
2. Updates **yt-dlp**, **ffmpeg**, and **deno** from their upstream releases (size + SHA256 checked)

| Flag | Meaning |
|------|---------|
| `-Force` | Re-download app package and tools even if versions match |
| `-SkipApp` | Tools only (skip RIP Demon self-update) |
| `-AppOnly` | RIP Demon package only (skip tools) |

```bat
yt update -Force
yt update -SkipApp
yt update -AppOnly
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\RIP-Demon\updater\Update.ps1" -Force
```

---

## Uninstall

```bat
yt uninstall
```

Also available via:

- `%LOCALAPPDATA%\RIP-Demon\Uninstall.cmd`
- **Settings → Apps → Installed apps → RIP Demon**
- Start Menu → **Uninstall RIP Demon**

Type `YES` to confirm (unless quiet). Downloaded MP3/MP4 files in your media folders are **kept**. PATH entry, Start Menu shortcuts, and Apps & features registration are removed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\RIP-Demon\Uninstall.ps1" -Quiet
```

Open a new terminal afterward so PATH refreshes in other windows.

---

## Install layout

```text
%LOCALAPPDATA%\RIP-Demon\
  bin\yt.cmd                 on PATH as `yt`
  lib\                       CLI engine, config helpers, defaults
  gui\RipDemon.Gui.ps1       Download window
  tools\                     yt-dlp.exe, ffmpeg, ffprobe, deno (+ DLLs)
  updater\                   Update.ps1, RipDemon.Tools.ps1
  config.ini                 User settings
  Uninstall.cmd / .ps1
  Update.cmd
  version.txt
  README.md
  LICENSE
  CHANGELOG.md
```

---

## Build & test

### Release zip

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\build\Build-Release.ps1
```

Output:

- `dist\RIP-Demon-1.0.0-windows.zip` — always
- `dist\SHA256SUMS.txt` — checksums for web install / self-update
- `dist\RIP-Demon-Setup-1.0.0.exe` — if [Inno Setup 6](https://jrsoftware.org/isinfo.php) is installed

The zip includes a root `Install.cmd`. Tools are downloaded at install time (not shipped inside the zip).

### Publish a GitHub Release

Tag a version that matches [`VERSION`](VERSION) (e.g. `v1.0.0`). The [Release](.github/workflows/release.yml) workflow builds the zip, writes `SHA256SUMS.txt`, and uploads them to the release. That unlocks the one-line installer and `yt update` self-update.

### Smoke tests

Fast checks, no tool downloads (optional zip build):

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Smoke.ps1
powershell -ExecutionPolicy Bypass -File .\tests\Smoke.ps1 -SkipBuild
```

### Integration test

Full install → CLI → update → optional real download → uninstall (isolated install root):

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Integration.ps1
powershell -ExecutionPolicy Bypass -File .\tests\Integration.ps1 -SkipTools
powershell -ExecutionPolicy Bypass -File .\tests\Integration.ps1 -SkipDownload
```

CI runs smoke tests on `windows-latest` (see `.github/workflows/ci.yml`).

---

## Repository layout

```text
rip-demon/
  VERSION                 App version (1.0.0)
  README.md               This documentation
  LICENSE                 MIT — Opes
  CHANGELOG.md
  src/
    yt.cmd                CLI entrypoint (on PATH as yt)
    lib/
      RipDemon.Cli.ps1    Download / info / config engine
      RipDemon.Config.ps1 Shared config helpers
      config.default.ini  Default settings template
      ripdemon-config.cmd Path bootstrap for yt.cmd
    gui/
      RipDemon.Gui.ps1    WinForms UI
  installer/
    Install.cmd / .ps1
    web-install.ps1       One-line irm | iex bootstrap
    Uninstall.cmd / .ps1
    Update.cmd
  updater/
    Update.ps1            App + tool updates
    RipDemon.Tools.ps1    Downloads, PATH, shortcuts, wizard, self-update
  build/
    Build-Release.ps1
    RIP-Demon.iss         Optional Inno Setup script
  tests/
    Smoke.ps1
    Integration.ps1
  .github/workflows/
    ci.yml
    release.yml           Tag v* → GitHub Release assets
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `yt` is not recognized | Open a **new** terminal after install, or use the installer window (PATH is primed there). Confirm `%LOCALAPPDATA%\RIP-Demon\bin` is on your User PATH. |
| `yt-dlp not found` | Run `yt update` |
| Download / site errors | Run `yt update`; try `--cookies-from-browser chrome`; quote URLs that contain `&` |
| Age-gated or private video | `--cookies-from-browser` with a logged-in browser profile |
| SHA256 / size mismatch | Re-run `yt update`; check proxy, VPN, or antivirus interference |
| Install fails on `.ps1` double-click | Use `Install.cmd` instead |
| Slow first install | Normal — FFmpeg (~80 MB) and deno (~40 MB) download once |
| ARM64 / non-x64 PC | Not supported — tools are x64-only |
| Want defaults without prompts | `Install.ps1 -SkipWizard` or web-install `-SkipWizard` |
| GUI missing | Re-run the installer / `yt update -AppOnly` so `gui\RipDemon.Gui.ps1` is copied |
| One-liner: no release yet | Publish a `vX.Y.Z` tag (see [Build & test](#build--test)); until then use `installer\Install.cmd` from a clone |
| App update fails | Check internet / GitHub; try `yt update -SkipApp` for tools only |

---

## Credits & license

**RIP Demon** is made by [**Opes**](https://opes.dev).

Licensed under the [MIT License](LICENSE).

It wraps [yt-dlp](https://github.com/yt-dlp/yt-dlp) and downloads tools from:

| Project | Role |
|---------|------|
| [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp) | Downloader |
| [yt-dlp/FFmpeg-Builds](https://github.com/yt-dlp/FFmpeg-Builds) | ffmpeg / ffprobe (GPL) |
| [denoland/deno](https://github.com/denoland/deno) | JS runtime used by yt-dlp for YouTube |

Third-party tools keep their own licenses; see [LICENSE](LICENSE).

---

https://opes.dev
