@echo off
REM Kamiwaza Auto-Start Script
REM This script runs after system restart to automatically start Kamiwaza

setlocal enabledelayedexpansion

echo ===============================================
echo Kamiwaza Auto-Start - Post-Restart Launch
echo ===============================================
echo Time: %DATE% %TIME%
echo.

REM Check if restart flag exists
set FLAG_FILE=%LOCALAPPDATA%\Kamiwaza\restart_required.flag
if not exist "%FLAG_FILE%" (
    echo No restart flag found - auto-start not required
    timeout /t 5 /nobreak >nul
    exit /b 0
)

echo [INFO] Restart flag detected - starting Kamiwaza platform...
echo [INFO] This window will remain open to show Kamiwaza status
echo.

REM Remove the restart flag to prevent repeated auto-starts
del "%FLAG_FILE%" 2>nul
if exist "%FLAG_FILE%" (
    echo [WARN] Could not remove restart flag - may auto-start again
) else (
    echo [OK] Restart flag removed
)

echo.
echo ===============================================
echo Starting Kamiwaza Platform
echo ===============================================
echo.

REM Start Kamiwaza in the dedicated WSL instance
echo [INFO] Executing: wsl -d kamiwaza -- kamiwaza start
echo [INFO] Please wait while Kamiwaza initializes...
echo [INFO] This may take several minutes for first startup
echo.

REM Run kamiwaza start and keep the window open
wsl -d kamiwaza -- kamiwaza start

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ===============================================
    echo Kamiwaza Started Successfully!
    echo ===============================================
    echo.
    echo [OK] Kamiwaza platform is now running
    echo [INFO] Access your deployment at: https://localhost
    echo [INFO] To check status: wsl -d kamiwaza -- kamiwaza status
    echo [INFO] To access WSL directly: wsl -d kamiwaza
    echo.
    echo [INFO] This window will remain open for status monitoring
    echo [INFO] You can safely minimize this window
    echo [INFO] To close Kamiwaza, run: wsl -d kamiwaza -- kamiwaza stop
    echo.
) else (
    echo.
    echo ===============================================
    echo Kamiwaza Startup Failed
    echo ===============================================
    echo.
    echo [ERROR] Kamiwaza failed to start (exit code: %ERRORLEVEL%)
    echo [INFO] You can try starting manually with: wsl -d kamiwaza -- kamiwaza start
    echo [INFO] Check logs with: wsl -d kamiwaza -- kamiwaza logs
    echo [INFO] Get status with: wsl -d kamiwaza -- kamiwaza status
    echo.
)

echo ===============================================
echo Auto-Start Complete
echo ===============================================
echo Press any key to close this window, or leave open for monitoring...
pause >nul