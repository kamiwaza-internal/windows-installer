@echo off
REM Kamiwaza Auto-Start Script
REM This script runs after system restart to automatically start Kamiwaza

setlocal enabledelayedexpansion

REM Ensure we run from a consistent working directory
pushd %~dp0

REM Create basic log
set LOGFILE=%LOCALAPPDATA%\Kamiwaza\logs\autostart.log
if not exist "%LOCALAPPDATA%\Kamiwaza\logs" mkdir "%LOCALAPPDATA%\Kamiwaza\logs" >nul 2>&1
(call ) 2>nul

echo ===============================================
echo Kamiwaza Auto-Start - Post-Restart Launch
echo ===============================================
echo Time: %DATE% %TIME%
echo.

echo [DEBUG] Logging to: %LOGFILE%
>> "%LOGFILE%" echo [%DATE% %TIME%] Autostart invoked

REM Determine the correct WSL instance to use
set WSL_INSTANCE=
for /f "tokens=*" %%i in ('wsl --list --quiet ^| findstr /R "^kamiwaza-"') do (
	set WSL_INSTANCE=%%i
	goto :found_instance
)
:found_instance
if "%WSL_INSTANCE%"=="" set WSL_INSTANCE=kamiwaza

echo [DEBUG] Using WSL instance: %WSL_INSTANCE%
>> "%LOGFILE%" echo [%DATE% %TIME%] Using instance: %WSL_INSTANCE%
 
REM Check if restart flag exists (optional)
set FLAG_FILE=%LOCALAPPDATA%\Kamiwaza\restart_required.flag
echo [DEBUG] Checking for restart flag: %FLAG_FILE%

REM Check if the Kamiwaza directory exists
if not exist "%LOCALAPPDATA%\Kamiwaza" (
	echo [DEBUG] Kamiwaza directory not found: %LOCALAPPDATA%\Kamiwaza
	echo No Kamiwaza installation detected - auto-start not required
	>> "%LOGFILE%" echo [%DATE% %TIME%] Kamiwaza dir missing; exiting
	timeout /t 3 /nobreak >nul
	exit /b 0
)

echo.
echo [INFO] This window will remain open to show Kamiwaza status
echo.

REM WSL readiness: wait until wsl --status and basic echo succeed
set /a ATTEMPT=0
set /a MAX_ATTEMPTS=10
set /a SLEEP_SECONDS=5
:wait_wsl
set /a ATTEMPT+=1
wsl --status >nul 2>&1
if errorlevel 1 (
	>> "%LOGFILE%" echo [%DATE% %TIME%] WSL status not ready (attempt !ATTEMPT!)
	if !ATTEMPT! GEQ !MAX_ATTEMPTS! goto :proceed
	timeout /t !SLEEP_SECONDS! /nobreak >nul
	goto :wait_wsl
)

wsl -d %WSL_INSTANCE% echo READY >nul 2>&1
if errorlevel 1 (
	>> "%LOGFILE%" echo [%DATE% %TIME%] Instance not ready (attempt !ATTEMPT!)
	if !ATTEMPT! GEQ !MAX_ATTEMPTS! goto :proceed
	timeout /t !SLEEP_SECONDS! /nobreak >nul
	goto :wait_wsl
)

:proceed

REM Remove the restart flag now that we are attempting startup
del "%FLAG_FILE%" 2>nul

REM Also remove any stale HKCU RunOnce entry to prevent repeated auto-starts
echo [INFO] Cleaning RunOnce (HKCU) entry if present...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "KamiwazaGPUAutostart" /f >nul 2>&1

REM Start Kamiwaza in the dedicated WSL instance with limited retries
set /a START_ATTEMPTS=0
set /a START_MAX=3
:try_start
echo.
echo ===============================================
echo Starting Kamiwaza Platform (attempt %START_ATTEMPTS%/%START_MAX%)
echo ===============================================
echo.

REM Run kamiwaza start and keep the window open
echo [INFO] Executing: wsl -d %WSL_INSTANCE% -- kamiwaza start
>> "%LOGFILE%" echo [%DATE% %TIME%] Starting kamiwaza
wsl -d %WSL_INSTANCE% -- kamiwaza start

REM Check exit code
if %ERRORLEVEL% EQU 0 (
	echo.
	echo ===============================================
	echo Kamiwaza Started Successfully!
	echo ===============================================
	echo.
	echo [OK] Kamiwaza platform is now running
	echo [INFO] Access your deployment at: https://localhost
	echo [INFO] To check status: wsl -d kamiwaza -- kamiwaza status
	echo [INFO] To access WSL directly: wsl -d kamiwaza
	echo.
	>> "%LOGFILE%" echo [%DATE% %TIME%] Started successfully
	REM Cleanup scheduled task to avoid future re-runs
	schtasks /Delete /TN "KamiwazaAutostart" /F >nul 2>&1
	popd
	goto :done
) else (
	echo.
	echo ===============================================
	echo Kamiwaza Startup Failed
	echo ===============================================
	echo.
	echo [ERROR] Kamiwaza failed to start (exit code: %ERRORLEVEL%)
	echo [INFO] You can try starting manually with: wsl -d kamiwaza -- kamiwaza start
	echo [INFO] Check logs with: wsl -d kamiwaza -- kamiwaza logs
	echo [INFO] Get status with: wsl -d kamiwaza -- kamiwaza status
	echo.
	>> "%LOGFILE%" echo [%DATE% %TIME%] Start failed with code %ERRORLEVEL%
	set /a START_ATTEMPTS+=1
	if %START_ATTEMPTS% LSS %START_MAX% (
		echo [INFO] Retrying in 10 seconds...
		timeout /t 10 /nobreak >nul
		goto :try_start
	)
)

:done
echo ===============================================
echo Auto-Start Complete
echo ===============================================
echo [INFO] Launching Kamiwaza GUI Monitor...
start "" "%LOCALAPPDATA%\Kamiwaza\KamiwazaManager.exe"

echo Press any key to close this window, or leave open for debugging...

pause >nul
popd