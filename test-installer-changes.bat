@echo off
echo ===============================================
echo Testing Kamiwaza Installer Changes
echo ===============================================
echo.
echo This script tests the recent changes made to the installer:
echo 1. Memory dropdown selector (instead of text input)
echo 2. Updated exit dialog with localhost instructions
echo 3. WSL config with 75% RAM swap and 75% CPU cores
echo 4. GPU detection for NVIDIA RTX and Intel Arc
echo.

pause
echo.

echo === Testing WSL Memory Configuration Script ===
echo Testing with 16GB memory allocation...
powershell -ExecutionPolicy Bypass -File configure_wsl_memory.ps1 -MemoryAmount "16GB"
if errorlevel 1 (
    echo [ERROR] WSL memory configuration test failed
) else (
    echo [SUCCESS] WSL memory configuration test passed
)
echo.

echo === Testing GPU Detection Script ===
echo Running GPU detection...
powershell -ExecutionPolicy Bypass -File detect_gpu.ps1 -WSLDistribution "test-gpu"
if errorlevel 1 (
    echo [ERROR] GPU detection test failed
) else (
    echo [SUCCESS] GPU detection test completed
)
echo.

echo === Checking GPU Placeholder Scripts ===
if exist setup_nvidia_gpu.sh (
    echo [OK] NVIDIA GPU setup script found
    echo First few lines:
    head -n 5 setup_nvidia_gpu.sh 2>nul || type setup_nvidia_gpu.sh | findstr /n "^" | findstr /r "^[1-5]:"
) else (
    echo [ERROR] NVIDIA GPU setup script missing
)
echo.

if exist setup_intel_arc_gpu.sh (
    echo [OK] Intel Arc GPU setup script found
    echo First few lines:
    head -n 5 setup_intel_arc_gpu.sh 2>nul || type setup_intel_arc_gpu.sh | findstr /n "^" | findstr /r "^[1-5]:"
) else (
    echo [ERROR] Intel Arc GPU setup script missing
)
echo.

echo === Checking Installer.wxs Changes ===
echo Checking for memory dropdown configuration...
findstr "MemoryCombo" installer.wxs >nul
if errorlevel 1 (
    echo [ERROR] Memory dropdown not found in installer.wxs
) else (
    echo [OK] Memory dropdown configuration found
)

echo Checking for GPU detection files...
findstr "detect_gpu.ps1" installer.wxs >nul
if errorlevel 1 (
    echo [ERROR] GPU detection script not referenced in installer.wxs
) else (
    echo [OK] GPU detection script referenced in installer.wxs
)

echo Checking for exit dialog updates...
findstr "localhost" installer.wxs >nul
if errorlevel 1 (
    echo [ERROR] Localhost instructions not found in exit dialog
) else (
    echo [OK] Localhost instructions found in exit dialog
)
echo.

echo === Testing Build Process ===
echo Testing build with --no-upload flag...
echo [INFO] This will create a test MSI with all changes
echo.
set /p build_choice="Build test MSI? (y/n): "
if /i "%build_choice%"=="y" (
    echo Building test MSI...
    call build.bat --no-upload
    if errorlevel 1 (
        echo [ERROR] Build failed
    ) else (
        echo [SUCCESS] Build completed successfully
        if exist kamiwaza_installer.msi (
            echo [OK] MSI file created: kamiwaza_installer.msi
        ) else (
            echo [ERROR] MSI file not found
        )
    )
) else (
    echo [INFO] Skipping build test
)

echo.
echo ===============================================
echo Test Summary
echo ===============================================
echo.
echo Changes implemented:
echo [[INFO]] Memory dropdown selector (4GB-64GB options)
echo [[INFO]] Exit dialog with localhost and troubleshooting instructions
echo [[INFO]] WSL config with 75% RAM swap and 75% CPU cores calculation
echo [[INFO]] GPU detection for NVIDIA GeForce RTX and Intel Arc
echo [[INFO]] Placeholder GPU setup scripts created
echo [[INFO]] GPU detection integrated into MSI installer
echo.
echo Files modified/created:
echo - installer.wxs (UI changes, GPU detection)
echo - configure_wsl_memory.ps1 (75% calculations)
echo - detect_gpu.ps1 (GPU detection logic)  
echo - setup_nvidia_gpu.sh (NVIDIA placeholder)
echo - setup_intel_arc_gpu.sh (Intel Arc placeholder)
echo.
echo To test the complete installer:
echo 1. Build MSI: build.bat --no-upload
echo 2. Install MSI and test memory dropdown
echo 3. Verify exit dialog shows localhost instructions
echo 4. Check that WSL config uses 75% calculations
echo 5. Confirm GPU detection runs after installation
echo.
pause