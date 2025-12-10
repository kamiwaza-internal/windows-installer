@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo Kamiwaza Installer Delete Script
echo ===============================================

if "%1"=="" (
    echo [ERROR] Please provide version and architecture
    echo Usage: delete_installer.bat 0.5.0 x86_64
    echo        delete_installer.bat 0.5.0 arm64
    echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
)

if "%2"=="" (
    echo [ERROR] Please provide both version and architecture
    echo Usage: delete_installer.bat 0.5.0 x86_64
    echo        delete_installer.bat 0.5.0 arm64
    echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
)

set VERSION=%1
set ARCH=%2

echo [INFO] Deleting installers for version %VERSION%, architecture %ARCH%
echo.

REM Call the PowerShell script with delete parameters
powershell -ExecutionPolicy Bypass -File "tools\upload_msi_to_win.ps1" -Delete -Version "%VERSION%" -Arch "%ARCH%"

echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
