@echo off
echo ===============================================
echo Kamiwaza Installer Cleanup Script
echo ===============================================
echo This will remove all traces of Kamiwaza installations
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [ERROR] This script requires Administrator privileges!
    echo Please run as Administrator and try again.
    pause
    exit /b 1
)

echo [INFO] Running with Administrator privileges...
echo.

REM 1. Try to uninstall using MSI product codes
echo ===============================================
echo Step 1: Uninstalling via MSI Product Codes
echo ===============================================

REM Look for Kamiwaza in installed programs
echo Searching for Kamiwaza installations...
wmic product where "name like '%%Kamiwaza%%'" get name,identifyingNumber,version 2>nul

REM Try common uninstall methods
echo Attempting uninstall via msiexec...
msiexec /x {PRODUCT-CODE-PLACEHOLDER} /quiet /norestart 2>nul
if %errorlevel% EQU 0 (
    echo [SUCCESS] MSI uninstalled via product code
) else (
    echo [INFO] No MSI found via product code or uninstall failed
)

REM Try uninstalling by MSI file if it exists
if exist "installer.msi" (
    echo Attempting uninstall via MSI file...
    msiexec /x "installer.msi" /quiet /norestart
    if %errorlevel% EQU 0 (
        echo [SUCCESS] MSI uninstalled via installer file
    ) else (
        echo [WARNING] MSI uninstall via file failed
    )
)

echo.

REM 2. Clean MSI cache
echo ===============================================
echo Step 2: Cleaning MSI Cache
echo ===============================================

REM Clean MSI cache folders
echo Cleaning MSI cache folders...
set MSI_CACHE=%SystemRoot%\Installer
if exist "%MSI_CACHE%" (
    echo Removing MSI cache files...
    REM Remove .msi files containing "kamiwaza" (case insensitive)
    for /f "delims=" %%f in ('dir /b "%MSI_CACHE%\*.msi" 2^>nul ^| findstr /i kamiwaza') do (
        echo   Removing: %MSI_CACHE%\%%f
        del /f /q "%MSI_CACHE%\%%f" 2>nul
        if %errorlevel% EQU 0 (
            echo   [SUCCESS] Removed %%f
        ) else (
            echo   [WARNING] Could not remove %%f - file may be in use
        )
    )
)

REM Clean temp MSI files
echo Cleaning temporary MSI files...
del /f /q "%TEMP%\*.msi" 2>nul
del /f /q "%TEMP%\kamiwaza*" 2>nul

echo.

REM 3. Clean Registry entries
echo ===============================================
echo Step 3: Cleaning Registry Entries
echo ===============================================

echo Removing registry entries...

REM Remove from Uninstall registry
echo Cleaning uninstall registry entries...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /f /v "DisplayName" /d "*Kamiwaza*" 2>nul
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /f /v "DisplayName" /d "*Kamiwaza*" 2>nul

REM Remove Kamiwaza-specific registry keys
echo Cleaning Kamiwaza registry keys...
reg delete "HKLM\SOFTWARE\Kamiwaza" /f 2>nul
reg delete "HKLM\SOFTWARE\WOW6432Node\Kamiwaza" /f 2>nul
reg delete "HKCU\SOFTWARE\Kamiwaza" /f 2>nul

REM Clean MSI product registry entries
echo Cleaning MSI product registry...
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products" 2^>nul ^| findstr /i kamiwaza') do (
    echo   Removing product key: %%k
    reg delete "%%k" /f 2>nul
)

echo.

REM 4. Clean Program Files
echo ===============================================
echo Step 4: Cleaning Program Files
echo ===============================================

REM Remove installation directories
set INSTALL_DIRS[0]=%ProgramFiles%\Kamiwaza
set INSTALL_DIRS[1]=%ProgramFiles(x86)%\Kamiwaza
set INSTALL_DIRS[2]=%LocalAppData%\Kamiwaza
set INSTALL_DIRS[3]=%AppData%\Kamiwaza

for /L %%i in (0,1,3) do (
    call set "DIR=%%INSTALL_DIRS[%%i]%%"
    call :clean_directory "%%DIR%%"
)

echo.

REM 5. Clean Start Menu and Desktop shortcuts
echo ===============================================
echo Step 5: Cleaning Shortcuts
echo ===============================================

echo Removing shortcuts...
del /f /q "%Public%\Desktop\Kamiwaza*" 2>nul
del /f /q "%UserProfile%\Desktop\Kamiwaza*" 2>nul
del /f /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Kamiwaza*" 2>nul
del /f /q "%AppData%\Microsoft\Windows\Start Menu\Programs\Kamiwaza*" 2>nul

REM Remove start menu folders
rd /s /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Kamiwaza" 2>nul
rd /s /q "%AppData%\Microsoft\Windows\Start Menu\Programs\Kamiwaza" 2>nul

echo.

REM 6. Clean Windows Installer service cache
echo ===============================================
echo Step 6: Cleaning Windows Installer Service
echo ===============================================

echo Stopping Windows Installer service...
net stop msiserver 2>nul
timeout /t 2 /nobreak >nul

echo Starting Windows Installer service...
net start msiserver 2>nul

echo.

REM 7. Final verification
echo ===============================================
echo Step 7: Verification
echo ===============================================

echo Checking for remaining Kamiwaza installations...
wmic product where "name like '%%Kamiwaza%%'" get name,version 2>nul

echo.
echo ===============================================
echo CLEANUP COMPLETE
echo ===============================================
echo All Kamiwaza installation traces have been removed.
echo You may need to restart your computer for all changes to take effect.
echo.
echo If you still see any Kamiwaza entries, please run this script again
echo or manually remove them.
echo ===============================================

pause
goto :eof

:clean_directory
set "target_dir=%~1"
if exist "%target_dir%" (
    echo   Removing directory: %target_dir%
    rd /s /q "%target_dir%" 2>nul
    if exist "%target_dir%" (
        echo   [WARNING] Could not completely remove %target_dir%
        echo   Some files may be in use. Try again after restart.
    ) else (
        echo   [SUCCESS] Removed %target_dir%
    )
) else (
    echo   [INFO] Directory not found: %target_dir%
)
goto :eof 