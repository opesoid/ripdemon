# Changelog

All notable changes to RIP Demon are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project uses [Semantic Versioning](https://semver.org/).

## 1.0.0 — 2026-07-16

First public release by [Opes](https://opes.dev).

### Added
- Windows CLI entrypoint `yt` for MP3/MP4 downloads via yt-dlp
- Bundled tool management for **yt-dlp**, **ffmpeg**, and **deno** (SHA256 verified)
- Per-user install under `%LOCALAPPDATA%\RIP-Demon\` (no admin)
- User `config.ini` for output folders, quality, cookies, open-after
- First-run installer wizard (`-SkipWizard` for defaults)
- **One-line web install** via `installer/web-install.ps1` (`irm … \| iex`) from the GitHub **main** branch (no Release required)
- **App self-update** — `yt update` upgrades RIP Demon from **main** (VERSION + commit), then tools; flags `-SkipApp` / `-AppOnly` / `-Force`
- Clipboard download when the URL is omitted
- Batch downloads from multiple URLs, `.txt` / `.list` files, or `.url` shortcuts
- Quality presets: `--quality 720|1080|best` and `--720` / `--1080` / `--best`
- `--open`, `--subs`, `--sponsorblock`, `--thumbnail-only`
- Safe yt-dlp passthrough after `--`
- `yt info`, `yt config`, `yt gui`, `yt update`, `yt version`, `yt uninstall`, `yt help`
- Minimal WinForms GUI and Start Menu shortcuts
- Apps & features registration and quiet uninstall
- Release zip packaging, `SHA256SUMS.txt`, and optional Inno Setup installer
- Smoke and integration tests; GitHub Actions CI (smoke) + Release workflow on `v*` tags

### Branding
- Publisher: **Opes** — https://opes.dev

### Removed
- Explorer context menus and SendTo shortcuts (not supported)
