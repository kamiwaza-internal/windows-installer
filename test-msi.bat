@echo off
echo ===============================================
echo Kamiwaza MSI Test Runner
echo ===============================================
echo.
echo This script provides multiple test modes for the Kamiwaza MSI:
echo.
echo 1. Mock DEB test (creates fake DEB file)
echo 2. Test URL (uses custom test DEB URL)
echo 3. Standard test (uses current config)
echo.

:menu
echo Please select test mode:
echo [1] Mock DEB test (recommended for safe testing)
echo [2] Test with custom URL
echo [3] Standard test with current config
echo [4] Just build test MSI without running
echo [Q] Quit
echo.
set /p choice="Enter choice (1-4, Q): "

if /i "%choice%"=="1" goto :mock_test
if /i "%choice%"=="2" goto :url_test
if /i "%choice%"=="3" goto :standard_test
if /i "%choice%"=="4" goto :build_only
if /i "%choice%"=="q" goto :quit
echo Invalid choice. Please try again.
echo.
goto :menu

:mock_test
echo.
echo ===============================================
echo MOCK DEB TEST MODE
echo ===============================================
echo This will create an MSI that generates fake DEB files
echo for testing the installation flow safely.
echo.
pause
call build-test.bat --mock
if exist kamiwaza_installer_TEST.msi (
    echo.
    echo Would you like to install and test the MSI now? (y/n)
    set /p install_choice="Install MSI: "
    if /i "!install_choice!"=="y" (
        echo Installing test MSI...
        start /wait msiexec /i kamiwaza_installer_TEST.msi /l*v msi_install_test.log
        echo.
        echo MSI installation completed. Check msi_install_test.log for details.
        echo Use the "Install Kamiwaza" shortcut from Start Menu to test.
    )
)
goto :end

:url_test
echo.
echo ===============================================
echo CUSTOM URL TEST MODE
echo ===============================================
echo Enter a test DEB URL (or press Enter for default test URL):
set /p test_url="Test URL: "
if "%test_url%"=="" set test_url=https://httpbin.org/robots.txt
echo Using test URL: %test_url%
echo.
pause
call build-test.bat --test-url "%test_url%"
if exist kamiwaza_installer_TEST.msi (
    echo.
    echo Would you like to install and test the MSI now? (y/n)
    set /p install_choice="Install MSI: "
    if /i "!install_choice!"=="y" (
        echo Installing test MSI...
        start /wait msiexec /i kamiwaza_installer_TEST.msi /l*v msi_install_test.log
        echo.
        echo MSI installation completed. Check msi_install_test.log for details.
        echo Use the "Install Kamiwaza" shortcut from Start Menu to test.
    )
)
goto :end

:standard_test
echo.
echo ===============================================
echo STANDARD TEST MODE
echo ===============================================
echo This will use the current config.yaml DEB URL
echo.
pause
call build.bat --no-upload
if exist kamiwaza_installer.msi (
    if exist kamiwaza_installer_STANDARD_TEST.msi del kamiwaza_installer_STANDARD_TEST.msi
    move kamiwaza_installer.msi kamiwaza_installer_STANDARD_TEST.msi >nul
    echo Created: kamiwaza_installer_STANDARD_TEST.msi
    echo.
    echo Would you like to install and test the MSI now? (y/n)
    set /p install_choice="Install MSI: "
    if /i "!install_choice!"=="y" (
        echo Installing standard test MSI...
        start /wait msiexec /i kamiwaza_installer_STANDARD_TEST.msi /l*v msi_install_standard_test.log
        echo.
        echo MSI installation completed. Check msi_install_standard_test.log for details.
        echo Use the "Install Kamiwaza" shortcut from Start Menu to test.
    )
)
goto :end

:build_only
echo.
echo ===============================================
echo BUILD ONLY MODE
echo ===============================================
echo Select build type:
echo [1] Mock DEB MSI
echo [2] Custom URL MSI  
echo [3] Standard MSI
echo.
set /p build_choice="Build choice (1-3): "

if "%build_choice%"=="1" (
    call build-test.bat --mock
    echo Mock DEB MSI created: kamiwaza_installer_TEST.msi
)
if "%build_choice%"=="2" (
    set /p test_url="Enter test URL: "
    if "!test_url!"=="" set test_url=https://httpbin.org/robots.txt
    call build-test.bat --test-url "!test_url!"
    echo Custom URL MSI created: kamiwaza_installer_TEST.msi
)
if "%build_choice%"=="3" (
    call build.bat --no-upload
    if exist kamiwaza_installer.msi (
        move kamiwaza_installer.msi kamiwaza_installer_STANDARD.msi >nul
        echo Standard MSI created: kamiwaza_installer_STANDARD.msi
    )
)
goto :end

:quit
echo Exiting...
exit /b 0

:end
echo.
echo ===============================================
echo TEST COMPLETED
echo ===============================================
echo.
echo Available test MSI files:
if exist kamiwaza_installer_TEST.msi echo - kamiwaza_installer_TEST.msi (Mock/Custom URL test)
if exist kamiwaza_installer_STANDARD_TEST.msi echo - kamiwaza_installer_STANDARD_TEST.msi (Standard test)
if exist kamiwaza_installer_STANDARD.msi echo - kamiwaza_installer_STANDARD.msi (Standard build)
echo.
echo Log files:
if exist msi_install_test.log echo - msi_install_test.log (Test MSI install log)
if exist msi_install_standard_test.log echo - msi_install_standard_test.log (Standard test install log)
echo.
echo To clean up test files, delete the MSI and log files above.
echo.
pause