@echo off
echo ===============================================
echo Kamiwaza Standard Test Runner
echo ===============================================
echo.
echo This will test the Kamiwaza installer with standard parameters:
echo   Email: drew@kamiwaza.ai
echo   Mode: lite
echo   Memory: 20GB
echo.

echo.
echo [INFO] Creating testable installer...
python create_test_installer.py
if errorlevel 1 (
    echo [ERROR] Failed to create test installer
    pause
    exit /b 1
)

echo.
echo [INFO] Running standard test...
echo [INFO] Command: python kamiwaza_headless_installer_test.py --memory 20GB --email drew@kamiwaza.ai --mode lite
echo.

python kamiwaza_headless_installer_test.py --memory 20GB --email drew@kamiwaza.ai --mode lite

echo.
echo ===============================================
echo Test completed!
echo ===============================================
echo.
echo To clean up the test installer file, run:
echo   del kamiwaza_headless_installer_test.py
echo.
pause 