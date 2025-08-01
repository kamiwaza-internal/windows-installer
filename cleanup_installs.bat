@echo off
echo ===============================================
echo Kamiwaza WSL Cleanup Tool
echo ===============================================
echo.
echo This tool will completely remove Kamiwaza WSL instances and related data.
echo This includes:
echo   - WSL instances (kamiwaza, Ubuntu-24.04)
echo   - WSL data directories
echo   - Configuration files
echo   - Log files
echo.
echo WARNING: This action cannot be undone!
echo.

set /p confirm="Are you sure you want to proceed? (y/N): "
if /i not "%confirm%"=="y" (
    echo Cleanup cancelled.
    pause
    exit /b 0
)

echo.
echo Starting cleanup...
echo.

REM Run the PowerShell cleanup script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0cleanup_wsl_kamiwaza.ps1" -Force

echo.
echo Cleanup completed!
pause 