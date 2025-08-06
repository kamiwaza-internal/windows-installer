@echo off
echo ===============================================
echo Kamiwaza MSI Installation Debug Log Checker
echo ===============================================
echo.

echo 1. Checking MSI debug log...
if exist "%TEMP%\kamiwaza_msi_debug.log" (
    echo [FOUND] MSI Debug Log: %TEMP%\kamiwaza_msi_debug.log
    echo.
    echo === Recent MSI Debug Log Content ===
    type "%TEMP%\kamiwaza_msi_debug.log"
    echo.
    echo === End MSI Debug Log ===
) else (
    echo [NOT FOUND] MSI debug log not found at: %TEMP%\kamiwaza_msi_debug.log
)

echo.
echo 2. Checking Windows Installer logs...
if exist "%TEMP%\kamiwaza_install.log" (
    echo [FOUND] Windows Installer Log: %TEMP%\kamiwaza_install.log
    echo Last 20 lines:
    powershell -Command "Get-Content '%TEMP%\kamiwaza_install.log' -Tail 20"
) else (
    echo [NOT FOUND] Windows installer log not found at: %TEMP%\kamiwaza_install.log
)

echo.
echo 3. Checking for restart flag...
if exist "%LOCALAPPDATA%\Kamiwaza\restart_required.flag" (
    echo [FOUND] Restart flag: %LOCALAPPDATA%\Kamiwaza\restart_required.flag
    type "%LOCALAPPDATA%\Kamiwaza\restart_required.flag"
) else (
    echo [NOT FOUND] No restart flag found
)

echo.
echo 4. Checking registry auto-start entry...
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "KamiwazaAutoStart" 2>nul
if %errorlevel% EQU 0 (
    echo [FOUND] Auto-start registry entry exists
) else (
    echo [NOT FOUND] No auto-start registry entry
)

echo.
echo 5. Checking GPU detection results...
if exist "%TEMP%\kamiwaza_gpu_detection.txt" (
    echo [FOUND] GPU Detection Results: %TEMP%\kamiwaza_gpu_detection.txt
    echo.
    type "%TEMP%\kamiwaza_gpu_detection.txt"
) else (
    echo [NOT FOUND] No GPU detection results found
)

echo.
echo ===============================================
echo Log Check Complete
echo ===============================================
pause