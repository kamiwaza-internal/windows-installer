@echo off
REM Test script for GPU setup script execution
REM This helps debug GPU acceleration configuration

setlocal enabledelayedexpansion

echo ===============================================
echo Kamiwaza GPU Setup Test
echo ===============================================
echo Time: %DATE% %TIME%
echo.

echo [INFO] Testing GPU setup script execution...
echo [INFO] This will check if GPU setup scripts are properly executed in WSL
echo.

REM Check if WSL is available
echo [INFO] Checking WSL availability...
wsl --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] WSL is not available
    echo [INFO] Please install WSL first: wsl --install
    pause
    exit /b 1
)
echo [OK] WSL is available

REM Check for kamiwaza WSL instance
echo [INFO] Checking for kamiwaza WSL instance...
wsl -d kamiwaza -- echo "test" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] kamiwaza WSL instance not found
    echo [INFO] Checking for other WSL instances...
    wsl --list --quiet
    echo.
    echo [QUESTION] Do you want to test with a different WSL instance? (y/N)
    set /p USE_DIFFERENT=
    if /i "!USE_DIFFERENT!"=="y" (
        echo [INFO] Please enter the WSL instance name to test with:
        set /p WSL_INSTANCE=
        set WSL_CMD=wsl -d !WSL_INSTANCE!
    ) else (
        echo [INFO] Skipping GPU setup test - no suitable WSL instance
        pause
        exit /b 0
    )
) else (
    echo [OK] kamiwaza WSL instance found
    set WSL_CMD=wsl -d kamiwaza
)

echo.
echo [INFO] Testing GPU setup scripts in WSL...
echo [INFO] WSL Command: !WSL_CMD!
echo.

REM Check if GPU setup scripts exist in WSL
echo [INFO] Checking for GPU setup scripts in WSL...
!WSL_CMD! -- ls -la /usr/local/bin/setup_*_gpu.sh 2>/dev/null || echo "No GPU setup scripts found"

echo.
echo [INFO] Checking GPU detection results...
!WSL_CMD! -- cat /tmp/kamiwaza_gpu_detection.txt 2>/dev/null || echo "No GPU detection results found"

echo.
echo [INFO] Running GPU status script (if available)...
!WSL_CMD! -- /usr/local/bin/kamiwaza_gpu_status.sh 2>/dev/null || echo "GPU status script not available"

echo.
echo [QUESTION] Do you want to manually run a GPU setup script? (y/N)
set /p RUN_SETUP=
if /i "!RUN_SETUP!"=="y" (
    echo [INFO] Available GPU setup scripts:
    !WSL_CMD! -- ls -la /usr/local/bin/setup_*_gpu.sh 2>/dev/null || echo "No scripts found"
    echo.
    echo [INFO] Please enter the script name to run (e.g., setup_nvidia_gpu.sh):
    set /p SCRIPT_NAME=
    if not "!SCRIPT_NAME!"=="" (
        echo [INFO] Running !SCRIPT_NAME!...
        !WSL_CMD! -- sudo /usr/local/bin/!SCRIPT_NAME!
        echo.
        echo [INFO] Script execution completed
    )
)

echo.
echo [INFO] Checking system GPU information...
echo [INFO] Windows GPU info:
wmic path win32_VideoController get name,driverversion /format:list

echo.
echo [INFO] WSL GPU info:
!WSL_CMD! -- lspci | grep -i vga 2>/dev/null || echo "No GPU info available in WSL"

echo.
echo [INFO] Checking for NVIDIA drivers in WSL...
!WSL_CMD! -- nvidia-smi 2>/dev/null || echo "NVIDIA drivers not available in WSL"

echo.
echo [INFO] Checking for Intel GPU drivers in WSL...
!WSL_CMD! -- ls /dev/dri/ 2>/dev/null || echo "Intel GPU drivers not available in WSL"

echo.
echo ===============================================
echo GPU Setup Test Complete
echo ===============================================
echo.
echo [INFO] Test completed. Check the output above for any issues.
echo [INFO] If GPU setup scripts are not found, they may not have been executed during installation.
echo.
pause 