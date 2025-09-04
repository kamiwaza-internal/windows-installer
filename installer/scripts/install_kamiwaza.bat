@echo off
setlocal enabledelayedexpansion

echo Kamiwaza Installer - Batch Script (Legacy)

echo This script is now a stub. All .deb download, debconf, and installation logic is handled by windows_installer.py.
echo Only WSL memory configuration is performed here if needed.

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0

REM Default values if not provided by MSI
set MEMORY_CONFIG=14GB
if not "%1"=="" set MEMORY_CONFIG=%1

echo Configuring Kamiwaza dedicated memory (%MEMORY_CONFIG%)...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%configure_wsl_memory.ps1" -MemoryAmount "%MEMORY_CONFIG%"

echo.
echo To install Kamiwaza, run the main installer (kamiwaza_installer.exe) or use the Start Menu shortcut.
echo.

exit /b 0 


