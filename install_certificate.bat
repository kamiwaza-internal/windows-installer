@echo off
echo Installing Kamiwaza self-signed certificate...
echo This will allow the MSI installer to run without security warnings.
echo.
pause

if not exist "kamiwaza_cert.pfx" (
    echo [ERROR] Certificate file 'kamiwaza_cert.pfx' not found!
    echo Make sure you're running this from the build directory.
    pause
    exit /b 1
)

echo [INFO] Installing certificate to TrustedPublisher store...
certutil -p "kamiwaza123" -importpfx "TrustedPublisher" "kamiwaza_cert.pfx"
if errorlevel 1 (
    echo [ERROR] Failed to install certificate. You may need to run as Administrator.
    pause
    exit /b 1
) else (
    echo [SUCCESS] Certificate installed successfully!
    echo The Kamiwaza MSI installer will now be trusted on this machine.
    pause
)