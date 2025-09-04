@echo off
setlocal enabledelayedexpansion

set NVIDIA_RTX_DETECTED=0
set INTEL_ARC_DETECTED=0
set GPU_DETECTION_FILE=%TEMP%\kamiwaza_gpu_detection.txt

if exist "%GPU_DETECTION_FILE%" del "%GPU_DETECTION_FILE%" >nul 2>&1

> "%GPU_DETECTION_FILE%" echo GPU Detection Results
>> "%GPU_DETECTION_FILE%" echo Generated: %DATE% %TIME%
>> "%GPU_DETECTION_FILE%" echo.

powershell -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*NVIDIA GeForce RTX*' } | Select-Object Name" > "%TEMP%\nvidia_check.tmp" 2>nul
for /f "tokens=*" %%i in ('type "%TEMP%\nvidia_check.tmp" 2^>nul ^| find "RTX"') do (
    set NVIDIA_RTX_DETECTED=1
    >> "%GPU_DETECTION_FILE%" echo NVIDIA_RTX_DETECTED=1
    >> "%GPU_DETECTION_FILE%" echo NVIDIA_GPU_NAME=%%i
)

powershell -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*Intel(R) Arc(TM)*' } | Select-Object Name" > "%TEMP%\intel_check.tmp" 2>nul
for /f "tokens=*" %%i in ('type "%TEMP%\intel_check.tmp" 2^>nul ^| find "Arc"') do (
    set INTEL_ARC_DETECTED=1
    >> "%GPU_DETECTION_FILE%" echo INTEL_ARC_DETECTED=1
    >> "%GPU_DETECTION_FILE%" echo INTEL_GPU_NAME=%%i
)

del "%TEMP%\nvidia_check.tmp" 2>nul
del "%TEMP%\intel_check.tmp" 2>nul

>> "%GPU_DETECTION_FILE%" echo.
if !NVIDIA_RTX_DETECTED!==1 (
    >> "%GPU_DETECTION_FILE%" echo SETUP_SCRIPT=setup_nvidia_gpu.sh
) else (
    >> "%GPU_DETECTION_FILE%" echo NVIDIA_RTX_DETECTED=0
)

if !INTEL_ARC_DETECTED!==1 (
    >> "%GPU_DETECTION_FILE%" echo SETUP_SCRIPT=setup_intel_arc_gpu.sh
) else (
    >> "%GPU_DETECTION_FILE%" echo INTEL_ARC_DETECTED=0
)

if !NVIDIA_RTX_DETECTED!==0 if !INTEL_ARC_DETECTED!==0 (
    >> "%GPU_DETECTION_FILE%" echo GPU_ACCELERATION=CPU_ONLY
) else (
    >> "%GPU_DETECTION_FILE%" echo GPU_ACCELERATION=HARDWARE
)

if !NVIDIA_RTX_DETECTED!==1 set KAMIWAZA_NVIDIA_RTX=1
if !INTEL_ARC_DETECTED!==1 set KAMIWAZA_INTEL_ARC=1

endlocal
exit /b 0