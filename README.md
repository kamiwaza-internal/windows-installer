# Kamiwaza Windows Installer

## Versioning and Configuration

All version, architecture, and build information is now managed in `config.yaml`:

```yaml
kamiwaza_version: 0.5.0-rc1
codename: noble
build_number: 1
arch: auto  # Use 'auto' to auto-detect, or specify 'amd64' or 'arm64'
```

- **kamiwaza_version**: The version of the Kamiwaza .deb to install.
- **codename**: Ubuntu codename (e.g., jammy, noble).
- **build_number**: Build number for the .deb file.
- **arch**: Architecture (`auto`, `amd64`, or `arm64`).

## Build Process

1. **Edit `config.yaml`** to set the desired version, codename, build, and arch.
2. **Run `build.bat`**. This will:
   - Parse `config.yaml` and set environment variables for versioning.
   - Build the Python installer and WiX MSI with the correct version/arch info.
   - The installer UI and logic will reflect the selected version and architecture.

## How it Works

- The Python installer (`windows_installer.py`) reads `config.yaml` (or accepts CLI overrides) and auto-detects architecture if set to `auto`.
- The WiX installer (`installer.wxs`) uses preprocessor variables for version, codename, build, and arch, so the UI and custom actions always match the config.

## Enterprise Benefits

- **Single source of truth** for versioning and architecture.
- **Easy upgrades**: Just update `config.yaml` and rebuild.
- **Consistent UI and logic**: All components use the same version/arch info.
- **Auto-detection**: Architecture is auto-detected unless explicitly set.

---

For advanced usage, you can override config values via command-line arguments to the Python installer:

```
kamiwaza_installer.exe --version 0.5.0-rc1 --codename noble --build 1 --arch amd64
```

If you have any questions, see the code comments or contact the maintainers.

## Troubleshooting

### WSL Installation Issues

If you encounter WSL-related errors during installation:

#### Error: `HCS_E_SERVICE_NOT_AVAILABLE` or `The operation could not be started because a required feature is not installed`

This indicates that required Windows features are not enabled. WSL 2 requires both the WSL feature AND the Virtual Machine Platform feature.

**Solution:**
1. Run as **Administrator** in PowerShell:
   ```powershell
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```

2. Or enable through Windows Features GUI:
   - Open "Turn Windows features on or off"
   - Check both:
     - ☑ Virtual Machine Platform
     - ☑ Windows Subsystem for Linux
   - Restart your computer

3. After restart, set WSL default version:
   ```powershell
   wsl --set-default-version 2
   ```

#### Error: `No suitable WSL distribution found`

The installer requires either 'kamiwaza' or 'Ubuntu-24.04' WSL distributions.

**Solution:**
- The installer will attempt to download and import the kamiwaza distribution automatically
- Ensure you have internet connectivity and sufficient disk space
- If manual installation is needed, install Ubuntu 24.04 from Microsoft Store

### Common Installation Issues

#### Insufficient Permissions
- Run the installer as Administrator
- Ensure your user account has permission to install software

#### Antivirus Interference
- Some antivirus software may block the installer
- Temporarily disable real-time protection during installation
- Add installer to antivirus whitelist

#### Disk Space
- Ensure at least 5GB free space for WSL distribution
- Check available space in `C:\Users\[username]\AppData\Local\WSL\`

#### Network Connectivity
- Installer requires internet access to download WSL rootfs
- Check firewall settings if download fails
- Corporate networks may require proxy configuration

#### Windows Version Compatibility
- WSL 2 requires Windows 10 version 1903 or higher, or Windows 11
- Check Windows version: `winver`
- Update Windows if necessary

### Port Conflicts
If Kamiwaza services fail to start, check for port conflicts:
```powershell
netstat -an | findstr ":8080\|:3000\|:5432"
```

### Logs and Diagnostics
- Installation logs are saved to: `%TEMP%\kamiwaza_installer.log`
- WSL logs: `wsl --list --verbose`
- Check Windows Event Viewer for additional error details 

<!-- To test on winserver -->
## Winserver Installation
To download on winserver:
`bash
PS C:\Users\drew> Invoke-WebRequest -Uri "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_0.5.0-rc1_amd64_build50.msi" -OutFile "kamiwaza_installer_build50.msi" 
`

Then to install:
`bash
 msiexec /i kamiwaza_installer_build50.msi
`