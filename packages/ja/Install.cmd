@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %*
set "taskResult=%ERRORLEVEL%"
echo.
pause
exit /b %taskResult%
