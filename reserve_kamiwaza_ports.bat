@echo off
REM Reserve Kamiwaza port range 61100-61299
REM Must be run as Administrator

echo ===============================================
echo Kamiwaza Port Reservation Script
echo ===============================================
echo This will reserve ports 61100-61299 for Kamiwaza
echo to prevent port collisions with other applications.
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [ERROR] This script requires Administrator privileges!
    echo Please run as Administrator and try again.
    echo.
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)

echo [INFO] Running with Administrator privileges...
echo.

REM Reserve the port range
echo Reserving ports 61100-61299 for Kamiwaza...
netsh int ipv4 add excludedportrange protocol=tcp startport=61100 numberofports=200 store=persistent

if %errorlevel% EQU 0 (
    echo [SUCCESS] Successfully reserved ports 61100-61299 for Kamiwaza
    echo These ports are now excluded from Windows dynamic port allocation
) else (
    echo [WARNING] Failed to reserve some or all ports
    echo This may be because some ports in the range are already in use
    echo or reserved by another application
)

echo.
echo Checking current port exclusions for Kamiwaza range...
netsh int ipv4 show excludedportrange protocol=tcp | findstr "61"

echo.
echo ===============================================
echo Port reservation complete!
echo ===============================================
echo.
echo To verify no applications are using these ports:
echo   netstat -an ^| findstr :611
echo.
echo To remove these reservations later:
echo   netsh int ipv4 delete excludedportrange protocol=tcp startport=61100 numberofports=200
echo.
pause