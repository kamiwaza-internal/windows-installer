@echo off
echo Building Kamiwaza Simple Windows Installer...
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

REM Run the simple build script
python build_simple_installer.py

REM Check if build was successful
if exist "Kamiwaza_Installer.zip" (
    echo.
    echo Build completed successfully!
    echo Installer package: Kamiwaza_Installer.zip
    echo.
    echo To install: Extract the zip and run install.bat as administrator
) else (
    echo.
    echo Build failed! Please check the error messages above.
)

pause 