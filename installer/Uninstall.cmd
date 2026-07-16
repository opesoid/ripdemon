@echo off
title RIP Demon Uninstaller
cd /d "%~dp0"
echo.
echo  Starting RIP Demon uninstaller...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" %*
set "ERR=%ERRORLEVEL%"
echo.
if not "%ERR%"=="0" (
  echo  Uninstall failed with code %ERR%.
  pause
  exit /b %ERR%
)
echo  Press any key to close...
pause >nul
exit /b 0
