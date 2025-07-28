@echo off
echo [INFO] Harvesting embedded Python files for WiX...

REM Use Heat to generate component group for all Python files
heat.exe dir embedded_python -cg EmbeddedPythonFiles -gg -scom -sreg -sfrag -srd -dr PYTHONFOLDER -var var.EmbeddedPythonPath -out python_components.wxs

if errorlevel 1 (
    echo [ERROR] Heat failed to harvest Python files
    pause
    exit /b 1
) else (
    echo [SUCCESS] Python components harvested to python_components.wxs
)

echo [INFO] You can now include this in your main installer.wxs
pause