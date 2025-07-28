@echo off
REM Batch wrapper to run Kamiwaza installer with embedded Python
REM This ensures the CustomAction works without requiring Python in PATH

setlocal
set SCRIPT_DIR=%~dp0
set PYTHON_EXE=%SCRIPT_DIR%python\python.exe
set INSTALLER_SCRIPT=%SCRIPT_DIR%kamiwaza_headless_installer.py

REM For testing, use embedded_python directory
if exist "%SCRIPT_DIR%embedded_python\python.exe" (
    set PYTHON_EXE=%SCRIPT_DIR%embedded_python\python.exe
)

REM Log execution attempt
echo [INFO] Starting Kamiwaza installation via batch wrapper
echo [INFO] Python: %PYTHON_EXE%
echo [INFO] Script: %INSTALLER_SCRIPT%
echo [INFO] Arguments: %*

REM Check if Python executable exists
if not exist "%PYTHON_EXE%" (
    echo [ERROR] Python executable not found at: %PYTHON_EXE%
    exit /b 1
)

REM Check if installer script exists
if not exist "%INSTALLER_SCRIPT%" (
    echo [ERROR] Installer script not found at: %INSTALLER_SCRIPT%
    exit /b 1
)

REM Execute with all passed arguments
echo [INFO] Executing installer...
"%PYTHON_EXE%" "%INSTALLER_SCRIPT%" %*
set EXIT_CODE=%ERRORLEVEL%

echo [INFO] Installer completed with exit code: %EXIT_CODE%
exit /b %EXIT_CODE%