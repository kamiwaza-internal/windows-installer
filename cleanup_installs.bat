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
echo   - AppData directories
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

REM Clean up AppData directories
echo Cleaning up AppData directories...
if exist "%LOCALAPPDATA%\Kamiwaza" (
    echo Removing Kamiwaza AppData directory...
    rmdir /s /q "%LOCALAPPDATA%\Kamiwaza" 2>nul
    if exist "%LOCALAPPDATA%\Kamiwaza" (
        echo Warning: Could not remove Kamiwaza AppData directory
    ) else (
        echo Kamiwaza AppData directory removed successfully.
    )
) else (
    echo No Kamiwaza AppData directory found.
)

REM Clean up WSL data directory if it still exists
if exist "%LOCALAPPDATA%\WSL\kamiwaza" (
    echo Removing WSL data directory...
    rmdir /s /q "%LOCALAPPDATA%\WSL\kamiwaza" 2>nul
    if exist "%LOCALAPPDATA%\WSL\kamiwaza" (
        echo Warning: Could not remove WSL data directory
    ) else (
        echo WSL data directory removed successfully.
    )
) else (
    echo No WSL data directory found.
)

@REM Clean up Start Menu shortcuts
echo Cleaning up Start Menu shortcuts...
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Kamiwaza" (
    rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Kamiwaza" 2>nul
    echo Start Menu shortcuts removed.
) else (
    echo No Start Menu shortcuts found.
)

@REM Clean up Desktop shortcuts
echo Cleaning up Desktop shortcuts...
for %%f in ("%USERPROFILE%\Desktop\*Kamiwaza*") do (
    del "%%f" 2>nul
    echo Removed Desktop shortcut: %%f
)

@REM Clean up registry entries
echo Cleaning up registry entries...
reg delete "HKCU\Software\Kamiwaza" /f 2>nul
if errorlevel 1 (
    echo No Kamiwaza registry keys found.
) else (
    echo Kamiwaza registry keys removed.
)

@REM Clean up RunOnce entries
echo Cleaning up RunOnce entries...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "KamiwazaGPUAutostart" /f 2>nul
if errorlevel 1 (
    echo No Kamiwaza RunOnce entries found.
) else (
    echo Kamiwaza RunOnce entries removed.
)

@REM Unregister WSL instance named "kamiwaza" if it exists
echo Checking for WSL instance "kamiwaza"...
wsl --unregister kamiwaza
if errorlevel 1 (
    echo Warning: Could not unregister WSL instance "kamiwaza" or it does not exist.
) else (
    echo WSL instance "kamiwaza" unregistered successfully.
)
wsl --list --verbose


echo.
echo Ensuring WSL is properly shut down...
wsl --shutdown 2>nul
if errorlevel 1 (
    echo Warning: Could not shut down WSL cleanly
) else (
    echo WSL shut down successfully.
)

echo.
echo Cleanup completed!
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul 