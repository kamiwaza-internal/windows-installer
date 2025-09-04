@echo off
REM Build and Install Kamiwaza GUI Manager
REM This script builds the GUI executable and prepares it for MSI installation

echo ========================================
echo Kamiwaza GUI Manager Build Process
echo ========================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not available in PATH
    echo Please install Python 3.8+ and try again
    pause
    exit /b 1
)

REM Check if required files exist
if not exist "kamiwaza_gui_manager.py" (
    echo ERROR: kamiwaza_gui_manager.py not found!
    echo Please run this script from the project directory
    pause
    exit /b 1
)

if not exist "kamiwaza.ico" (
    echo WARNING: kamiwaza.ico not found - GUI will use default icon
)

echo Building GUI executable...
python build_gui_exe.py

if errorlevel 1 (
    echo.
    echo ERROR: GUI build failed!
    echo Please check the error messages above
    pause
    exit /b 1
)

echo.
echo ========================================
echo GUI Build Completed Successfully!
echo ========================================
echo.

REM Check if executable was created
if exist "dist\KamiwazaGUIManager.exe" (
    echo Executable created: dist\KamiwazaGUIManager.exe
    
    REM Copy to current directory for MSI installer
    copy "dist\KamiwazaGUIManager.exe" "KamiwazaGUIManager.exe" >nul
    echo Copied to current directory for MSI installer
    
    REM Show file size
    for %%A in ("KamiwazaGUIManager.exe") do (
        echo File size: %%~zA bytes
    )
    
    echo.
    echo Next steps:
    echo 1. The executable is ready for MSI installation
    echo 2. installer.wxs has been updated to include the GUI
    echo 3. Build your MSI installer
    echo 4. Test the installation
    echo.
    echo The GUI will be installed to:
    echo - %LOCALAPPDATA%\Kamiwaza\GUI\KamiwazaGUIManager.exe
    echo - Start Menu: Start ^> Kamiwaza ^> Kamiwaza Monitor
    echo.
    
) else (
    echo ERROR: Executable not found after build!
    pause
    exit /b 1
)

echo Build process completed successfully!
echo.
pause 