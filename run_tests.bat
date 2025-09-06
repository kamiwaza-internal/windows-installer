@echo off
REM Kamiwaza Installer Test Runner
REM Interactive test runner for development and debugging

echo ==========================================
echo KAMIWAZA INSTALLER TEST RUNNER
echo ==========================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python is not available. Cannot run tests.
    echo Please install Python 3.8+ and try again.
    pause
    exit /b 1
)

echo Python found: 
python --version
echo.

REM Check if we're in a virtual environment
if defined VIRTUAL_ENV (
    echo Virtual environment active: %VIRTUAL_ENV%
) else (
    echo WARNING: No virtual environment detected
    echo Recommend activating venv: venv\Scripts\activate
)
echo.

REM Install test dependencies if needed
echo Checking test dependencies...
python -c "import pytest" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installing test dependencies...
    python -m pip install -r tests\requirements.txt
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to install test dependencies
        pause
        exit /b 1
    )
    echo Test dependencies installed successfully
) else (
    echo Test dependencies already available
)
echo.

REM Validate test suite health first
echo Validating test suite health...
python tests\validate_test_suite.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Test suite validation failed
    echo Please fix test suite issues before running tests
    echo.
    pause
    exit /b 1
)
echo Test suite validation passed!
echo.

REM Show test options
echo ==========================================
echo TEST OPTIONS:
echo ==========================================
echo 1. Run all tests (full suite)
echo 2. Run quick tests only (skip slow tests)
echo 3. Run specific test file
echo 4. Run tests with verbose output
echo 5. Run tests and generate coverage report
echo 6. Exit
echo.

set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" (
    echo.
    echo Running full test suite...
    python -m pytest tests\ -v
) else if "%choice%"=="2" (
    echo.
    echo Running quick tests only...
    python -m pytest tests\ -v -m "not slow"
) else if "%choice%"=="3" (
    echo.
    echo Available test files:
    dir /b tests\test_*.py
    echo.
    set /p testfile="Enter test file name (e.g., test_installer.py): "
    echo Running tests\%testfile%...
    python -m pytest tests\%testfile% -v
) else if "%choice%"=="4" (
    echo.
    echo Running tests with verbose output...
    python -m pytest tests\ -v -s
) else if "%choice%"=="5" (
    echo.
    echo Running tests with coverage report...
    python -m pytest tests\ --cov=. --cov-report=html --cov-report=term
) else if "%choice%"=="6" (
    echo Exiting...
    exit /b 0
) else (
    echo Invalid choice. Running default test suite...
    python -m pytest tests\ -v
)

set test_exit_code=%ERRORLEVEL%

echo.
echo ==========================================
if %test_exit_code% EQU 0 (
    echo ✓ ALL TESTS PASSED!
    echo Installer configuration is valid.
) else (
    echo ✗ SOME TESTS FAILED!
    echo Review the output above and fix any issues.
)
echo ==========================================
echo.

echo Press any key to exit...
pause >nul
exit /b %test_exit_code%
