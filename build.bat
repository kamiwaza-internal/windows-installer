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

REM Check for --no-upload flag
set SKIP_UPLOAD=0
if "%1"=="--no-upload" (
    set SKIP_UPLOAD=1
    echo [INFO] Upload to AWS will be skipped
)

echo ===============================================
echo Kamiwaza Build Script
echo ===============================================

REM Hardcode values to bypass parsing issues
echo [INFO] Using hardcoded config values...
set KAMIWAZA_VERSION=0.5.0-rc1
set CODENAME=noble
set BUILD_NUMBER=104
set ARCH=amd64
set R2_ENDPOINT_URL=https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com
set DEB_FILE_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_v0.5.0_noble_amd64_build12.deb

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
if "%SKIP_UPLOAD%"=="1" (
    echo [INFO] Skipping build check: --no-upload flag specified
) else if not "%R2_ENDPOINT_URL%"=="" (
    echo [INFO] Checking for existing builds on AWS...
    for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File aws_wrapper.ps1 -Operation "find-build" -Version "%KAMIWAZA_VERSION%" -Arch "%ARCH%" -StartBuild %BUILD_NUMBER% -EndpointUrl "%R2_ENDPOINT_URL%"') do (
        if "%%A"=="FINAL_BUILD_NUMBER" set FINAL_BUILD_NUMBER=%%B
    )
) else (
    echo [WARN] Skipping build check: R2_ENDPOINT_URL not configured
)

set /a NEXT_BUILD=!FINAL_BUILD_NUMBER!+1
REM Update config.yaml with next build number for future (move this up)
echo [INFO] Updating config.yaml for next build: !NEXT_BUILD!
powershell -Command "(Get-Content config.yaml) -replace 'build_number: [0-9]+', 'build_number: !NEXT_BUILD!' | Set-Content config.yaml"
if errorlevel 1 (
    echo [ERROR] Failed to update config.yaml
) else (
    echo [SUCCESS] Config.yaml updated successfully
)

echo [INFO] Final config: Version=%KAMIWAZA_VERSION%, Build=!FINAL_BUILD_NUMBER!, Arch=%ARCH%
echo [INFO] DEB File URL: %DEB_FILE_URL%
echo.

REM Create a working copy and inject DEB_FILE_URL into template
echo [INFO] Creating working copy and injecting DEB_FILE_URL...
copy windows_installer.py windows_installer_template.py.backup >nul
powershell -Command "(Get-Content windows_installer.py) -replace '{{DEB_FILE_URL}}', '%DEB_FILE_URL%' | Set-Content windows_installer_build.py"
if errorlevel 1 (
    echo [ERROR] Failed to inject DEB_FILE_URL into working copy
    pause
    exit /b 1
) else (
    echo [SUCCESS] DEB_FILE_URL injected into working copy
)





REM Initialize signing for MSI only
set SKIP_SIGNING=0

REM Create self-signed certificate if it doesn't exist
if not exist "kamiwaza_cert.pfx" (
    echo [INFO] Creating self-signed certificate...
    powershell -Command "& { $cert = New-SelfSignedCertificate -DnsName 'Kamiwaza' -CertStoreLocation 'Cert:\CurrentUser\My' -Type CodeSigning -Subject 'CN=Kamiwaza Installer'; $password = ConvertTo-SecureString -String 'kamiwaza123' -Force -AsPlainText; Export-PfxCertificate -Cert $cert -FilePath 'kamiwaza_cert.pfx' -Password $password; Write-Output 'Certificate created: kamiwaza_cert.pfx' }"
    if errorlevel 1 (
        echo [WARN] Failed to create certificate - signing will be skipped
        set SKIP_SIGNING=1
    ) else (
        echo [SUCCESS] Self-signed certificate created
        set SKIP_SIGNING=0
    )
) else (
    echo [INFO] Using existing certificate: kamiwaza_cert.pfx
    set SKIP_SIGNING=0
)

REM Parse version components for WiX
for /f "tokens=1,2,3 delims=.-" %%a in ("%KAMIWAZA_VERSION%") do (
    set VERSION_MAJOR=%%a
    set VERSION_MINOR=%%b
    set VERSION_PATCH=%%c
)

REM Build WiX installer
echo [INFO] Building MSI installer...
echo [INFO] Version components: Major=%VERSION_MAJOR%, Minor=%VERSION_MINOR%, Patch=%VERSION_PATCH%
candle -dKAMIWAZA_VERSION=%KAMIWAZA_VERSION% -dKAMIWAZA_VERSION_MAJOR=%VERSION_MAJOR% -dKAMIWAZA_VERSION_MINOR=%VERSION_MINOR% -dKAMIWAZA_VERSION_PATCH=%VERSION_PATCH% -dCODENAME=%CODENAME% -dBUILD_NUMBER=!FINAL_BUILD_NUMBER! -dARCH=%ARCH% -dDEB_FILE_URL="%DEB_FILE_URL%" -dEmbeddedPythonPath=embedded_python installer.wxs python_components.wxs
if errorlevel 1 (
    echo [ERROR] WiX compile failed! Check the output above for details.
    del windows_installer_build.py 2>nul
    pause
    exit /b 1
) else (
    echo [SUCCESS] WiX compilation completed
)

light -ext WixUIExtension -sval -out kamiwaza_installer.msi installer.wixobj python_components.wixobj
if errorlevel 1 (
    echo [ERROR] WiX link failed! Check the output above for details.
    del windows_installer_build.py 2>nul
    pause
    exit /b 1
) else (
    echo [SUCCESS] MSI installer built successfully
)

REM Sign MSI using PowerShell script
if not "%SKIP_SIGNING%"=="1" (
    echo [INFO] Signing executables...
    powershell -ExecutionPolicy Bypass -File "sign_files.ps1" -MSIPath "kamiwaza_installer.msi"
    if errorlevel 1 (
        echo [WARN] Failed to sign files - continuing anyway
    ) else (
        echo [SUCCESS] Files signed successfully
        echo [INFO] To trust the self-signed certificate on target machines, run:
        echo [INFO]   certutil -p "kamiwaza123" -importpfx "TrustedPublisher" "kamiwaza_cert.pfx"
    )
) else (
    echo [INFO] Skipping code signing
)

echo.
echo ===============================================
echo BUILD COMPLETED SUCCESSFULLY
echo ===============================================
echo MSI: kamiwaza_installer.msi
echo.

REM Set MSI file name (will be updated by PowerShell wrapper)
set MSI_NAME=kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%FINAL_BUILD_NUMBER%.msi

REM Upload files using PowerShell wrapper
if "%SKIP_UPLOAD%"=="1" (
    echo [INFO] Skipping upload: --no-upload flag specified
    goto :end
)
if "%R2_ENDPOINT_URL%"=="" (
    echo [WARN] Skipping upload: R2_ENDPOINT_URL not configured
    goto :end
)

echo [INFO] Uploading files to AWS...
for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File aws_wrapper.ps1 -Operation "upload" -Version "%KAMIWAZA_VERSION%" -Arch "%ARCH%" -StartBuild %FINAL_BUILD_NUMBER% -EndpointUrl "%R2_ENDPOINT_URL%"') do (
    echo [DEBUG] Parsing output: %%A=%%B
    if "%%A"=="MSI_SUCCESS" (
        if "%%B"=="True" (
            set MSI_SUCCESS=1
            echo [SUCCESS] MSI uploaded successfully
        ) else (
            set MSI_SUCCESS=0
            echo [ERROR] MSI upload failed!
        )
    )
    if "%%A"=="MSI_NAME" (
        set MSI_NAME=%%B
        echo [DEBUG] MSI_NAME set to: %%B
    )
)

REM Only show URL if upload was successful
if "%MSI_SUCCESS%"=="1" (
    echo.
    echo ===============================================
    echo LATEST BUILD URL
    echo ===============================================
    echo [DEBUG] MSI_NAME variable: !MSI_NAME!
    set MSI_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/!MSI_NAME!
    echo [DEBUG] MSI_URL constructed: !MSI_URL!
    echo [SUCCESS] MSI: !MSI_URL!
    echo ===============================================
    echo.
    echo [INFO] Copy this URL for reference:
    echo        MSI: !MSI_URL!
    echo ===============================================
) else (
    echo.
    echo ===============================================
    echo UPLOAD STATUS
    echo ===============================================
    echo [INFO] MSI file created locally: kamiwaza_installer.msi
    echo [INFO] Upload was not successful - no public URL available
    echo ===============================================
)

:end

echo.
REM Clean up working copy
echo [INFO] Cleaning up working copy...
del windows_installer_build.py 2>nul
echo [SUCCESS] Working copy cleaned up

echo [INFO] Build complete! Config updated for next build (!NEXT_BUILD!)
