@echo off
echo Testing GPU Detection Script
echo =============================

echo.
echo 1. Running detect_gpu_cmd.bat...
call detect_gpu_cmd.bat

echo.
echo 2. Checking detection results...
if exist "%TEMP%\kamiwaza_gpu_detection.txt" (
    echo.
    echo Detection file contents:
    type "%TEMP%\kamiwaza_gpu_detection.txt"
) else (
    echo ERROR: Detection file not created
)

echo.
echo 3. Testing Intel GPU detection specifically...
powershell -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*Intel*' } | Select-Object Name, AdapterCompatibility"

pause