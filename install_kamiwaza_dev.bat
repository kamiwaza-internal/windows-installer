@echo off
echo Downloading Kamiwaza Installer (Developer Mode)...

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0

REM Default values if not provided by MSI
set MEMORY_CONFIG=14GB
set USER_EMAIL=default@kamiwaza.ai
set LICENSE_KEY=COMMUNITY-EDITION-ONLY
set USAGE_REPORTING=1
set INSTALL_MODE=dev

REM Parse command line parameters (passed from MSI)
if not "%1"=="" set MEMORY_CONFIG=%1
if not "%2"=="" set USER_EMAIL=%2
if not "%3"=="" set LICENSE_KEY=%3
if not "%4"=="" set USAGE_REPORTING=%4
if not "%5"=="" set INSTALL_MODE=%5

REM Configure WSL memory before installation
echo Configuring Kamiwaza dedicated memory (%MEMORY_CONFIG%)...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%configure_wsl_memory.ps1" -MemoryAmount "%MEMORY_CONFIG%"

REM Download the installer
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%download_exe.ps1" -DownloadUrl "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_0.5.0-rc1_amd64_build1.exe" -OutputPath "%SCRIPT_DIR%kamiwaza_installer_final.exe"

REM Check if download was successful
if %ERRORLEVEL%==0 (
    echo Download completed successfully!
    
    REM Setup debconf configuration in Ubuntu (if WSL is available)
    echo Configuring Kamiwaza debconf settings...
    where wsl >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo Setting up Ubuntu debconf configuration...
        wsl cp "%SCRIPT_DIR%setup_debconf.sh" /tmp/setup_debconf.sh
        wsl chmod +x /tmp/setup_debconf.sh
        wsl sudo /tmp/setup_debconf.sh --email "%USER_EMAIL%" --license-key "%LICENSE_KEY%" --usage-reporting "%USAGE_REPORTING%" --mode "%INSTALL_MODE%" --license-accepted "true"
        echo Debconf configuration completed!
    ) else (
        echo WSL not detected - debconf setup will be handled by installer
    )
    
    echo Starting Kamiwaza Installer in Developer Mode...
    "%SCRIPT_DIR%kamiwaza_installer_final.exe" --debug --memory=%MEMORY_CONFIG% --version=0.5.0-rc1 --codename=noble --build=1 --arch=amd64 --email="%USER_EMAIL%" --license-key="%LICENSE_KEY%" --usage-reporting=%USAGE_REPORTING% --mode=%INSTALL_MODE%
    
    echo.
    echo Installation completed!
    echo - WSL memory configured: %MEMORY_CONFIG%
    echo - User email: %USER_EMAIL%
    echo - Install mode: %INSTALL_MODE% (Developer)
    echo - Usage reporting: %USAGE_REPORTING%
    echo.
    echo Please run 'wsl --shutdown' to apply memory changes before using Kamiwaza.
) else (
    echo Download failed!
    pause
) 