@echo off
echo ===============================================
echo Kamiwaza Installation Logs Viewer
echo ===============================================
echo.

echo 1. Windows MSI Installation Log:
echo    %TEMP%\kamiwaza_install.log
if exist "%TEMP%\kamiwaza_install.log" (
    echo    [EXISTS - %~z1 bytes]
) else (
    echo    [NOT FOUND]
)
echo.

echo 2. WSL Instance Logs (in kamiwaza WSL):
echo    /var/log/apt/history.log - Installation history
echo    /var/log/apt/term.log    - Detailed terminal output  
echo    /var/log/dpkg.log        - Package installation details
echo.

echo Choose an option:
echo [1] View Windows MSI log
echo [2] View WSL apt history (shows errors)
echo [3] View WSL apt terminal output (detailed)
echo [4] View WSL dpkg log
echo [5] Open all logs in separate windows
echo [0] Exit

set /p choice="Enter choice (0-5): "

if "%choice%"=="1" (
    if exist "%TEMP%\kamiwaza_install.log" (
        notepad "%TEMP%\kamiwaza_install.log"
    ) else (
        echo MSI log file not found.
    )
)

if "%choice%"=="2" (
    echo.
    echo === WSL APT History Log ===
    wsl -d kamiwaza cat /var/log/apt/history.log
    pause
)

if "%choice%"=="3" (
    echo.
    echo === WSL APT Terminal Log (Last 50 lines) ===
    wsl -d kamiwaza tail -50 /var/log/apt/term.log
    pause
)

if "%choice%"=="4" (
    echo.
    echo === WSL DPKG Log (Last 30 lines) ===
    wsl -d kamiwaza tail -30 /var/log/dpkg.log
    pause  
)

if "%choice%"=="5" (
    start notepad "%TEMP%\kamiwaza_install.log"
    start cmd /k "wsl -d kamiwaza cat /var/log/apt/history.log && pause"
    start cmd /k "wsl -d kamiwaza tail -50 /var/log/apt/term.log && pause"
)

echo.
echo Log locations:
echo - Windows: %TEMP%\kamiwaza_install.log
echo - WSL:     /var/log/apt/ directory in kamiwaza instance
echo.
pause