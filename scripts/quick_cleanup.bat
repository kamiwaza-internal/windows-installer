@echo off
echo ===============================================
echo Kamiwaza Quick Cleanup
echo ===============================================
echo This will quickly remove common installation traces
echo.

REM Try uninstalling via local MSI file (most common case)
if exist "installer.msi" (
    echo Attempting quick uninstall via installer.msi...
    msiexec /x "installer.msi" /quiet /norestart
    if %errorlevel% EQU 0 (
        echo [SUCCESS] Uninstalled via installer.msi
    ) else (
        echo [WARNING] Quick uninstall failed, may need full cleanup
    )
) else (
    echo [INFO] No installer.msi found in current directory
)

echo.
echo Cleaning common temporary files...
del /f /q "%TEMP%\*.msi" 2>nul
del /f /q "%TEMP%\kamiwaza*" 2>nul

echo.
echo Removing common shortcuts...
del /f /q "%Public%\Desktop\Kamiwaza*" 2>nul
del /f /q "%UserProfile%\Desktop\Kamiwaza*" 2>nul

echo.
echo ===============================================
echo QUICK CLEANUP COMPLETE
echo ===============================================
echo If this didn't fully clean the installation,
echo run cleanup_installs.bat (as Administrator) for
echo comprehensive cleanup including registry and cache.
echo ===============================================

pause 