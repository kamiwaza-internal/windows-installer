@echo off
echo Generating Kamiwaza application icon...
python create_icon.py
if errorlevel 1 (
    echo [ERROR] Icon generation failed! Make sure Pillow is installed: pip install Pillow
    pause
    exit /b 1
) else (
    echo [SUCCESS] Icon generated successfully as kamiwaza.ico
    echo You can now build the installer with: build.bat
)
pause 