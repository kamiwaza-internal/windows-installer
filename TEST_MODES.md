# Kamiwaza MSI Test Mode Documentation

This document describes the various test modes available for testing the Kamiwaza MSI installer with different DEB configurations.

## Overview

The Kamiwaza installer supports multiple test modes to allow safe testing without requiring real DEB packages or affecting production systems.

## Available Test Modes

### 1. Mock DEB Test Mode (Recommended for Development)

**Purpose**: Creates fake DEB files and simulates the installation process
**Safety**: 100% safe - no real packages downloaded or installed
**Use Case**: Development testing, CI/CD, demonstration

**How to Use**:
```batch
# Interactive mode
test-msi.bat

# Direct build
build-test.bat --mock

# Command line
python create_mock_test_installer.py
```

**What it does**:
- Creates a fake DEB file instead of downloading
- Simulates apt package installation with realistic output
- Creates a mock `kamiwaza` command that shows test messages
- Tests the complete installation flow safely

### 2. Custom URL Test Mode

**Purpose**: Tests with a custom DEB URL (can be any file)
**Safety**: Depends on the URL provided
**Use Case**: Testing with specific test files or lightweight downloads

**How to Use**:
```batch
# Interactive mode
test-msi.bat

# Direct build
build-test.bat --test-url "https://example.com/test.deb"

# Custom config
edit test-config.yaml
build.bat --no-upload
```

**Example URLs**:
- `https://httpbin.org/robots.txt` (lightweight text file)
- `https://example.com/small-test.deb` (actual test DEB)
- Local file URLs for development

### 3. Standard Test Mode

**Purpose**: Uses the current production DEB URL from config.yaml
**Safety**: Downloads real packages - use with caution
**Use Case**: Pre-production testing, verification builds

**How to Use**:
```batch
# Interactive mode
test-msi.bat

# Direct build
build.bat --no-upload
```

## Test Scripts Reference

### Main Test Scripts

| Script | Purpose | Safety Level |
|--------|---------|--------------|
| `test-msi.bat` | Interactive test menu | Varies |
| `build-test.bat` | Build test MSI with options | Medium |
| `standard-test.bat` | Run Python installer directly | High |

### Supporting Scripts

| Script | Purpose |
|--------|---------|
| `create_mock_test_installer.py` | Creates mock DEB installer |
| `create_test_installer.py` | Creates test installer with real URLs |
| `test_wsl_reboot.py` | Tests WSL restart functionality |

## Configuration Files

### test-config.yaml
Default test configuration with safe test URL:
```yaml
kamiwaza_version: 0.5.0-test
codename: noble
build_number: 999
arch: amd64
r2_endpoint_url: https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com
deb_file_url: https://httpbin.org/robots.txt
```

## Test Output Files

After running tests, you'll find:

| File | Description |
|------|-------------|
| `kamiwaza_installer_TEST.msi` | Mock/Custom URL test MSI |
| `kamiwaza_installer_STANDARD_TEST.msi` | Standard test MSI |
| `msi_install_test.log` | MSI installation log |
| `kamiwaza_headless_installer_test.py` | Test installer with DEB URL injected |
| `kamiwaza_headless_installer_mock.py` | Mock installer version |

## Step-by-Step Testing Guide

### Quick Mock Test (Safest)
1. Run `test-msi.bat`
2. Choose option 1 (Mock DEB test)
3. Let it build the test MSI
4. Choose to install when prompted
5. Use "Install Kamiwaza" shortcut from Start Menu
6. Watch the mock installation process

### Custom URL Test
1. Run `test-msi.bat`
2. Choose option 2 (Test with custom URL)
3. Enter your test URL (or press Enter for default)
4. Let it build and optionally install
5. Test with the Start Menu shortcut

### Full Production Test
1. Run `test-msi.bat`
2. Choose option 3 (Standard test)
3. **Warning**: This downloads real DEB packages
4. Monitor installation carefully

## WSL Reboot Testing

The new WSL reboot functionality can be tested with:

```batch
# Test WSL restart logic
python test_wsl_reboot.py

# Test with existing kamiwaza instance
python test_reboot_focused.py
```

## Log Files and Debugging

### Installation Logs
- `msi_install_test.log` - MSI installation process
- `%TEMP%\kamiwaza_install.log` - Detailed installer log
- `%LOCALAPPDATA%\Kamiwaza\logs\` - Copied WSL logs

### WSL Logs (within WSL instance)
- `/var/log/apt/term.log` - Detailed package installation
- `/var/log/apt/history.log` - Package history
- `/tmp/kamiwaza_install.log` - Installer backup log

## Cleanup

### After Testing
1. Uninstall via Add/Remove Programs, OR
2. Use "Cleanup WSL" shortcut from Start Menu
3. Delete test MSI files:
   - `kamiwaza_installer_TEST.msi`
   - `kamiwaza_installer_STANDARD_TEST.msi`
4. Delete log files if desired

### Manual WSL Cleanup
```cmd
wsl --unregister kamiwaza
wsl --shutdown
```

## Safety Notes

### Mock Mode ✅ SAFE
- No real downloads
- No real package installations  
- Creates fake commands only
- Easy to clean up

### Custom URL Mode ⚠️ DEPENDS ON URL
- Safe if using harmless URLs (like robots.txt)
- Could download large files if URL points to them
- Installation will fail gracefully with non-DEB files

### Standard Mode ⚠️ USE WITH CAUTION
- Downloads production DEB packages
- Performs real installation
- May require internet connection
- Creates actual WSL instances

## Troubleshooting

### Common Issues
1. **WSL not available**: Install WSL first with `wsl --install`
2. **Permission errors**: Run as Administrator if needed
3. **Build failures**: Check that all required files are present
4. **MSI install fails**: Check msi_install_test.log for details

### Getting Help
- Check log files listed above
- Run `python kamiwaza_headless_installer.py --help` for options
- Use mock mode for safe testing first

## Integration with CI/CD

For automated testing, use mock mode:
```batch
# Automated testing
build-test.bat --mock
if exist kamiwaza_installer_TEST.msi (
    echo "Test MSI created successfully"
    # Add automated installation tests here
)
```