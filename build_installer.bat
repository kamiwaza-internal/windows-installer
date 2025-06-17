@echo off
echo Building Kamiwaza Installer...

rmdir /s /q dist
rmdir /s /q build
del windows_installer.spec

REM Create and activate virtual environment
echo Creating virtual environment...
python -m venv venv
call venv\Scripts\activate.bat

REM Install required Python packages in venv
echo Installing required Python packages...
python -m pip install --upgrade pip
pip install pyinstaller
pip install -r requirements.txt

REM Create executable from Python script
echo Creating executable...
pyinstaller --onefile --noconsole --icon=icon.ico windows_installer.py

REM Deactivate virtual environment
call venv\Scripts\deactivate.bat

REM Build the MSI using WiX
echo Building MSI...
candle installer.wxs
light -ext WixUIExtension installer.wixobj

echo Done! The installer should be in the current directory.
pause 