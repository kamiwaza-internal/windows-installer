@echo off
title Kamiwaza Installation Pulse Monitor
echo ===============================================
echo Kamiwaza Installation Pulse Monitor
echo ===============================================
echo.
echo Monitoring: C:\temp\kamiwaza_pulse.log
echo.
echo Run the installer in another window and watch this for real-time progress...
echo Press Ctrl+C to stop monitoring
echo.
echo ===============================================
echo.

REM Create the temp directory if it doesn't exist
if not exist "C:\temp" mkdir "C:\temp"

REM Clear any existing log
if exist "C:\temp\kamiwaza_pulse.log" del "C:\temp\kamiwaza_pulse.log"

REM Monitor the log file
powershell -Command "while ($true) { if (Test-Path 'C:\temp\kamiwaza_pulse.log') { Get-Content 'C:\temp\kamiwaza_pulse.log' -Wait } else { Start-Sleep -Seconds 1 } }"