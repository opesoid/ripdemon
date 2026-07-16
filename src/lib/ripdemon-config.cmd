@echo off
REM Shared paths — installed layout: %LOCALAPPDATA%\RIP-Demon\lib\ripdemon-config.cmd
REM Default Music/Videos paths (user overrides live in config.ini via RipDemon.Config.ps1)
REM Keep in sync with Get-RipDemonOutputDirs in updater\RipDemon.Tools.ps1
set "RIPDEMON_ROOT=%~dp0.."
for %%I in ("%RIPDEMON_ROOT%") do set "RIPDEMON_ROOT=%%~fI"

set "RIPDEMON_BIN=%RIPDEMON_ROOT%\bin"
set "RIPDEMON_TOOLS=%RIPDEMON_ROOT%\tools"
set "RIPDEMON_LIB=%RIPDEMON_ROOT%\lib"
set "RIPDEMON_GUI=%RIPDEMON_ROOT%\gui"
set "RIPDEMON_UPDATER=%RIPDEMON_ROOT%\updater"
set "RIPDEMON_YTDLP=%RIPDEMON_TOOLS%\yt-dlp.exe"
set "RIPDEMON_FFMPEG=%RIPDEMON_TOOLS%\ffmpeg.exe"
set "RIPDEMON_VERSION_FILE=%RIPDEMON_ROOT%\version.txt"
set "RIPDEMON_CONFIG=%RIPDEMON_ROOT%\config.ini"

REM Env overrides still honored by the PowerShell CLI
if not defined RIPDEMON_MP3_DIR set "RIPDEMON_MP3_DIR=%USERPROFILE%\Music\RIP Demon\MP3"
if not defined RIPDEMON_MP4_DIR set "RIPDEMON_MP4_DIR=%USERPROFILE%\Videos\RIP Demon\MP4"
