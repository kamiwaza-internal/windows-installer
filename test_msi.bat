@echo off
echo Testing Kamiwaza MSI Installer...
echo.

REM Set variables
set MSI_FILE=installer.msi
set LOG_FILE=msi_test_log.txt
set INSTALL_DIR=%LOCALAPPDATA%\Kamiwaza

REM Clean up previous installation
echo Cleaning up previous installation...
msiexec /x "%MSI_FILE%" /quiet /norestart
timeout /t 5 /nobreak >nul

REM Remove install directory if it exists
if exist "%INSTALL_DIR%" (
    echo Removing old install directory...
    rmdir /s /q "%INSTALL_DIR%"
)

REM Test installation with full logging
echo.
echo Installing MSI with full logging...
echo Command: msiexec /i "%MSI_FILE%" /l*v "%LOG_FILE%" /quiet
msiexec /i "%MSI_FILE%" /l*v "%LOG_FILE%" /quiet

REM Check exit code
if %ERRORLEVEL%==0 (
    echo SUCCESS: MSI installed successfully
    echo.
    echo Checking installed files...
    if exist "%INSTALL_DIR%\kamiwaza_installer.exe" (
        echo SUCCESS: kamiwaza_installer.exe found in install directory
    ) else (
        echo ERROR: kamiwaza_installer.exe NOT found in install directory
    )
    
    echo.
    echo Checking Start Menu shortcuts...
    if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Kamiwaza" (
        echo SUCCESS: Start Menu shortcuts created
    ) else (
        echo ERROR: Start Menu shortcuts NOT found
    )
) else (
    echo ERROR: MSI installation failed with exit code %ERRORLEVEL%
)

echo.
echo Check %LOG_FILE% for detailed installation log
echo.