@echo off
REM Kamiwaza System Tray Manager Launcher (PowerShell Version)
REM Launches the PowerShell-based system tray manager

set "INSTALL_PATH=%LOCALAPPDATA%\Kamiwaza"
set "TRAY_SCRIPT=%INSTALL_PATH%\kamiwaza_tray_manager.ps1"

REM Check if the tray manager script exists
if not exist "%TRAY_SCRIPT%" (
    echo ERROR: Tray manager script not found at: %TRAY_SCRIPT%
    echo Please run install_tray_manager_powershell.ps1 first
    pause
    exit /b 1
)

REM Launch the PowerShell tray manager
echo Starting Kamiwaza System Tray Manager...
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%TRAY_SCRIPT%"

REM If we get here, the tray manager has exited
echo Kamiwaza System Tray Manager has stopped
pause
