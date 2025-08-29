@echo off
REM Kamiwaza Start - Start the platform and show status
REM This script starts Kamiwaza and keeps the CLI open for user interaction

setlocal enabledelayedexpansion

REM Sanitize .wslconfig to remove unsupported keys (e.g., wsl2.gpu) and reload WSL
powershell -NoProfile -Command "try { $p = Join-Path $env:USERPROFILE '.wslconfig'; if (Test-Path $p) { $lines = Get-Content -LiteralPath $p -ErrorAction Stop; $filtered = $lines | Where-Object { $_ -notmatch '^\s*wsl2\.gpu\s*=' }; if ($filtered.Count -ne $lines.Count) { $filtered | Set-Content -LiteralPath $p -Encoding UTF8; } } } catch { }" >nul 2>&1
wsl --shutdown >nul 2>&1

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
echo.

REM Start Kamiwaza platform
echo [INFO] Starting Kamiwaza platform...
wsl -d %WSL_INSTANCE% -- kamiwaza start

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Kamiwaza platform started successfully!
) else (
    echo.
    echo [WARNING] Kamiwaza start command returned error code: %ERRORLEVEL%
)

echo.
echo [INFO] Checking Kamiwaza status...
wsl -d %WSL_INSTANCE% -- kamiwaza status

REM Launch GUI Monitor if present
set GUI_PATH=%LOCALAPPDATA%\Kamiwaza\GUI\KamiwazaGUIManager.exe
if exist "%GUI_PATH%" (
    start "" "%GUI_PATH%" >nul 2>&1
) else (
    echo [INFO] GUI Manager not found at %GUI_PATH%
)

REM Launch frontend (HTTPS). If not up yet, open a lightweight local loading page that auto-retries.
set TMP_HTML=%TEMP%\kamiwaza_loading.html
>"%TMP_HTML%" (
    echo ^<!DOCTYPE html^>
    echo ^<html lang="en"^>
    echo ^<head^>
    echo   ^<meta charset="utf-8"/^>
    echo   ^<meta http-equiv="refresh" content="2;url=https://localhost/"/^>
    echo   ^<title^>Kamiwaza Loading...^</title^>
    echo   ^<style^>body{font-family:Segoe UI,Arial,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#0b0f14;color:#e6edf3} .card{padding:28px 32px;border-radius:12px;background:#121820;box-shadow:0 6px 26px rgba(0,0,0,.35)} h1{font-size:18px;margin:0 0 8px} p{margin:0;color:#9fb1c1;font-size:13px}^</style^>
    echo ^</head^>
    echo ^<body^>
    echo   ^<div class="card"^>
    echo     ^<h1^>Starting Kamiwaza...^</h1^>
    echo     ^<p^>If the page doesn't load immediately, it will retry automatically.^</p^>
    echo   ^</div^>
    echo ^</body^>
    echo ^</html^>
)
start "" "%TMP_HTML%" >nul 2>&1

echo.
echo ===============================================
echo            COMMANDS COMPLETED
echo ===============================================
echo.
echo Available commands you can run manually:
echo   wsl -d %WSL_INSTANCE% -- kamiwaza start    - Start the platform
echo   wsl -d %WSL_INSTANCE% -- kamiwaza stop     - Stop the platform  
echo   wsl -d %WSL_INSTANCE% -- kamiwaza status   - Show platform status
echo   wsl -d %WSL_INSTANCE%                      - Enter WSL directly
echo.
