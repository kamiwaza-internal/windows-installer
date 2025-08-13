@echo off
setlocal enabledelayedexpansion

REM GPU Detection Script for Kamiwaza Installer (CMD Version)
REM This runs BEFORE WSL/Debian installation to detect GPU hardware

echo ===============================================
echo Kamiwaza GPU Detection (Pre-Installation)
echo ===============================================
echo.

REM Initialize variables
set NVIDIA_RTX_DETECTED=0
set INTEL_ARC_DETECTED=0
set GPU_DETECTION_FILE=%TEMP%\kamiwaza_gpu_detection.txt

REM Clear previous detection results
if exist "%GPU_DETECTION_FILE%" del "%GPU_DETECTION_FILE%"

echo [INFO] Detecting graphics hardware...
echo GPU Detection Results > "%GPU_DETECTION_FILE%"
echo Generated: %DATE% %TIME% >> "%GPU_DETECTION_FILE%"
echo. >> "%GPU_DETECTION_FILE%"

REM Use PowerShell to get GPU information
echo [INFO] Running GPU detection via PowerShell...
powershell -Command "Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility | Format-Table -AutoSize"

REM Check for NVIDIA GeForce RTX
echo [INFO] Checking for NVIDIA GeForce RTX GPUs...
powershell -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*NVIDIA GeForce RTX*' } | Select-Object Name" > "%TEMP%\nvidia_check.tmp"
for /f "tokens=*" %%i in ('type "%TEMP%\nvidia_check.tmp" 2^>nul ^| find "RTX"') do (
    set NVIDIA_RTX_DETECTED=1
    echo [FOUND] NVIDIA GeForce RTX GPU detected: %%i
    echo NVIDIA_RTX_DETECTED=1 >> "%GPU_DETECTION_FILE%"
    echo NVIDIA_GPU_NAME=%%i >> "%GPU_DETECTION_FILE%"
)

REM Check for Intel Arc
echo [INFO] Checking for Intel Arc GPUs...
powershell -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*Intel(R) Arc(TM)*' } | Select-Object Name" > "%TEMP%\intel_check.tmp"
for /f "tokens=*" %%i in ('type "%TEMP%\intel_check.tmp" 2^>nul ^| find "Arc"') do (
    set INTEL_ARC_DETECTED=1
    echo [FOUND] Intel Arc GPU detected: %%i
    echo INTEL_ARC_DETECTED=1 >> "%GPU_DETECTION_FILE%"
    echo INTEL_GPU_NAME=%%i >> "%GPU_DETECTION_FILE%"
)

REM Clean up temp files
del "%TEMP%\nvidia_check.tmp" 2>nul
del "%TEMP%\intel_check.tmp" 2>nul

REM Log detection results
echo. >> "%GPU_DETECTION_FILE%"
if !NVIDIA_RTX_DETECTED!==1 (
    echo [GPU] NVIDIA GeForce RTX acceleration will be configured
    echo SETUP_SCRIPT=setup_nvidia_gpu.sh >> "%GPU_DETECTION_FILE%"
) else (
    echo NVIDIA_RTX_DETECTED=0 >> "%GPU_DETECTION_FILE%"
)

if !INTEL_ARC_DETECTED!==1 (
    echo [GPU] Intel Arc acceleration will be configured
    echo SETUP_SCRIPT=setup_intel_arc_gpu.sh >> "%GPU_DETECTION_FILE%"
) else (
    echo INTEL_ARC_DETECTED=0 >> "%GPU_DETECTION_FILE%"
)

if !NVIDIA_RTX_DETECTED!==0 if !INTEL_ARC_DETECTED!==0 (
    echo [INFO] No supported GPU acceleration hardware detected
    echo [INFO] Kamiwaza will run with CPU-only acceleration
    echo GPU_ACCELERATION=CPU_ONLY >> "%GPU_DETECTION_FILE%"
) else (
    echo GPU_ACCELERATION=HARDWARE >> "%GPU_DETECTION_FILE%"
)

echo.
echo ===============================================
echo GPU Detection Complete
echo ===============================================
echo Detection results saved to: %GPU_DETECTION_FILE%
echo.

REM Display summary
echo === GPU Detection Summary ===
if !NVIDIA_RTX_DETECTED!==1 echo [OK] NVIDIA GeForce RTX GPU detected
if !INTEL_ARC_DETECTED!==1 echo [OK] Intel Arc GPU detected  
if !NVIDIA_RTX_DETECTED!==0 if !INTEL_ARC_DETECTED!==0 echo [WARN] No supported GPU hardware detected
echo.

REM Set environment variables for the installer
if !NVIDIA_RTX_DETECTED!==1 (
    set KAMIWAZA_NVIDIA_RTX=1
    echo Setting KAMIWAZA_NVIDIA_RTX=1
)
if !INTEL_ARC_DETECTED!==1 (
    set KAMIWAZA_INTEL_ARC=1
    echo Setting KAMIWAZA_INTEL_ARC=1
)

echo [INFO] GPU detection completed successfully
echo [INFO] Results will be used during Kamiwaza platform installation
echo.

REM Exit with success
exit /b 0