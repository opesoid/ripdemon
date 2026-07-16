@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "RIPDEMON_SCRIPT_DIR=%~dp0"
if exist "%RIPDEMON_SCRIPT_DIR%lib\ripdemon-config.cmd" (
  call "%RIPDEMON_SCRIPT_DIR%lib\ripdemon-config.cmd"
) else if exist "%RIPDEMON_SCRIPT_DIR%..\lib\ripdemon-config.cmd" (
  call "%RIPDEMON_SCRIPT_DIR%..\lib\ripdemon-config.cmd"
) else (
  echo Error: could not load RIP Demon config.
  exit /b 1
)
if errorlevel 1 (
  echo Error: could not load RIP Demon config.
  exit /b 1
)

if /I "%~1"=="version" goto :version
if /I "%~1"=="update" goto :update
if /I "%~1"=="uninstall" goto :uninstall

set "RIPDEMON_CLI=%RIPDEMON_LIB%\RipDemon.Cli.ps1"
if not exist "%RIPDEMON_CLI%" (
  echo Error: CLI engine not found at "%RIPDEMON_CLI%"
  echo Re-run the installer.
  exit /b 1
)

REM Forward all args to PowerShell CLI (mp3/mp4/info/gui/config/help/...)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RIPDEMON_CLI%" %*
exit /b %ERRORLEVEL%

:version
set "APPVER=unknown"
if exist "%RIPDEMON_VERSION_FILE%" (
  set /p APPVER=<"%RIPDEMON_VERSION_FILE%"
)
echo RIP Demon %APPVER%
echo by Opes - https://opes.dev
if exist "%RIPDEMON_YTDLP%" (
  for /f "delims=" %%V in ('"%RIPDEMON_YTDLP%" --version 2^>nul') do echo yt-dlp %%V
) else (
  echo yt-dlp not installed — run: yt update
)
if exist "%RIPDEMON_FFMPEG%" (
  for /f "delims=" %%V in ('"%RIPDEMON_FFMPEG%" -version 2^>nul') do (
    echo %%V
    goto :ffmpeg_tag
  )
) else (
  echo ffmpeg not installed — run: yt update
  goto :deno_ver
)
:ffmpeg_tag
if exist "%RIPDEMON_TOOLS%\ffmpeg.version" (
  set /p FFTAG=<"%RIPDEMON_TOOLS%\ffmpeg.version"
  echo ffmpeg build !FFTAG!
)
:deno_ver
if exist "%RIPDEMON_TOOLS%\deno.exe" (
  for /f "delims=" %%V in ('"%RIPDEMON_TOOLS%\deno.exe" --version 2^>nul') do (
    echo %%V
    goto :eof
  )
) else (
  echo deno not installed — run: yt update
)
exit /b 0

:update
REM Forward optional flags: -Force, -SkipApp, -AppOnly, -InstallRoot ...
shift
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RIPDEMON_UPDATER%\Update.ps1" %*
exit /b %ERRORLEVEL%

:uninstall
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RIPDEMON_ROOT%\Uninstall.ps1"
exit /b %ERRORLEVEL%
