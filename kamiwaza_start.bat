@echo off
REM Kamiwaza Start - Start the platform and show status
REM This script starts Kamiwaza and keeps the CLI open for user interaction

setlocal enabledelayedexpansion

echo ===============================================
echo            KAMIWAZA START
echo ===============================================
echo.

REM Determine the correct WSL instance name
set WSL_INSTANCE=kamiwaza
for /f "tokens=*" %%i in ('wsl --list --running --quiet ^| findstr /i "kamiwaza"') do (
    set WSL_INSTANCE=%%i
    goto :found_instance
)

for /f "tokens=*" %%i in ('wsl --list --quiet ^| findstr /i "kamiwaza"') do (
    set WSL_INSTANCE=%%i
    goto :found_instance
)

:found_instance
echo [INFO] Using WSL instance: %WSL_INSTANCE%
echo.

REM Start Kamiwaza platform
echo [INFO] Starting Kamiwaza platform...
wsl -d %WSL_INSTANCE% -- kamiwaza start

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Kamiwaza platform started successfully!
) else (
    echo.
    echo [WARNING] Kamiwaza start command returned error code: %ERRORLEVEL%
)

echo.
echo [INFO] Checking Kamiwaza status...
wsl -d %WSL_INSTANCE% -- kamiwaza status

echo.
echo ===============================================
echo            COMMANDS COMPLETED
echo ===============================================
echo.
echo Available commands you can run manually:
echo   wsl -d %WSL_INSTANCE% -- kamiwaza start    - Start the platform
echo   wsl -d %WSL_INSTANCE% -- kamiwaza stop     - Stop the platform  
echo   wsl -d %WSL_INSTANCE% -- kamiwaza status   - Show platform status
echo   wsl -d %WSL_INSTANCE%                      - Enter WSL directly
echo.
