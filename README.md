# Kamiwaza Windows Installer

A Windows installer for setting up the Kamiwaza development environment. This installer handles the setup of WSL (Windows Subsystem for Linux), Docker, and other required components.

## Quick Start

### Option 1: Using the Executable (Recommended)
1. Download `kamiwaza_installer.exe` from the latest release
2. Right-click the installer and select "Run as Administrator"
3. Follow the on-screen instructions

### Option 2: Running from Source
If you prefer to run from source, you'll need Python 3.8+ installed.

1. Clone this repository:
```bash
git clone https://github.com/yourusername/kamiwaza-installer
cd kamiwaza-installer
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the installer:
```bash
python windows_installer.py
```

## Features

- Automated WSL2 installation and configuration
- Docker Desktop setup assistance
- Kamiwaza deployment in WSL Ubuntu
- User-friendly graphical interface
- Progress tracking and logging

## System Requirements

- Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11
- 64-bit processor with Second Level Address Translation (SLAT)
- At least 4GB of RAM
- BIOS-level hardware virtualization support must be enabled

## Troubleshooting

### Common Issues

1. **"Run as Administrator" not working**
   - Make sure you're using a Windows account with administrative privileges
   - Try right-clicking and selecting "Run as Administrator" explicitly

2. **WSL Installation Fails**
   - Ensure Windows is up to date
   - Enable virtualization in BIOS/UEFI
   - Run `wsl --update` in PowerShell as administrator

3. **Docker Desktop Installation Issues**
   - Verify WSL2 is properly installed
   - Check that virtualization is enabled in Windows Features
   - Ensure Hyper-V is available and enabled

### Getting Help

If you encounter any issues:
1. Check the log output in the installer window
2. Refer to the [GitHub Issues](https://github.com/yourusername/kamiwaza-installer/issues)
3. Submit a new issue with the log output and error details

## Building from Source

To create your own executable:

1. Install PyInstaller:
```bash
pip install pyinstaller
```

2. Build the executable:
```bash
pyinstaller --onefile --noconsole --icon=kamiwaza.ico windows_installer.py
```

The executable will be created in the `dist` directory.

## License

[Add your license information here] 