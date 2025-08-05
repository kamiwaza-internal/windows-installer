# Kamiwaza Windows Installer

## Versioning and Configuration

All version, architecture, and build information is managed in `config.yaml`:

```yaml
kamiwaza_version: 0.5.0
codename: noble
build_number: 173
arch: amd64  # Use 'auto' to detect, or specify 'amd64' or 'arm64' 
r2_endpoint_url: https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com
deb_file_url: https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_v0.5.0_noble_amd64_build370000.deb
```

- **kamiwaza_version**: The version of the Kamiwaza .deb to install
- **codename**: Ubuntu codename (e.g., jammy, noble)
- **build_number**: Build number for the .deb file (auto-incremented during build)
- **arch**: Architecture (`auto`, `amd64`, or `arm64`)
- **r2_endpoint_url**: Cloudflare R2 storage endpoint for build uploads
- **deb_file_url**: Direct URL to the Kamiwaza .deb package

## Build Process

1. **Edit `config.yaml`** to set the desired version, codename, build, and arch
2. **Run `build.bat`**. This will:
   - Parse `config.yaml` and set environment variables for versioning
   - Auto-detect the next available build number by checking AWS R2 storage
   - Update `config.yaml` with the next build number for future builds
   - Inject the `deb_file_url` into the installer template
   - Build the WiX MSI installer with the correct version/arch info
   - Create a self-signed certificate for code signing (if not exists)
   - Sign the MSI installer with the certificate
   - Upload the MSI to AWS R2 storage (unless `--no-upload` flag is used)
   - Display the public download URL for the latest build

### Build Script Options

```bash
# Normal build with upload
build.bat

# Build without uploading to AWS
build.bat --no-upload

# Clean up log files
build.bat --clean
```

## How it Works

### Build System
- The build script (`build.bat`) reads `config.yaml` and parses all configuration values
- Build numbers are automatically incremented by checking existing builds on AWS R2
- The `deb_file_url` is injected into the installer template during build
- WiX installer uses preprocessor variables for version, codename, build, and arch
- Self-signed certificates are created automatically for code signing

### Installer Features
- **Custom UI**: Configuration dialog for email, license key, usage reporting, and installation mode
- **WSL Memory Configuration**: Configurable WSL memory allocation (default: 14GB)
- **Port Reservation**: Automatically reserves ports 61100-61299 for Kamiwaza services
- **Start Menu Integration**: Creates shortcuts for installation, platform start, and cleanup
- **Comprehensive Cleanup**: Complete removal of WSL instances and data on uninstall
- **Embedded Python**: Includes Python runtime for installer operations
- **Verbose Logging**: Detailed installation logs saved to `%TEMP%\kamiwaza_install.log`

### Installation Modes
- **Lite**: Minimal installation with core components
- **Full**: Complete installation with all features

## Enterprise Benefits

- **Single source of truth** for versioning and architecture in `config.yaml`
- **Automatic build numbering** with AWS R2 integration
- **Easy upgrades**: Just update `config.yaml` and rebuild
- **Consistent UI and logic**: All components use the same version/arch info
- **Auto-detection**: Architecture is auto-detected unless explicitly set
- **Code signing**: Self-signed certificates for enterprise deployment
- **Comprehensive logging**: Detailed logs for troubleshooting

---

For advanced usage, you can override config values via command-line arguments to the Python installer:

```
kamiwaza_installer.exe --version 0.5.0 --codename noble --build 173 --arch amd64
```

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

### Build Issues

#### Certificate Creation Fails
If self-signed certificate creation fails:
- Ensure PowerShell execution policy allows script execution
- Run as Administrator if certificate store access is restricted
- The build will continue without signing if certificate creation fails

#### AWS Upload Fails
If upload to AWS R2 fails:
- Check internet connectivity
- Verify AWS credentials are configured in `venv\Scripts\aws.cmd`
- Use `--no-upload` flag to skip upload and build locally only

## Windows Server Installation

To download on Windows Server:
```powershell
PS C:\Users\username> Invoke-WebRequest -Uri "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_0.5.0_amd64_build173.msi" -OutFile "kamiwaza_installer_build173.msi"
```

Then to install:
```powershell
msiexec /i kamiwaza_installer_build173.msi
```

## Development Notes

- The installer uses WiX Toolset for MSI creation
- Custom UI dialogs are defined in `installer.wxs`
- Python installer template is processed during build to inject configuration
- Build artifacts include both MSI and EXE versions (EXE for direct execution)
- All cleanup operations are comprehensive and remove all traces of the installation