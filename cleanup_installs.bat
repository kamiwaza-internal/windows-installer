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

REM Non-interactive mode for MSI uninstall
REM set /p confirm="Are you sure you want to proceed? (y/N): "
REM if /i not "%confirm%"=="y" (
REM     echo Cleanup cancelled.
REM     pause
REM     exit /b 0
REM )

echo.
echo Starting cleanup...
echo.

REM Run the PowerShell cleanup script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0cleanup_wsl_kamiwaza.ps1" -Force

@REM Unregister kamiwaza ubuntu-24.04 instance (ignore errors)
wsl --unregister kamiwaza 2>nul

echo.
echo Cleanup completed!
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul 