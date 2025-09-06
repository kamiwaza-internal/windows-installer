# Kamiwaza Installer Development Guide

## 🎯 Project Overview
This is a **Windows MSI installer** for Kamiwaza, a WSL-based platform with GPU acceleration support. The installer uses WiX, CustomActions, and batch file integration.

## ✅ Canonical Installer Flow
1. **WSL setup**: Ensure WSL is installed and functional. Repair if needed.
2. **GPU detection and setup**:
   - Detect NVIDIA, Intel Arc, or Intel Integrated via Windows WMI
   - Copy and run matching WSL setup script (`setup_nvidia_gpu.sh`, `setup_intel_arc_gpu.sh`, `setup_intel_integrated_gpu.sh`)
   - All GPU scripts run non-interactively (`DEBIAN_FRONTEND=noninteractive`)
3. **Kamiwaza package installation**:
   - Download `.deb` into WSL (`/tmp/<file>.deb`)
   - Install with `sudo apt install -y <deb>`, streaming logs to `/tmp/kamiwaza_install.log` and `/var/log/apt/term.log`
4. **Register autostart (RunOnce)**:
   - Create `RunOnce` entry `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce` → `KamiwazaGPUAutostart` pointing to `kamiwaza_autostart.bat`
   - On reboot runs: `wsl -d kamiwaza -- kamiwaza start`
5. **Automatic full device restart**:
   - Optional interactive pause: "Press Enter to proceed with FULL DEVICE restart…"
   - 10-second visible countdown
   - Execute `shutdown /r /t 0` to restart the entire Windows device

## 🔁 After Reboot
- `RunOnce` triggers `kamiwaza_autostart.bat`
- Starts platform with: `wsl -d kamiwaza -- kamiwaza start`
- If anything fails, window remains open (batch files end with `pause >nul`)

## 🧾 Logging & Visibility
- **Python installer logs**:
  - `%LOCALAPPDATA%\Kamiwaza\logs\kamiwaza_installer.log` (primary)
  - `%TEMP%\kamiwaza_installer_temp.log` (fallback)
  - `kamiwaza_installer_simple.log` (CWD fallback)
- **WSL logs**: `/var/log/apt/term.log`, `/var/log/apt/history.log`, `/var/log/dpkg.log`
- **All batch files end with `pause >nul`** for debugging visibility

## 🚨 Critical Rules

### Batch File Standards
- **ALWAYS add `pause >nul`** at the end of batch files for debugging
- **NEVER use `exit /b`** without user interaction first
- **ALWAYS provide clear error messages** and status updates

### WiX/MSI Standards
- **ALWAYS test WiX compilation** after any changes
- **NEVER ignore** WiX compiler errors - they WILL cause installation failures
- **ALWAYS verify** file paths and registry entries
- **NEVER mix** `FileKey` and `Directory` attributes in CustomActions

### Testing Requirements
- **NEVER claim** code is "fixed" without testing
- **ALWAYS test** WiX compilation, MSI installation, and CustomAction execution
- **ALWAYS verify** functionality in actual environment

## 🔧 Common Issues & Solutions

### WiX Compilation Errors
- **CNDL0022**: CustomAction/@Directory attribute conflict → Remove `Directory` when using `FileKey`
- **CNDL0005**: Unexpected RegistryValue element → Use CustomActions for registry manipulation
- **CNDL1077**: Property reference warnings → Use CustomActions with batch files

### Path Handling Issues
- **Missing backslashes**: `C:\path\file` vs `C:\pathfile` → Ensure proper path concatenation
- **File not found**: Verify file inclusion in MSI and test paths manually

### CustomAction Execution Failures
- **Return Code 1**: Test batch file manually, check file paths, verify parameters
- **Missing files**: Verify file deployment, check working directory

## 🧪 Testing Protocol

### Before Any "Fix" Declaration
1. **WiX Compilation Test**: `./build.bat` - verify "WiX compilation completed"
2. **MSI Build Test**: Verify "MSI installer built successfully"
3. **Installation Test**: `msiexec /i kamiwaza_installer.msi /l*v test_install.log`
4. **Functionality Test**: Execute all batch files manually, verify WSL integration, test GPU detection
5. **Uninstall Test**: `msiexec /x kamiwaza_installer.msi /l*v test_uninstall.log`

### Testing Checklist
- [ ] WiX compilation succeeds
- [ ] MSI builds without errors
- [ ] All CustomActions execute successfully
- [ ] Batch files run without errors
- [ ] WSL integration works
- [ ] GPU detection functions
- [ ] Registry entries created correctly
- [ ] Uninstall process works

## 🚫 What NOT to Do
- **NEVER embed** Bash/Unix syntax in PowerShell/BAT contexts
- **NEVER use** non-DOS/Windows-unsafe characters in WiX/BAT/PowerShell
- **NEVER trigger** restarts before package installation
- **NEVER add** extra manual touchpoints requiring ad-hoc CMD steps
- **NEVER rely** solely on WSL shutdown for driver activation
- DONT REMOVE DEBUGGING UNLESS SPECIFICALLY PROMPTED!!

## ✅ What ALWAYS to Do
- DEBUG, DEBUG, DEBUG!! Always add debugging messages - more the better! 
- **ALWAYS use** non-interactive installs inside WSL (`DEBIAN_FRONTEND=noninteractive`)
- **ALWAYS detect** GPU via WMI in Python
- **ALWAYS copy** scripts into WSL via reliable methods (tee, unique temp names, `dos2unix`, `chmod +x`)
- **ALWAYS create** RunOnce to autostart Kamiwaza after restart
- **ALWAYS show** clear countdown/pause before automatic device restart

## 📝 Quick Reference

### Essential Commands
```bash
./build.bat                           # Build MSI
msiexec /i installer.msi /l*v log    # Install with logging
msiexec /x installer.msi /l*v log    # Uninstall with logging
```

### Key Files
- `installer.wxs` - Main WiX configuration
- `create_runonce.bat` - RunOnce registry creation
- `run_kamiwaza.bat` - Main installer execution
- `detect_gpu_cmd.bat` - GPU detection
- `kamiwaza_autostart.bat` - Post-reboot startup

### Batch File Template
```batch
@echo off
REM Your script content here

REM Always end with:
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
```

## 🚨 Critical Reminders
- **Script visibility is essential** - always add `pause >nul` to batch files
- **Testing is mandatory** - never claim code is fixed without comprehensive testing
- **WiX compilation errors are CRITICAL** - must be resolved before any other development
- **`wsl --shutdown` ≠ Windows restart** - use `shutdown /r /t 0` for full device restart

---

**Remember: In this project, testing is not optional - it's mandatory. Never claim code is fixed without comprehensive testing.**