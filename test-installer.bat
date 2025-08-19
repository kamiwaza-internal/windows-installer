@echo off
echo ========================================
echo Kamiwaza Installer Validation Tests
echo ========================================
echo.
echo This will test the installer configuration without running anything.
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not available. Please install Python and try again.
    pause
    exit /b 1
)

echo Python found. Running installer validation tests...
echo.

REM Run the simple test runner
python test_installer_simple_fixed.py

echo.
echo ========================================
echo Test execution completed.
echo ========================================
echo.
echo Check the output above for test results.
echo.
pause 