# Changelog

## 1.0.2

- Cookie DPAPI fallback: retry without browser cookies when Chrome/Edge decrypt fails
- Performance: rolling yt-dlp log buffer, tools PATH primed once, CLI console inherit when cookies off
- Performance: `yt info` uses one yt-dlp process; GUI downloads on BackgroundWorker with throttled progress
- `yt gui` launches the WinForms script directly from `yt.cmd`
- Install/update zip extract prefers `tar.exe` when available
