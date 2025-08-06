@echo off
echo ===============================================
echo Kamiwaza MSI Pulse Check System Test
echo ===============================================
echo.

echo 1. Starting pulse monitor in background...
start "Pulse Monitor" cmd /c "call watch_pulse.bat"

echo 2. Waiting 3 seconds for monitor to start...
timeout /t 3 /nobreak >nul

echo 3. Testing manual pulse logging...
if not exist "C:\temp" mkdir "C:\temp"
echo PULSE: Test manual pulse entry from test script >> C:\temp\kamiwaza_pulse.log

echo 4. Instructions for full test:
echo    a. Run the MSI installer in another window
echo    b. Watch the Pulse Monitor window for real-time progress
echo    c. The pulse log shows each custom action as it executes
echo    d. If installation fails silently, the pulse log will show where it stopped
echo.

echo 5. Pulse log file location: C:\temp\kamiwaza_pulse.log
echo.

echo Current pulse log contents (if any):
echo ===============================================
if exist "C:\temp\kamiwaza_pulse.log" (
    type "C:\temp\kamiwaza_pulse.log"
) else (
    echo [No pulse log found yet]
)
echo ===============================================
echo.

echo Test setup complete. The pulse monitor is running in a separate window.
echo Run your MSI installer now and watch the progress!
pause