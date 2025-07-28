@echo off
echo Testing embedded Python execution...

REM Test direct Python execution
echo [TEST 1] Direct Python execution:
embedded_python\python.exe -c "print('Python works!')"
if errorlevel 1 (
    echo [FAIL] Python execution failed
    pause
    exit /b 1
) else (
    echo [PASS] Python execution successful
)

REM Test script execution  
echo [TEST 2] Script execution:
embedded_python\python.exe kamiwaza_headless_installer.py --help
if errorlevel 1 (
    echo [FAIL] Script execution failed
    pause
    exit /b 1
) else (
    echo [PASS] Script execution successful
)

REM Test with actual arguments (dry run)
echo [TEST 3] Full argument test:
embedded_python\python.exe kamiwaza_headless_installer.py --memory "8GB" --email "test@example.com" --license-key "test123" --usage-reporting "1" --mode "lite" 2>&1 | findstr /C:"Starting Kamiwaza installation"
if errorlevel 1 (
    echo [FAIL] Full execution test failed
) else (
    echo [PASS] Full execution test successful
)

echo.
echo All tests completed. If all passed, the CustomAction should work.
pause