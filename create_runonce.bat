@echo off
REM Create RunOnce entry for Kamiwaza installation continuation
REM This is called by the MSI installer to ensure installation continues after reboot

setlocal enabledelayedexpansion

REM Get the parameters passed from MSI
set INSTALLFOLDER=%~1
set WSLMEMORY=%~2
set USER_EMAIL=%~3
set LICENSE_KEY=%~4
set USAGE_REPORTING=%~5
set INSTALL_MODE=%~6

REM Ensure INSTALLFOLDER ends with backslash
if not "%INSTALLFOLDER:~-1%"=="\" set INSTALLFOLDER=%INSTALLFOLDER%\

REM Create the RunOnce registry entry (silent)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "KamiwazaContinueInstall" /t REG_SZ /d "\"%INSTALLFOLDER%run_kamiwaza.bat\" --memory \"%WSLMEMORY%\" --email \"%USER_EMAIL%\" --license-key \"%LICENSE_KEY%\" --usage-reporting \"%USAGE_REPORTING%\" --mode \"%INSTALL_MODE%\"" /f >nul 2>&1

endlocal
exit /b 0 