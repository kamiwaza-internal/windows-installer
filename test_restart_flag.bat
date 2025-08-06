@echo off
REM Test script for restart flag creation and detection
REM This helps debug the auto-start functionality

setlocal enabledelayedexpansion

echo ===============================================
echo Kamiwaza Restart Flag Test
echo ===============================================
echo Time: %DATE% %TIME%
echo.

set FLAG_FILE=%LOCALAPPDATA%\Kamiwaza\restart_required.flag
set KAMIWAZA_DIR=%LOCALAPPDATA%\Kamiwaza

echo [INFO] Testing restart flag functionality...
echo [INFO] Flag file location: %FLAG_FILE%
echo [INFO] Kamiwaza directory: %KAMIWAZA_DIR%
echo.

REM Check if Kamiwaza directory exists
if exist "%KAMIWAZA_DIR%" (
    echo [OK] Kamiwaza directory exists
) else (
    echo [WARN] Kamiwaza directory does not exist
    echo [INFO] Creating Kamiwaza directory for testing...
    mkdir "%KAMIWAZA_DIR%" 2>nul
    if exist "%KAMIWAZA_DIR%" (
        echo [OK] Created Kamiwaza directory
    ) else (
        echo [ERROR] Failed to create Kamiwaza directory
        pause
        exit /b 1
    )
)

REM Check current flag status
if exist "%FLAG_FILE%" (
    echo [INFO] Restart flag currently exists
    echo [INFO] Current flag contents:
    type "%FLAG_FILE%"
    echo.
    
    echo [QUESTION] Do you want to remove the existing flag? (y/N)
    set /p REMOVE_FLAG=
    if /i "!REMOVE_FLAG!"=="y" (
        del "%FLAG_FILE%" 2>nul
        if exist "%FLAG_FILE%" (
            echo [ERROR] Failed to remove flag
        ) else (
            echo [OK] Flag removed
        )
    )
) else (
    echo [INFO] No restart flag currently exists
)

echo.
echo [QUESTION] Do you want to create a test restart flag? (y/N)
set /p CREATE_FLAG=
if /i "!CREATE_FLAG!"=="y" (
    echo [INFO] Creating test restart flag...
    
    echo GPU_ACCELERATION_CONFIGURED > "%FLAG_FILE%"
    echo NVIDIA_RTX=true >> "%FLAG_FILE%"
    echo INTEL_ARC=false >> "%FLAG_FILE%"
    echo INTEL_INTEGRATED=false >> "%FLAG_FILE%"
    echo TIMESTAMP=%TIME% >> "%FLAG_FILE%"
    
    if exist "%FLAG_FILE%" (
        echo [OK] Test restart flag created
        echo [INFO] Flag contents:
        type "%FLAG_FILE%"
    ) else (
        echo [ERROR] Failed to create test flag
    )
)

echo.
echo [INFO] Testing autostart script detection...
echo [INFO] Running autostart script in test mode...
echo.

REM Run the autostart script to test detection
call "%~dp0kamiwaza_autostart.bat"

echo.
echo ===============================================
echo Restart Flag Test Complete
echo ===============================================
echo.
echo [INFO] Test completed. Check the output above for any issues.
echo [INFO] If the flag was detected, the autostart script should have run.
echo.
pause 