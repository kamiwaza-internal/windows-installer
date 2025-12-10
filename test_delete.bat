@echo off
echo ===============================================
echo Testing Delete Functionality
echo ===============================================

echo [INFO] Testing delete functionality with version 0.5.0 and x86_64 architecture
echo [INFO] This will attempt to delete any existing installers for this version/arch
echo.

REM Test the delete functionality
call delete_installer.bat 0.5.0 x86_64

echo.
echo [INFO] Test completed. Check the output above for results.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
