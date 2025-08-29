@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PYTHON_EXE=%SCRIPT_DIR%python\python.exe
set INSTALLER_SCRIPT=%SCRIPT_DIR%kamiwaza_headless_installer.py

if exist "%SCRIPT_DIR%embedded_python\python.exe" (
    set PYTHON_EXE=%SCRIPT_DIR%embedded_python\python.exe
)

"%PYTHON_EXE%" "%INSTALLER_SCRIPT%" %*
exit /b %ERRORLEVEL%