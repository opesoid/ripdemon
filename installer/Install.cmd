@echo off
title RIP Demon Installer
cd /d "%~dp0\.."
echo.
echo  Starting RIP Demon installer...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -NoPause %*
set "ERR=%ERRORLEVEL%"
echo.
if not "%ERR%"=="0" (
  echo  Install failed with code %ERR%.
  pause
  exit /b %ERR%
)

REM Prefer default install on PATH for this window (custom -InstallRoot still works after new terminals)
if exist "%LOCALAPPDATA%\RIP-Demon\bin\yt.cmd" (
  set "PATH=%LOCALAPPDATA%\RIP-Demon\bin;%PATH%"
  echo  PATH ready in this window — try: yt version
  echo.
)

echo  Press any key to close...
pause >nul
exit /b 0
