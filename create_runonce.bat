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

REM Debug output
echo [DEBUG] INSTALLFOLDER: "%INSTALLFOLDER%"
echo [DEBUG] Final path: "%INSTALLFOLDER%run_kamiwaza.bat"

REM Create the RunOnce registry entry
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "KamiwazaContinueInstall" /t REG_SZ /d "\"%INSTALLFOLDER%run_kamiwaza.bat\" --memory \"%WSLMEMORY%\" --email \"%USER_EMAIL%\" --license-key \"%LICENSE_KEY%\" --usage-reporting \"%USAGE_REPORTING%\" --mode \"%INSTALL_MODE%\"" /f

if %ERRORLEVEL% EQU 0 (
    echo [OK] RunOnce entry created successfully
    echo [INFO] Kamiwaza installation will continue automatically after reboot
) else (
    echo [ERROR] Failed to create RunOnce entry
    echo [INFO] You may need to manually run the installer after reboot
)

REM Keep window open for debugging
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul 