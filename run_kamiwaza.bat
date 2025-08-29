@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PYTHON_EXE=%SCRIPT_DIR%python\python.exe
set INSTALLER_SCRIPT=%SCRIPT_DIR%kamiwaza_headless_installer.py

if exist "%SCRIPT_DIR%embedded_python\python.exe" (
    set PYTHON_EXE=%SCRIPT_DIR%embedded_python\python.exe
)

"%PYTHON_EXE%" "%INSTALLER_SCRIPT%" %*
set EXITCODE=%ERRORLEVEL%

REM Treat reboot-required (3010) as success from MSI's perspective
if %EXITCODE% EQU 3010 exit /b 0
exit /b %EXITCODE%