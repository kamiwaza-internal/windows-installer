#!/usr/bin/env python3
"""
Simple Windows Installer Builder
Creates a Windows installer without requiring WiX Toolset.
"""

import os
import sys
import subprocess
import shutil
import zipfile
import urllib.request
import tempfile
from pathlib import Path

def check_requirements():
    """Check and install Python requirements."""
    try:
        print("Installing Python requirements...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✓ Python requirements installed")
    except subprocess.CalledProcessError as e:
        print(f"Error installing requirements: {e}")
        return False
    return True

def build_executable():
    """Build the executable using PyInstaller."""
    try:
        # Clean previous builds
        for path in ["build", "dist"]:
            if os.path.exists(path):
                shutil.rmtree(path)
        
        print("Building executable with PyInstaller...")
        
        # PyInstaller command
        cmd = [
            "pyinstaller",
            "--onefile",                    # Create a single executable
            "--noconsole",                  # Don't show console window
            "--name", "kamiwaza_installer", # Name of the executable
            "--clean",                      # Clean PyInstaller cache
            "kamiwaza_installer.py"          # Main script
        ]
        
        # Add manifest if it exists
        if os.path.exists("uac_admin.manifest"):
            cmd.extend(["--manifest", "uac_admin.manifest"])
        
        # Add icon if it exists
        if os.path.exists("icon.ico"):
            cmd.extend(["--icon", "icon.ico"])
        
        subprocess.check_call(cmd)
        
        if os.path.exists("dist/kamiwaza_installer.exe"):
            print("✓ Executable built successfully")
            return True
        else:
            print("✗ Executable not found in dist folder")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"Error building executable: {e}")
        return False

def create_installer_script():
    """Create a simple installer script."""
    installer_script = """@echo off
echo Installing Kamiwaza...
echo.

REM Create installation directory
set INSTALL_DIR=C:\\Program Files\\Kamiwaza
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Copy executable
copy "kamiwaza_installer.exe" "%INSTALL_DIR%\\"

REM Create Start Menu shortcut
set START_MENU=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Kamiwaza
if not exist "%START_MENU%" mkdir "%START_MENU%"

REM Create shortcut
echo @echo off > "%START_MENU%\\Kamiwaza Installer.bat"
echo cd /d "%INSTALL_DIR%" >> "%START_MENU%\\Kamiwaza Installer.bat"
echo start "" "kamiwaza_installer.exe" >> "%START_MENU%\\Kamiwaza Installer.bat"

REM Add to registry for uninstall
reg add "HKCU\\Software\\Kamiwaza\\KamiwazaInstaller" /v "installed" /t REG_DWORD /d 1 /f

echo Installation complete!
echo Kamiwaza Installer has been installed to: %INSTALL_DIR%
echo.
pause
"""
    
    with open("dist/install.bat", "w") as f:
        f.write(installer_script)
    
    print("✓ Installer script created")

def create_uninstaller_script():
    """Create an uninstaller script."""
    uninstaller_script = """@echo off
echo Uninstalling Kamiwaza...
echo.

REM Remove Start Menu shortcut
set START_MENU=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Kamiwaza
if exist "%START_MENU%\\Kamiwaza Installer.bat" del "%START_MENU%\\Kamiwaza Installer.bat"
if exist "%START_MENU%" rmdir "%START_MENU%"

REM Remove installation directory
set INSTALL_DIR=C:\\Program Files\\Kamiwaza
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"

REM Remove registry entries
reg delete "HKCU\\Software\\Kamiwaza\\KamiwazaInstaller" /f

echo Uninstallation complete!
echo.
pause
"""
    
    with open("dist/uninstall.bat", "w") as f:
        f.write(uninstaller_script)
    
    print("✓ Uninstaller script created")

def create_zip_installer():
    """Create a zip file installer package."""
    try:
        print("Creating installer package...")
        
        # Create installer directory
        installer_dir = "Kamiwaza_Installer"
        if os.path.exists(installer_dir):
            shutil.rmtree(installer_dir)
        os.makedirs(installer_dir)
        
        # Copy files
        shutil.copy("dist/kamiwaza_installer.exe", installer_dir)
        shutil.copy("dist/install.bat", installer_dir)
        shutil.copy("dist/uninstall.bat", installer_dir)
        
        # Create README
        readme_content = """Kamiwaza Windows Installer

To install:
1. Right-click on install.bat and select "Run as administrator"
2. Follow the installation prompts

To uninstall:
1. Right-click on uninstall.bat and select "Run as administrator"

The installer will:
- Install Kamiwaza to C:\\Program Files\\Kamiwaza
- Create a Start Menu shortcut
- Add registry entries for proper uninstallation

For more information, see the main README.md file.
"""
        
        with open(f"{installer_dir}/README.txt", "w") as f:
            f.write(readme_content)
        
        # Create zip file
        shutil.make_archive("Kamiwaza_Installer", 'zip', installer_dir)
        
        # Clean up
        shutil.rmtree(installer_dir)
        
        print("✓ Installer package created: Kamiwaza_Installer.zip")
        return True
        
    except Exception as e:
        print(f"Error creating installer package: {e}")
        return False

def main():
    """Main build process."""
    print("=== Kamiwaza Simple Windows Installer Builder ===\n")
    
    # Check Python requirements
    if not check_requirements():
        sys.exit(1)
    
    # Build executable
    if not build_executable():
        sys.exit(1)
    
    # Create installer scripts
    create_installer_script()
    create_uninstaller_script()
    
    # Create installer package
    if not create_zip_installer():
        sys.exit(1)
    
    print("\n=== Build Complete! ===")
    print("Files created:")
    print("- dist/kamiwaza_installer.exe (standalone executable)")
    print("- Kamiwaza_Installer.zip (installer package)")
    print("\nTo install: Extract the zip and run install.bat as administrator")

if __name__ == "__main__":
    main() 