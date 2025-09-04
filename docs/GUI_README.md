# Kamiwaza GUI Manager Integration

This document explains how the Kamiwaza GUI Manager is integrated into the MSI installer to provide users with a "Kamiwaza Monitor" application.

## Overview

The GUI Manager gives users a graphical interface to:
- Start/stop Kamiwaza services
- Check GPU status and run diagnostics
- View logs and system information
- Manage WSL instances
- Troubleshoot installation issues

## Components

### 1. Source Code
- **`kamiwaza_gui_manager.py`** - Main GUI application
- **`build_gui_exe.py`** - Script to build the executable
- **`install_gui_manager.ps1`** - PowerShell script to install the GUI

### 2. Build Process
```bash
# Install dependencies
pip install -r requirements_gui.txt

# Build the executable
python build_gui_exe.py

# Or use the batch file
build_and_install_gui.bat
```

### 3. MSI Integration
The installer automatically:
- Includes the GUI executable in the MSI package
- Installs it to `%LOCALAPPDATA%\Kamiwaza\GUI\`
- Creates Start Menu shortcuts under "Kamiwaza > Kamiwaza Monitor"
- Runs GPU detection and setup through the GUI

## Installation Flow

1. **MSI Installer** runs and extracts files
2. **Python Installer** sets up WSL and Kamiwaza
3. **GPU Detection** runs to configure acceleration
4. **GUI Installation** copies executable to AppData
5. **Start Menu** shortcuts are created
6. **User** can launch "Kamiwaza Monitor" from Start Menu

## File Locations

### During Installation
- **Source**: `[INSTALLFOLDER]\KamiwazaGUIManager.exe`
- **Script**: `[INSTALLFOLDER]\install_gui_manager.ps1`

### After Installation
- **Executable**: `%LOCALAPPDATA%\Kamiwaza\GUI\KamiwazaGUIManager.exe`
- **Start Menu**: `Start > Kamiwaza > Kamiwaza Monitor`
- **Logs**: `%LOCALAPPDATA%\Kamiwaza\logs\`

## Features

### System Tray Integration
- **Always starts minimized to system tray** by default
- Right-click tray icon for quick actions (Start/Stop Kamiwaza)
- Click "Show Kamiwaza Manager" to open the full interface
- Real-time status updates in tray icon title
- Use `--show` command line flag to start with window visible

### Quick Actions
- Start/Stop Kamiwaza services
- Check service status
- View real-time logs

### GPU Management
- Run GPU detection scripts
- Check GPU acceleration status
- View OpenCL/VA-API information

### WSL Management
- Check WSL status and health
- Fix common WSL issues
- Clean WSL environment

### System Diagnostics
- View system information
- Check Windows GPU drivers
- Monitor resource usage

## Troubleshooting

### GUI Won't Start
1. Check if executable exists in AppData folder
2. Verify Start Menu shortcuts are created
3. Check Windows Event Viewer for errors
4. Try running from command line: `%LOCALAPPDATA%\Kamiwaza\GUI\KamiwazaGUIManager.exe`
5. **Note**: The GUI starts in system tray by default - look for the Kamiwaza icon in your system tray

### Can't Find GUI Window
1. **Check system tray** - the GUI starts minimized to tray by default
2. Right-click the Kamiwaza tray icon and select "Show Kamiwaza Manager"
3. If you want the window visible on startup, use: `KamiwazaGUIManager.exe --show`

### Missing Shortcuts
1. Check if `install_gui_manager.ps1` ran successfully
2. Verify PowerShell execution policy allows scripts
3. Check Start Menu folder permissions

### GPU Detection Issues
1. Ensure `detect_gpu.ps1` is accessible
2. Check WSL distribution name is correct
3. Verify PowerShell can access WSL

## Development

### Building Locally
```bash
# Install build dependencies
pip install pyinstaller

# Build executable
python build_gui_exe.py

# Test locally
./dist/KamiwazaGUIManager.exe
```

### Customizing the GUI
- Modify `kamiwaza_gui_manager.py` for UI changes
- Update `build_gui_exe.py` for build options
- Modify `install_gui_manager.ps1` for installation changes

### Testing Installation
1. Build the executable
2. Build the MSI installer
3. Install on test machine
4. Verify GUI appears in Start Menu
5. Test all GUI functionality

## Notes

- The GUI is designed to work with both local and remote WSL installations
- All operations run with user permissions (no admin required)
- The GUI automatically detects available WSL distributions
- GPU detection scripts are embedded in the executable
- Start Menu shortcuts use proper Windows shell integration 