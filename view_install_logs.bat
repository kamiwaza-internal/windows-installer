@echo off
echo ===============================================
echo Kamiwaza Installation Logs from journald
echo ===============================================
echo.

echo Choose log viewing option:
echo [1] View all Kamiwaza installation logs
echo [2] View today's installation logs
echo [3] View last 50 installation log entries
echo [4] Follow installation logs in real-time (tail -f style)
echo [5] View logs with timestamps
echo [6] View only error/warning logs
echo [0] Exit

set /p choice="Enter choice (0-6): "

if "%choice%"=="1" (
    echo.
    echo === All Kamiwaza Installation Logs ===
    wsl -d kamiwaza journalctl -t kamiwaza-install --no-pager
    pause
)

if "%choice%"=="2" (
    echo.
    echo === Today's Installation Logs ===
    wsl -d kamiwaza journalctl -t kamiwaza-install --since today --no-pager
    pause
)

if "%choice%"=="3" (
    echo.
    echo === Last 50 Installation Log Entries ===
    wsl -d kamiwaza journalctl -t kamiwaza-install -n 50 --no-pager
    pause
)

if "%choice%"=="4" (
    echo.
    echo === Following Installation Logs (Press Ctrl+C to stop) ===
    wsl -d kamiwaza journalctl -t kamiwaza-install -f
)

if "%choice%"=="5" (
    echo.
    echo === Installation Logs with Full Timestamps ===
    wsl -d kamiwaza journalctl -t kamiwaza-install --no-pager -o short-iso
    pause
)

if "%choice%"=="6" (
    echo.
    echo === Error/Warning Installation Logs ===
    wsl -d kamiwaza journalctl -t kamiwaza-install -p warning --no-pager
    pause
)

echo.
echo Other useful commands:
echo - View logs from specific time: wsl -d kamiwaza journalctl -t kamiwaza-install --since "2025-07-28 16:00"
echo - Search logs: wsl -d kamiwaza journalctl -t kamiwaza-install | grep "ERROR"
echo - View logs in JSON format: wsl -d kamiwaza journalctl -t kamiwaza-install -o json-pretty
echo.
pause