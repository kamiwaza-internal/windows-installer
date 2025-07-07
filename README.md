# Kamiwaza Windows Installer

## Overview
This project provides a graphical Windows installer for deploying the Kamiwaza .deb package into WSL Ubuntu. It features a progress bar, log output, and automates the download and installation process inside WSL. The installer also includes WSL memory configuration to optimize performance.

---

## For Developers

### Prerequisites
- Python 3.10+ (64-bit recommended)
- [PyInstaller](https://pyinstaller.org/)
- [WiX Toolset](https://wixtoolset.org/) (for MSI packaging, optional)
- Windows with WSL enabled

### Setup & Build

1. **Clone the repository**
   ```sh
   git clone <your-repo-url>
   cd windows-installer
   ```

2. **Create and activate a virtual environment**
   ```sh
   python -m venv venv
   venv\Scripts\activate  # On Windows
   ```

3. **Install dependencies**
   ```sh
   pip install -r requirements.txt
   pip install pyinstaller
   ```

4. **Build the standalone executable**
   ```sh
   pyinstaller --onefile --noconsole --name kamiwaza_installer windows_installer.py
   # The EXE will be in the dist/ folder as kamiwaza_installer.exe
   ```

5. **(Optional) Build an MSI installer**
   - Make sure WiX Toolset is installed and in your PATH.
   - Run:
     ```sh
     candle installer.wxs
     light -ext WixUIExtension installer.wixobj
     ```
   - The MSI will be created in your project directory and will include kamiwaza_installer.exe.

---

## For End Users

### Prerequisites
- Windows 10/11 with WSL enabled (Ubuntu recommended)
- Internet connection

### How to Use

1. **Run the Installer**
   - Double-click the `kamiwaza_installer.exe` (or run the MSI if provided).
   - If prompted by Windows, allow the installer to run as administrator.

2. **Configure WSL Memory (MSI Installer)**
   - During installation, you'll be prompted to configure WSL memory allocation.
   - Enter the desired memory amount (e.g., 8GB, 14GB, 16GB, 32GB).
   - The default is 14GB, but you can adjust based on your system's available RAM.
   - This will create/update the `.wslconfig` file in your C:\ drive.

3. **Follow the UI**
   - Click the "Install in WSL" button.
   - The installer will:
     - Configure WSL memory allocation in `.wslconfig`
     - Check for WSL and install if missing
     - Download the latest Kamiwaza `.deb` package into WSL
     - Install the package in WSL Ubuntu
     - Show progress and log output in the window

4. **Completion**
   - When finished, a "Close" button will appear.
   - You can review the log output for details or errors.

### WSL Memory Configuration
The installer automatically configures WSL memory allocation by creating/updating the `.wslconfig` file in your C:\ drive. This file contains:

```ini
[wsl2]
memory=14GB
processors=auto
swap=0
localhostForwarding=true
```

- **memory**: Sets the maximum memory allocation for WSL (default: 14GB)
- **processors**: Automatically detects and uses available CPU cores
- **swap**: Disabled for better performance
- **localhostForwarding**: Enables port forwarding between Windows and WSL

### Troubleshooting
- If the installer fails to download or install, check your WSL internet connectivity by opening a WSL terminal and running `ping google.com` or `wget <deb-url>`.
- Make sure WSL is set up and Ubuntu is installed. You can install Ubuntu from the Microsoft Store.
- If you see permission errors, try running the installer as administrator.
- If WSL memory configuration fails, you can manually edit `C:\.wslconfig` with your desired memory allocation.

---

## What the Installer Includes
- `kamiwaza_installer.exe` (main EXE, built with PyInstaller)
- Installs to `C:\Program Files\Kamiwaza\`
- Start Menu shortcut for Kamiwaza Installer
- Registry entry for uninstall tracking
- Uninstall support via Control Panel (MSI)
- License agreement dialog (MSI only, from License.rtf)
- **WSL memory configuration dialog (MSI only)**
- **Automatic `.wslconfig` file creation/update**

## Customization
- To change the `.deb` package URL, edit the `deb_url` variable in `windows_installer.py`.
- To add more installation steps (e.g., Docker), extend the `perform_installation` method.
- To change the license agreement, edit `License.rtf` (RTF format) and ensure it is referenced in `installer.wxs`.
- To modify default WSL memory allocation, edit the `WSLMEMORY` property in `installer.wxs`.
- To add more WSL configuration options, modify the `configure_wsl_memory` method in `windows_installer.py`.

---

## License
MIT or your chosen license. 