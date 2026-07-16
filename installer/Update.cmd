@echo off
title RIP Demon Updater
setlocal
cd /d "%~dp0"

if exist "%~dp0updater\Update.ps1" (
  set "UPD=%~dp0updater\Update.ps1"
) else if exist "%~dp0..\updater\Update.ps1" (
  set "UPD=%~dp0..\updater\Update.ps1"
) else (
  echo  Error: Update.ps1 not found.
  pause
  exit /b 1
)

echo.
echo  Starting RIP Demon updater...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%UPD%" %*
set "ERR=%ERRORLEVEL%"
echo.
if not "%ERR%"=="0" (
  echo  Update failed with code %ERR%.
  pause
  exit /b %ERR%
)
echo  Press any key to close...
pause >nul
exit /b 0
