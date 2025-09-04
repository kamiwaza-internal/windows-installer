@echo off
setlocal enabledelayedexpansion

REM Check if MSI file argument is provided
if "%1"=="" (
    echo [ERROR] Please provide an MSI file path as an argument
    echo Usage: %0 "path\to\your\installer.msi"
    echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
)

REM Validate that the MSI file exists
if not exist "%1" (
    echo [ERROR] MSI file not found: %1
    echo Please check the file path and try again.
    echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
)

REM Get the full path of the MSI file
set MSI_FILE=%1
echo ===============================================
echo Kamiwaza MSI Upload Script
echo ===============================================
echo [INFO] MSI File: %MSI_FILE%

REM Read R2 endpoint URL from config.yaml
echo [INFO] Reading upload configuration from config.yaml...
for /f "tokens=1,2 delims==" %%A in ('powershell -Command "Get-Content ..\config.yaml | Where-Object { $_ -match '^[^#]' -and $_ -match ':' } | ForEach-Object { $line = $_.Trim(); if ($line -match '^([^:]+):\s*(.+?)(?:\s+#|$)') { $matches[1].Trim() + '=' + $matches[2].Trim() } else { $line -replace ':\s*', '=' } }"') do (
    if "%%A"=="r2_endpoint_url" set R2_ENDPOINT_URL=%%B
)

REM Clean up variables
set R2_ENDPOINT_URL=%R2_ENDPOINT_URL: =%

if "%R2_ENDPOINT_URL%"=="" (
    echo [ERROR] r2_endpoint_url not found in config.yaml
    echo Please configure the R2 endpoint URL in config.yaml
echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
)

echo [INFO] R2 Endpoint: %R2_ENDPOINT_URL%
echo.

REM Copy the MSI file to a standard name for upload
echo [INFO] Preparing MSI file for upload...
set UPLOAD_MSI_NAME=kamiwaza_installer.msi
copy "%MSI_FILE%" "%UPLOAD_MSI_NAME%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy MSI file for upload
    echo.
    echo [DEBUG] Script completed. Press any key to close...
    pause >nul
    exit /b 1
) else (
    echo [SUCCESS] MSI file prepared for upload
)

echo [INFO] Uploading MSI to AWS...

REM Upload the MSI as a generic file (no versioning, just upload to /win/)
REM Try the regular AWS wrapper first
set UPLOAD_SUCCESS=0
for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File ..\aws_wrapper.ps1 -Operation "upload-generic" -EndpointUrl "%R2_ENDPOINT_URL%" 2^>nul') do (
    echo [DEBUG] Parsing output: %%A=%%B
    if "%%A"=="GENERIC_MSI_SUCCESS" (
        if "%%B"=="True" (
            set GENERIC_MSI_SUCCESS=1
            set UPLOAD_SUCCESS=1
            echo [SUCCESS] Generic MSI uploaded successfully
        ) else (
            set GENERIC_MSI_SUCCESS=0
        )
    )
    if "%%A"=="GENERIC_MSI_NAME" (
        set GENERIC_MSI_NAME=%%B
        echo [DEBUG] GENERIC_MSI_NAME set to: %%B
    )
)

REM If regular upload failed, try the fallback wrapper
if "%UPLOAD_SUCCESS%"=="0" (
    echo [WARN] Regular upload failed, trying fallback method...
    for /f "tokens=1,2 delims==" %%A in ('powershell -ExecutionPolicy Bypass -File ..\aws_wrapper_fallback.ps1 -Operation "upload-generic" -EndpointUrl "%R2_ENDPOINT_URL%"') do (
        echo [DEBUG] Fallback parsing output: %%A=%%B
        if "%%A"=="GENERIC_MSI_SUCCESS" (
            if "%%B"=="True" (
                set GENERIC_MSI_SUCCESS=1
                set UPLOAD_SUCCESS=1
                echo [SUCCESS] Generic MSI uploaded successfully via fallback method
            ) else (
                set GENERIC_MSI_SUCCESS=0
                echo [ERROR] Generic MSI upload failed even with fallback method!
            )
        )
        if "%%A"=="GENERIC_MSI_NAME" (
            set GENERIC_MSI_NAME=%%B
            echo [DEBUG] GENERIC_MSI_NAME set to: %%B
        )
    )
)

REM Show results
    echo.
    echo ===============================================
echo UPLOAD RESULTS
    echo ===============================================
    
if "%UPLOAD_SUCCESS%"=="1" (
    if not "%GENERIC_MSI_NAME%"=="" (
        set GENERIC_MSI_URL=https://packages.kamiwaza.ai/win/!GENERIC_MSI_NAME!
        echo [SUCCESS] MSI uploaded successfully!
        echo [SUCCESS] Generic MSI URL: !GENERIC_MSI_URL!
        echo.
        echo [INFO] Copy this URL for distribution:
        echo        !GENERIC_MSI_URL!
    ) else (
        echo [SUCCESS] MSI uploaded successfully!
        echo [INFO] Generic MSI available at: https://packages.kamiwaza.ai/win/kamiwaza_installer.msi
    )
) else (
    echo [ERROR] Upload failed!
    echo [INFO] MSI file is available locally: %UPLOAD_MSI_NAME%
    echo [INFO] Please check your AWS configuration and try again.
)

echo ===============================================

REM Clean up the copied MSI file
echo.
echo [INFO] Cleaning up temporary files...
if exist "%UPLOAD_MSI_NAME%" (
    del "%UPLOAD_MSI_NAME%" 2>nul
    echo [SUCCESS] Temporary MSI file cleaned up
)

echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul