@echo off
REM XiaomeiSignal set-status for Windows. Uses python from PATH.
setlocal
set "DIR=%~dp0"
if exist "%DIR%set-status.py" (
  python "%DIR%set-status.py" %*
  exit /b %ERRORLEVEL%
)
if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\XiaomeiSignal\set-status.py" (
  python "%LOCALAPPDATA%\XiaomeiSignal\set-status.py" %*
  exit /b %ERRORLEVEL%
)
echo set-status.py not found. Run install-windows.ps1 first.
exit /b 1
