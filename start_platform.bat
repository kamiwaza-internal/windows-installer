@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo Start Kamiwaza Platform
echo ===============================================
echo.

REM Determine the correct WSL instance to use
set WSL_INSTANCE=
for /f "tokens=*" %%i in ('wsl --list --quiet ^| findstr /R "^kamiwaza-"') do (
    set WSL_INSTANCE=%%i
    goto :found_instance
)
:found_instance
if "%WSL_INSTANCE%"=="" set WSL_INSTANCE=kamiwaza

echo [INFO] Using WSL instance: %WSL_INSTANCE%
echo [INFO] Executing: wsl -d %WSL_INSTANCE% -- kamiwaza start

wsl -d %WSL_INSTANCE% -- kamiwaza start
set EXITCODE=%ERRORLEVEL%

if %EXITCODE% EQU 0 (
    echo [OK] Kamiwaza started successfully
) else (
    echo [ERROR] Kamiwaza failed to start (exit code: %EXITCODE%)
    echo Try manually: wsl -d %WSL_INSTANCE% -- kamiwaza start
)

echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul 