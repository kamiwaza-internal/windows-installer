@echo off
setlocal enabledelayedexpansion

REM Test mode build script for Kamiwaza installer
REM This creates an MSI with a test DEB URL for testing purposes

echo ===============================================
echo Kamiwaza TEST MODE Build Script
echo ===============================================

REM Check for parameters
set TEST_DEB_URL=
set USE_MOCK_DEB=0

if "%1"=="--mock" (
    set USE_MOCK_DEB=1
    echo [INFO] Using mock DEB mode - installer will create a fake DEB file
)

if "%1"=="--test-url" (
    if "%2"=="" (
        echo [ERROR] --test-url requires a URL parameter
        echo Usage: build-test.bat --test-url https://example.com/test.deb
        exit /b 1
    )
    set TEST_DEB_URL=%2
    echo [INFO] Using custom test DEB URL: %TEST_DEB_URL%
)

if "%USE_MOCK_DEB%"=="0" and "%TEST_DEB_URL%"=="" (
    echo [INFO] No test URL specified, using default test configuration
    set TEST_DEB_URL=https://httpbin.org/robots.txt
)

echo [INFO] Test DEB URL: %TEST_DEB_URL%
echo.

REM Backup the original config
if exist config.yaml (
    copy config.yaml config.yaml.backup >nul
    echo [INFO] Backed up original config.yaml
)

REM Create test configuration
echo [INFO] Creating test configuration...
if "%USE_MOCK_DEB%"=="1" (
    echo kamiwaza_version: 0.5.0-test-mock> test-config-temp.yaml
    echo codename: noble>> test-config-temp.yaml
    echo build_number: 999>> test-config-temp.yaml
    echo arch: amd64>> test-config-temp.yaml
    echo r2_endpoint_url: >> test-config-temp.yaml
    echo deb_file_url: MOCK_DEB_PLACEHOLDER>> test-config-temp.yaml
) else (
    echo kamiwaza_version: 0.5.0-test> test-config-temp.yaml
    echo codename: noble>> test-config-temp.yaml
    echo build_number: 999>> test-config-temp.yaml
    echo arch: amd64>> test-config-temp.yaml
    echo r2_endpoint_url: >> test-config-temp.yaml
    echo deb_file_url: %TEST_DEB_URL%>> test-config-temp.yaml
)

REM Replace the config with test config
move test-config-temp.yaml config.yaml >nul
echo [SUCCESS] Test configuration created

REM Create a test version of the installer that handles mock DEBs
if "%USE_MOCK_DEB%"=="1" (
    echo [INFO] Creating mock DEB test installer...
    python create_mock_test_installer.py
    if errorlevel 1 (
        echo [ERROR] Failed to create mock test installer
        goto :restore_config
    )
)

echo.
echo [INFO] Building TEST MSI installer...
echo [INFO] This will create kamiwaza_installer.msi with test DEB URL

REM Run the regular build process with --no-upload
call build.bat --no-upload

if errorlevel 1 (
    echo [ERROR] Build failed!
    goto :restore_config
)

REM Rename the MSI to indicate it's a test version
if exist kamiwaza_installer.msi (
    if exist kamiwaza_installer_TEST.msi del kamiwaza_installer_TEST.msi
    move kamiwaza_installer.msi kamiwaza_installer_TEST.msi >nul
    echo [SUCCESS] Test MSI created: kamiwaza_installer_TEST.msi
) else (
    echo [ERROR] MSI file not found after build
    goto :restore_config
)

:restore_config
echo.
echo [INFO] Restoring original configuration...
if exist config.yaml.backup (
    move config.yaml.backup config.yaml >nul
    echo [SUCCESS] Original config.yaml restored
) else (
    echo [WARNING] No backup config found
)

echo.
echo ===============================================
echo TEST BUILD COMPLETED
echo ===============================================
if exist kamiwaza_installer_TEST.msi (
    echo [SUCCESS] Test MSI: kamiwaza_installer_TEST.msi
    echo.
    echo TESTING INSTRUCTIONS:
    echo 1. Install the MSI: kamiwaza_installer_TEST.msi
    echo 2. Run the "Install Kamiwaza" shortcut from Start Menu
    echo 3. Monitor the installer output for test DEB download
    if "%USE_MOCK_DEB%"=="1" (
        echo 4. The installer will create a fake DEB file for testing
    ) else (
        echo 4. The installer will attempt to download: %TEST_DEB_URL%
    )
    echo.
    echo CLEANUP:
    echo - Uninstall via Add/Remove Programs
    echo - Or use "Cleanup WSL" shortcut to remove WSL instances
) else (
    echo [ERROR] Test MSI was not created successfully
)
echo ===============================================

pause