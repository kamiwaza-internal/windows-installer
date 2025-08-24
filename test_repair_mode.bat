@echo off
setlocal enabledelayedexpansion

echo === KAMIWAZA REPAIR MODE TEST ===
echo.

REM Check if MSI exists
if not exist "kamiwaza_installer.msi" (
    echo [ERROR] MSI installer not found. Please run build.bat first.
    pause
    exit /b 1
)

echo [INFO] Found MSI installer: kamiwaza_installer.msi
echo.

REM Check if already installed
echo [INFO] Checking if Kamiwaza is already installed...
reg query "HKCU\Software\Kamiwaza" >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Kamiwaza appears to be already installed
    echo [INFO] Testing repair mode...
    set TEST_MODE=repair
) else (
    echo [INFO] Kamiwaza not installed, testing fresh install first...
    set TEST_MODE=install
)

echo.
echo === TESTING %TEST_MODE% MODE ===
echo.

if "%TEST_MODE%"=="install" (
    echo [STEP 1] Installing Kamiwaza...
    echo [INFO] Command: msiexec /i kamiwaza_installer.msi /quiet
    msiexec /i kamiwaza_installer.msi /quiet
    
    if %errorlevel% equ 0 (
        echo [SUCCESS] Installation completed
        echo.
        echo [STEP 2] Testing repair mode...
        echo [INFO] Command: msiexec /f kamiwaza_installer.msi /quiet
        msiexec /f kamiwaza_installer.msi /quiet
        
        if %errorlevel% equ 0 (
            echo [SUCCESS] Repair mode completed
        ) else (
            echo [ERROR] Repair mode failed with exit code %errorlevel%
        )
    ) else (
        echo [ERROR] Installation failed with exit code %errorlevel%
    )
) else (
    echo [STEP 1] Testing repair mode...
    echo [INFO] Command: msiexec /f kamiwaza_installer.msi /quiet
    msiexec /f kamiwaza_installer.msi /quiet
    
    if %errorlevel% equ 0 (
        echo [SUCCESS] Repair mode completed
    ) else (
        echo [ERROR] Repair mode failed with exit code %errorlevel%
    )
)

echo.
echo === VERIFICATION ===
echo.

REM Check if custom actions ran by looking for expected files/registry entries
echo [INFO] Checking if repair mode custom actions executed...

REM Check for WSL instance
echo [INFO] Checking WSL instances...
wsl --list --quiet 2>nul | findstr "kamiwaza" >nul
if %errorlevel% equ 0 (
    echo [OK] WSL kamiwaza instance found
) else (
    echo [WARN] WSL kamiwaza instance not found
)

REM Check for GPU detection scripts
echo [INFO] Checking GPU detection scripts...
if exist "%LOCALAPPDATA%\Kamiwaza\setup_nvidia_gpu.sh" (
    echo [OK] NVIDIA GPU script found
) else (
    echo [INFO] NVIDIA GPU script not found (may not be applicable)
)

if exist "%LOCALAPPDATA%\Kamiwaza\setup_intel_arc_gpu.sh" (
    echo [OK] Intel Arc GPU script found
) else (
    echo [INFO] Intel Arc GPU script not found (may not be applicable)
)

REM Check for autostart registry entries
echo [INFO] Checking autostart registry entries...
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "KamiwazaGPUAutostart" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Autostart registry entry found
) else (
    echo [WARN] Autostart registry entry not found
)

REM Check for scheduled tasks
echo [INFO] Checking scheduled tasks...
schtasks /Query /TN "KamiwazaAutostart" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Autostart scheduled task found
) else (
    echo [WARN] Autostart scheduled task not found
)

echo.
echo === REPAIR MODE TEST COMPLETE ===
echo.
echo To test manually:
echo 1. Open Control Panel ^> Programs ^> Programs and Features
echo 2. Find Kamiwaza and click "Change"
echo 3. Select "Repair" option
echo 4. Monitor the installation process
echo.
echo To view detailed logs:
echo - Check %TEMP%\kamiwaza_install.log
echo - Check %LOCALAPPDATA%\Kamiwaza\logs\
echo.
pause 