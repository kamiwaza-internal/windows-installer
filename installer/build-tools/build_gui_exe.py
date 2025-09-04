#!/usr/bin/env python3
"""
Build Script for Kamiwaza GUI Manager Executable
Creates a standalone .exe file that can be distributed with the MSI installer
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def build_gui_exe():
    """Build the GUI manager as an executable"""
    print("=== Building Kamiwaza GUI Manager Executable ===")
    
    # Check if PyInstaller is available
    try:
        import PyInstaller
        print(f"PyInstaller version: {PyInstaller.__version__}")
    except ImportError:
        print("PyInstaller not found. Installing...")
        subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"], check=True)
    
    # Source file
    source_file = "kamiwaza_gui_manager.py"
    if not os.path.exists(source_file):
        print(f"ERROR: Source file {source_file} not found!")
        return False
    
    # Output directory
    output_dir = "dist"
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    
    # Build command
    build_cmd = [
        "pyinstaller",
        "--onefile",                    # Single executable
        "--windowed",                   # No console window
        "--name=KamiwazaGUIManager",    # Executable name
        "--icon=../assets/kamiwaza.ico",          # Icon file
        "--add-data=../assets/kamiwaza.ico;.",    # Include icon
        "--add-data=../scripts/detect_gpu.ps1;.",  # Include GPU detection script
        "--add-data=../scripts/cleanup_wsl_kamiwaza.ps1;.",  # Include cleanup script
        "--hidden-import=tkinter",      # Ensure tkinter is included
        "--hidden-import=tkinter.ttk",  # Include ttk widgets
        "--hidden-import=subprocess",   # Include subprocess
        "--hidden-import=threading",    # Include threading
        "--hidden-import=json",         # Include JSON
        "--hidden-import=datetime",     # Include datetime
        "--hidden-import=pathlib",      # Include pathlib
        source_file
    ]
    
    print(f"Build command: {' '.join(build_cmd)}")
    
    try:
        # Run the build
        result = subprocess.run(build_cmd, check=True, capture_output=True, text=True)
        print("Build completed successfully!")
        print("Build output:")
        print(result.stdout)
        
        # Check if executable was created
        exe_path = os.path.join(output_dir, "KamiwazaGUIManager.exe")
        if os.path.exists(exe_path):
            print(f"Executable created: {exe_path}")
            
            # Get file size
            size_mb = os.path.getsize(exe_path) / (1024 * 1024)
            print(f"Executable size: {size_mb:.1f} MB")
            
            return True
        else:
            print("ERROR: Executable not found after build!")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"Build failed with exit code {e.returncode}")
        print("Error output:")
        print(e.stderr)
        return False
    except Exception as e:
        print(f"Build error: {e}")
        return False

def create_installer_integration():
    """Create files needed for MSI installer integration"""
    print("\n=== Creating MSI Installer Integration ===")
    
    # Create the GUI installation script
    gui_install_script = """@echo off
REM Install Kamiwaza GUI Manager to AppData and Start Menu
REM This script is called by the MSI installer

setlocal enabledelayedexpansion

echo Installing Kamiwaza GUI Manager...

REM Get the source executable path (from MSI installer)
set "SOURCE_EXE=%~dp0KamiwazaGUIManager.exe"
set "TARGET_DIR=%LOCALAPPDATA%\\Kamiwaza\\GUI"
set "START_MENU_DIR=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Kamiwaza"

REM Create target directories
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if not exist "%START_MENU_DIR%" mkdir "%START_MENU_DIR%"

REM Copy the executable
if exist "%SOURCE_EXE%" (
    copy "%SOURCE_EXE%" "%TARGET_DIR%\\" >nul
    echo Copied GUI Manager to: %TARGET_DIR%
    
    REM Create Start Menu shortcut
    echo @echo off > "%START_MENU_DIR%\\Kamiwaza Monitor.lnk"
    echo start "" "%TARGET_DIR%\\KamiwazaGUIManager.exe" >> "%START_MENU_DIR%\\Kamiwaza Monitor.lnk"
    
    REM Create desktop shortcut if requested
    if "%1"=="--desktop" (
        set "DESKTOP_DIR=%USERPROFILE%\\Desktop"
        if exist "%DESKTOP_DIR%" (
            echo @echo off > "%DESKTOP_DIR%\\Kamiwaza Monitor.lnk"
            echo start "" "%TARGET_DIR%\\KamiwazaGUIManager.exe" >> "%DESKTOP_DIR%\\Kamiwaza Monitor.lnk"
            echo Created desktop shortcut
        )
    )
    
    echo GUI Manager installation completed successfully!
) else (
    echo ERROR: Source executable not found: %SOURCE_EXE%
    exit /b 1
)

echo.
echo Kamiwaza Monitor is now available:
echo - Start Menu: Start > Kamiwaza > Kamiwaza Monitor
echo - Direct path: %TARGET_DIR%\\KamiwazaGUIManager.exe
echo.
echo You can now use the GUI to manage your Kamiwaza installation!
"""
    
    with open("install_gui_manager.ps1", "w") as f:
        f.write(gui_install_script)
    
    print("Created GUI installation script: install_gui_manager.ps1")
    
    # Create PowerShell version for better integration
    ps_install_script = """# Install Kamiwaza GUI Manager to AppData and Start Menu
# This script is called by the MSI installer

param(
    [switch]$CreateDesktopShortcut
)

Write-Host "Installing Kamiwaza GUI Manager..." -ForegroundColor Green

# Get the source executable path (from MSI installer)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceExe = Join-Path $scriptDir "KamiwazaGUIManager.exe"
$targetDir = Join-Path $env:LOCALAPPDATA "Kamiwaza\\GUI"
$startMenuDir = Join-Path $env:APPDATA "Microsoft\\Windows\\Start Menu\\Programs\\Kamiwaza"

# Create target directories
if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
if (!(Test-Path $startMenuDir)) {
    New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
}

# Copy the executable
if (Test-Path $sourceExe) {
    Copy-Item $sourceExe $targetDir -Force
    Write-Host "Copied GUI Manager to: $targetDir" -ForegroundColor Green
    
    # Create Start Menu shortcut using WScript.Shell
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut("$startMenuDir\\Kamiwaza Monitor.lnk")
        $shortcut.TargetPath = "$targetDir\\KamiwazaGUIManager.exe"
        $shortcut.WorkingDirectory = $targetDir
        $shortcut.Description = "Kamiwaza Monitor - GUI Management Tool"
        $shortcut.IconLocation = "$targetDir\\KamiwazaGUIManager.exe,0"
        $shortcut.Save()
        Write-Host "Created Start Menu shortcut" -ForegroundColor Green
        
        # Create desktop shortcut if requested
        if ($CreateDesktopShortcut) {
            $desktopDir = [Environment]::GetFolderPath("Desktop")
            if (Test-Path $desktopDir) {
                $desktopShortcut = $WshShell.CreateShortcut("$desktopDir\\Kamiwaza Monitor.lnk")
                $desktopShortcut.TargetPath = "$targetDir\\KamiwazaGUIManager.exe"
                $desktopShortcut.WorkingDirectory = $targetDir
                $desktopShortcut.Description = "Kamiwaza Monitor - GUI Management Tool"
                $desktopShortcut.IconLocation = "$targetDir\\KamiwazaGUIManager.exe,0"
                $desktopShortcut.Save()
                Write-Host "Created desktop shortcut" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning "Could not create shortcuts: $_"
        # Fallback: create batch file shortcuts
        $batchContent = "@echo off`nstart `"`" `"$targetDir\\KamiwazaGUIManager.exe`""
        Set-Content -Path "$startMenuDir\\Kamiwaza Monitor.bat" -Value $batchContent
        Write-Host "Created batch file shortcut as fallback" -ForegroundColor Yellow
    }
    
    Write-Host "GUI Manager installation completed successfully!" -ForegroundColor Green
} else {
    Write-Error "Source executable not found: $sourceExe"
    exit 1
}

Write-Host ""
Write-Host "Kamiwaza Monitor is now available:" -ForegroundColor Cyan
Write-Host "- Start Menu: Start > Kamiwaza > Kamiwaza Monitor" -ForegroundColor White
Write-Host "- Direct path: $targetDir\\KamiwazaGUIManager.exe" -ForegroundColor White
Write-Host ""
Write-Host "You can now use the GUI to manage your Kamiwaza installation!" -ForegroundColor Green
"""
    
    with open("install_gui_manager.ps1", "w") as f:
        f.write(ps_install_script)
    
    print("Created PowerShell GUI installation script: install_gui_manager.ps1")

def main():
    """Main build process"""
    print("Kamiwaza GUI Manager Build Process")
    print("==================================")
    
    # Build the executable
    if build_gui_exe():
        print("\n✅ Executable built successfully!")
        
        # Create installer integration files
        create_installer_integration()
        
        print("\n🎉 Build process completed!")
        print("\nNext steps:")
        print("1. The executable is in the 'dist' folder")
        print("2. Copy it to your MSI installer source directory")
        print("3. Update installer.wxs to include the GUI installation")
        print("4. Test the MSI installer")
        
    else:
        print("\n❌ Build failed!")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main()) 