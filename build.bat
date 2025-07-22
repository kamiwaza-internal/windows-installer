@echo off
REM Parse config.yaml and set environment variables
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^kamiwaza_version:" config.yaml') do set KAMIWAZA_VERSION=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^codename:" config.yaml') do set CODENAME=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^build_number:" config.yaml') do set BUILD_NUMBER=%%B
for /f "tokens=1,2 delims=: " %%A in ('findstr /r /c:"^arch:" config.yaml') do set ARCH=%%B
for /f "tokens=1* delims=: " %%A in ('findstr /r /c:"^r2_endpoint_url:" config.yaml') do set R2_ENDPOINT_URL=%%B

REM Remove leading/trailing spaces
set KAMIWAZA_VERSION=%KAMIWAZA_VERSION: =%
set CODENAME=%CODENAME: =%
set BUILD_NUMBER=%BUILD_NUMBER: =%
set ARCH=%ARCH: =%
set R2_ENDPOINT_URL=%R2_ENDPOINT_URL: =%

REM Build the Python executable with version info
pyinstaller --onefile --noconsole --hidden-import=yaml --name kamiwaza_installer windows_installer.py

REM Build the WiX installer, passing version info as preprocessor variables
candle -dKAMIWAZA_VERSION=%KAMIWAZA_VERSION% -dCODENAME=%CODENAME% -dBUILD_NUMBER=%BUILD_NUMBER% -dARCH=%ARCH% installer.wxs
light -ext WixUIExtension installer.wixobj

REM Upload the EXE to R2
set EXE_FILE=dist\kamiwaza_installer.exe
set MSI_FILE=installer.msi
set BASENAME=kamiwaza_installer
set R2_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%BUILD_NUMBER%.exe
set R2_MSI_URL=https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%BUILD_NUMBER%.msi

REM Check if R2_ENDPOINT_URL is set and looks like a URL
echo R2 endpoint: %R2_ENDPOINT_URL%
if "%R2_ENDPOINT_URL%"=="" (
    echo Skipping upload: R2_ENDPOINT_URL is not set.
) else if not "%R2_ENDPOINT_URL:~0,4%"=="http" (
    echo Skipping upload: R2_ENDPOINT_URL does not look like a valid URL.
) else (
    echo Uploading %EXE_FILE% to %R2_URL% ...
    aws s3 cp "%EXE_FILE%" "s3://k-ubuntu/kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%BUILD_NUMBER%.exe" --endpoint-url "%R2_ENDPOINT_URL%"
    if errorlevel 1 (
        echo EXE upload failed! Check your AWS CLI configuration and endpoint.
    ) else (
        echo EXE uploaded to: %R2_URL%
    )
    
    echo Uploading %MSI_FILE% to %R2_MSI_URL% ...
    aws s3 cp "%MSI_FILE%" "s3://k-ubuntu/kamiwaza_installer_%KAMIWAZA_VERSION%_%ARCH%_build%BUILD_NUMBER%.msi" --endpoint-url "%R2_ENDPOINT_URL%"
    if errorlevel 1 (
        echo MSI upload failed! Check your AWS CLI configuration and endpoint.
    ) else (
        echo MSI uploaded to: %R2_MSI_URL%
    )
)

REM Check the MSI log
msiexec /i installer.msi /l*v install.log