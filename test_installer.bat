@echo off
echo === Kamiwaza Installer Test Mode ===
echo.
echo This will test the installer without actually installing the .deb package
echo Memory will be set to 16GB to test WSL configuration
echo.
pause

echo Starting installer in test mode...
python windows_installer.py --test --memory 16GB --debug

echo.
echo Test completed. Check the log output above.
pause 