@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo Creating Embedded Python for Enterprise MSI
echo ===============================================

REM Create embedded directory
if exist "embedded_python" rmdir /s /q "embedded_python"
mkdir embedded_python
cd embedded_python

echo [INFO] Downloading Python embeddable distribution...
REM Download Python 3.11 embeddable
curl -L -o python-3.11.9-embed-amd64.zip "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
if errorlevel 1 (
    echo [ERROR] Failed to download Python embeddable
    pause
    exit /b 1
)

echo [INFO] Extracting Python...
powershell -Command "Expand-Archive -Path 'python-3.11.9-embed-amd64.zip' -DestinationPath '.' -Force"
del python-3.11.9-embed-amd64.zip

echo [INFO] Downloading get-pip.py...
curl -L -o get-pip.py "https://bootstrap.pypa.io/get-pip.py"
if errorlevel 1 (
    echo [ERROR] Failed to download get-pip.py
    pause
    exit /b 1
)

echo [INFO] Configuring Python paths...
REM Enable site-packages by editing python311._pth
echo python311.zip > python311._pth
echo . >> python311._pth
echo Lib\site-packages >> python311._pth

echo [INFO] Installing pip...
python.exe get-pip.py
if errorlevel 1 (
    echo [ERROR] Failed to install pip
    pause
    exit /b 1
)

echo [INFO] Installing required packages...
python.exe -m pip install PyYAML requests
if errorlevel 1 (
    echo [ERROR] Failed to install packages
    pause
    exit /b 1
)

echo [INFO] Testing Python installation...
python.exe -c "import sys; import yaml; import requests; print('Python embedded runtime ready:', sys.version)"
if errorlevel 1 (
    echo [ERROR] Python test failed
    pause
    exit /b 1
)

cd ..

echo [SUCCESS] Embedded Python created successfully in embedded_python\
echo [INFO] Size: 
dir embedded_python /s /-c | find "bytes"

echo [INFO] Ready for MSI packaging!
pause