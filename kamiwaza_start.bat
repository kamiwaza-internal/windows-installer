@echo off
REM Kamiwaza Start - Start the platform and show status
REM This script starts Kamiwaza and keeps the CLI open for user interaction

setlocal enabledelayedexpansion

REM Set up logging
set LOGFILE=%LOCALAPPDATA%\Kamiwaza\logs\kamiwaza_start.log
if not exist "%LOCALAPPDATA%\Kamiwaza\logs" mkdir "%LOCALAPPDATA%\Kamiwaza\logs" >nul 2>&1
(call ) 2>nul

REM Log script start
>> "%LOGFILE%" echo [%DATE% %TIME%] Kamiwaza start script invoked

REM Sanitize .wslconfig to remove unsupported keys (e.g., wsl2.gpu) and reload WSL
>> "%LOGFILE%" echo [%DATE% %TIME%] Sanitizing .wslconfig and shutting down WSL
powershell -NoProfile -Command "try { $p = Join-Path $env:USERPROFILE '.wslconfig'; if (Test-Path $p) { $lines = Get-Content -LiteralPath $p -ErrorAction Stop; $filtered = $lines | Where-Object { $_ -notmatch '^\s*wsl2\.gpu\s*=' }; if ($filtered.Count -ne $lines.Count) { $filtered | Set-Content -LiteralPath $p -Encoding UTF8; } } } catch { }" >nul 2>&1
wsl --shutdown >nul 2>&1
>> "%LOGFILE%" echo [%DATE% %TIME%] WSL shutdown completed

echo ===============================================
echo            KAMIWAZA START
echo ===============================================
echo.

REM Determine the correct WSL instance name
set WSL_INSTANCE=kamiwaza
for /f "tokens=*" %%i in ('wsl --list --running --quiet ^| findstr /i "kamiwaza"') do (
    set WSL_INSTANCE=%%i
    goto :found_instance
)

for /f "tokens=*" %%i in ('wsl --list --quiet ^| findstr /i "kamiwaza"') do (
    set WSL_INSTANCE=%%i
    goto :found_instance
)

:found_instance
echo [INFO] Using WSL instance: %WSL_INSTANCE%
>> "%LOGFILE%" echo [%DATE% %TIME%] Using WSL instance: %WSL_INSTANCE%
echo.

REM Start Kamiwaza platform
echo [INFO] Starting Kamiwaza platform...
>> "%LOGFILE%" echo [%DATE% %TIME%] Starting Kamiwaza platform
wsl -d %WSL_INSTANCE% -- kamiwaza start

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Kamiwaza platform started successfully!
    >> "%LOGFILE%" echo [%DATE% %TIME%] Kamiwaza platform started successfully
) else (
    echo.
    echo [WARNING] Kamiwaza start command returned error code: %ERRORLEVEL%
    >> "%LOGFILE%" echo [%DATE% %TIME%] Kamiwaza start command returned error code: %ERRORLEVEL%
)

echo.
echo [INFO] Checking Kamiwaza status...
>> "%LOGFILE%" echo [%DATE% %TIME%] Checking Kamiwaza status
wsl -d %WSL_INSTANCE% -- kamiwaza status

REM Launch GUI Monitor if present
set GUI_PATH=%LOCALAPPDATA%\Kamiwaza\KamiwazaGUIManager.exe
if exist "%GUI_PATH%" (
    >> "%LOGFILE%" echo [%DATE% %TIME%] Launching GUI Manager from: %GUI_PATH%
    start "" "%GUI_PATH%" >nul 2>&1
) else (
    echo [INFO] GUI Manager not found at %GUI_PATH%
    >> "%LOGFILE%" echo [%DATE% %TIME%] GUI Manager not found at: %GUI_PATH%
)

echo.
echo ===============================================
echo            COMMANDS COMPLETED
echo ===============================================
echo.

>> "%LOGFILE%" echo [%DATE% %TIME%] Script execution completed successfully

echo Available commands you can run manually:
echo   wsl -d %WSL_INSTANCE% -- kamiwaza start    - Start the platform
echo   wsl -d %WSL_INSTANCE% -- kamiwaza stop     - Stop the platform  
echo   wsl -d %WSL_INSTANCE% -- kamiwaza status   - Show platform status
echo   wsl -d %WSL_INSTANCE%                      - Enter WSL directly
echo.
