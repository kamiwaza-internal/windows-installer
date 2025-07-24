@echo off
setlocal enabledelayedexpansion

REM Check for --clean flag
if "%1"=="--clean" (
    echo Cleaning up log files...
    del /q *.log 2>nul
    del /q build_*.log 2>nul
    echo Log files cleaned up.
    exit /b 0
)

echo ===============================================
echo Kamiwaza Build Script
echo ===============================================

REM Parse config.yaml 
echo [INFO] Parsing config.yaml...
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^kamiwaza_version:" config.yaml') do set KAMIWAZA_VERSION=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^codename:" config.yaml') do set CODENAME=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^build_number:" config.yaml') do set BUILD_NUMBER=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^arch:" config.yaml') do set ARCH=%%B
for /f "tokens=1* delims=: " %%A in ('findstr /r /c:"^r2_endpoint_url:" config.yaml') do set R2_ENDPOINT_URL=%%B
for /f "tokens=1* delims=: " %%A in ('findstr /r /c:"^deb_file_url:" config.yaml') do set DEB_FILE_URL=%%B

REM Clean up variables
set KAMIWAZA_VERSION=%KAMIWAZA_VERSION: =%
set CODENAME=%CODENAME: =%
set BUILD_NUMBER=%BUILD_NUMBER: =%
set ARCH=%ARCH: =%
set R2_ENDPOINT_URL=%R2_ENDPOINT_URL: =%
set DEB_FILE_URL=%DEB_FILE_URL: =%

echo [INFO] Initial config: Version=%KAMIWAZA_VERSION%, Build=%BUILD_NUMBER%, Arch=%ARCH%
echo [INFO] R2 Endpoint: %R2_ENDPOINT_URL%

REM Auto-detect next available build number using PowerShell wrapper
set FINAL_BUILD_NUMBER=%BUILD_NUMBER%
if not "%R2_ENDPOINT_URL%"=="" (
    echo [INFO] Checking for existing builds on AWS...
    for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File aws_wrapper.ps1 -Operation "find-build" -Version "%KAMIWAZA_VERSION%" -Arch "%ARCH%" -StartBuild %BUILD_NUMBER% -EndpointUrl "%R2_ENDPOINT_URL%"') do (
        if "%%A"=="FINAL_BUILD_NUMBER" set FINAL_BUILD_NUMBER=%%B
    )
) else (
    echo [WARN] Skipping build check: R2_ENDPOINT_URL not configured
)

echo [INFO] Final config: Version=%KAMIWAZA_VERSION%, Build=!FINAL_BUILD_NUMBER!, Arch=%ARCH%
echo.

REM Generate application icon
echo [INFO] Generating application icon...
python create_icon.py
if errorlevel 1 (
    echo [ERROR] Icon generation failed! Check if Pillow is installed.
    pause
    exit /b 1
) else (
    echo [SUCCESS] Application icon generated successfully
)

REM Build Python executable
echo [INFO] Building Python executable...
pyinstaller --onefile --noconsole --hidden-import=yaml --name kamiwaza_installer --icon=kamiwaza.ico windows_installer.py
if errorlevel 1 (
    echo [ERROR] Python build failed! Check the output above for details.
    pause
    exit /b 1
) else (
    echo [SUCCESS] Python executable built successfully
)

REM Build WiX installer
echo [INFO] Building MSI installer...
candle -dKAMIWAZA_VERSION=%KAMIWAZA_VERSION% -dCODENAME=%CODENAME% -dBUILD_NUMBER=!FINAL_BUILD_NUMBER! -dARCH=%ARCH% -dDEB_FILE_URL="%DEB_FILE_URL%" installer.wxs
if errorlevel 1 (
    echo [ERROR] WiX compile failed! Check the output above for details.
    pause
    exit /b 1
) else (
    echo [SUCCESS] WiX compilation completed
)

light -ext WixUIExtension installer.wixobj
if errorlevel 1 (
    echo [ERROR] WiX link failed! Check the output above for details.
    pause
    exit /b 1
) else (
    echo [SUCCESS] MSI installer built successfully
)

echo.
echo ===============================================
echo BUILD COMPLETED SUCCESSFULLY
echo ===============================================
echo EXE: dist\kamiwaza_installer.exe
echo MSI: installer.msi
echo.

REM Set file names (will be updated by PowerShell wrapper)
set EXE_NAME=kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%FINAL_BUILD_NUMBER%.exe
set MSI_NAME=kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%FINAL_BUILD_NUMBER%.msi

REM Upload files using PowerShell wrapper
if "%R2_ENDPOINT_URL%"=="" (
    echo [WARN] Skipping upload: R2_ENDPOINT_URL not configured
    goto :show_urls
)

echo [INFO] Uploading files to AWS...
for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File aws_wrapper.ps1 -Operation "upload" -Version "%KAMIWAZA_VERSION%" -Arch "%ARCH%" -StartBuild %FINAL_BUILD_NUMBER% -EndpointUrl "%R2_ENDPOINT_URL%"') do (
    if "%%A"=="EXE_SUCCESS" (
        if "%%B"=="True" (
            set EXE_SUCCESS=1
            echo [SUCCESS] EXE uploaded successfully
        ) else (
            set EXE_SUCCESS=0
            echo [ERROR] EXE upload failed!
        )
    )
    if "%%A"=="MSI_SUCCESS" (
        if "%%B"=="True" (
            set MSI_SUCCESS=1
            echo [SUCCESS] MSI uploaded successfully
        ) else (
            set MSI_SUCCESS=0
            echo [ERROR] MSI upload failed!
        )
    )
    if "%%A"=="EXE_NAME" set EXE_NAME=%%B
    if "%%A"=="MSI_NAME" set MSI_NAME=%%B
)

:show_urls
echo.
echo ===============================================
echo LATEST BUILD URLS
echo ===============================================
set EXE_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/%EXE_NAME%
set MSI_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/%MSI_NAME%

if "%EXE_SUCCESS%"=="1" (
    echo [SUCCESS] EXE: %EXE_URL%
) else (
    echo [FAILED]  EXE: %EXE_URL%
    echo          ^-- Upload failed, but this is where the file would be
)
if "%MSI_SUCCESS%"=="1" (
    echo [SUCCESS] MSI: %MSI_URL%
) else (
    echo [FAILED]  MSI: %MSI_URL%
    echo          ^-- Upload failed, but this is where the file would be
)
echo ===============================================
echo.
echo [INFO] Copy these URLs for reference:
echo        EXE: %EXE_URL%
echo        MSI: %MSI_URL%
echo ===============================================

REM Update config.yaml with next build number for future
set /a NEXT_BUILD=!FINAL_BUILD_NUMBER!+1
echo [INFO] Updating config.yaml for next build: !NEXT_BUILD!
powershell -Command "(Get-Content config.yaml) -replace '^build_number: !FINAL_BUILD_NUMBER!', 'build_number: !NEXT_BUILD!' | Set-Content config.yaml"
if errorlevel 1 (
    echo [ERROR] Failed to update config.yaml
) else (
    echo [SUCCESS] Config.yaml updated successfully
)

echo.
echo [INFO] Build complete! Config updated for next build (!NEXT_BUILD!)
pause 