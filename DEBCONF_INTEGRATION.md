# Kamiwaza MSI to Debconf Integration

This document describes how the Windows MSI installer integrates with Ubuntu's debconf system to provide a seamless configuration experience.

## Overview

The Kamiwaza Windows installer collects user preferences through an MSI dialog and automatically configures the Ubuntu instance's debconf database with these settings. This eliminates the need for users to re-enter configuration during package installation.

## Integration Flow

```
MSI Installer Dialog → Batch Scripts → WSL/Ubuntu → Debconf Configuration → Kamiwaza Installation
```

### 1. MSI Parameter Collection

The MSI installer collects these user preferences:

- **Email Address** (`USER_EMAIL`)
- **License Key** (`LICENSE_KEY`) 
- **Usage Reporting** (`USAGE_REPORTING`)
- **Installation Mode** (`INSTALL_MODE`)
- **Kamiwaza Dedicated Memory** (`WSLMEMORY`)

### 2. Parameter Passing

Parameters are passed from MSI to batch files via command line arguments:

```batch
install_kamiwaza.bat "16GB" "user@company.com" "LICENSE-KEY" "1" "full"
```

### 3. WSL Configuration

Before Ubuntu package installation:

1. **WSL Memory Configuration**: Updates `.wslconfig` with dedicated memory
2. **Debconf Setup**: Configures Ubuntu's debconf database
3. **Environment Variables**: Exports configuration for installation scripts

### 4. Debconf Database Setup

The `setup_debconf.sh` script configures these debconf values:

| Debconf Key | Type | Description |
|-------------|------|-------------|
| `kamiwaza/email` | string | User email address |
| `kamiwaza/license-key` | password | License key (secured) |
| `kamiwaza/usage-reporting` | boolean | Usage analytics preference |
| `kamiwaza/install-mode` | select | Installation mode (lite/full/dev) |
| `kamiwaza/license/accepted` | boolean | License agreement acceptance |
| `kamiwaza/configured-by` | string | Configuration source tracking |
| `kamiwaza/configuration-date` | string | Configuration timestamp |

## File Structure

```
├── installer.wxs                  # MSI installer definition
├── setup_debconf.sh              # Ubuntu debconf configuration script
├── configure_wsl_memory.ps1       # WSL memory configuration script
├── install_kamiwaza.bat           # Main installation script
└── install_kamiwaza_dev.bat       # Developer mode installation script
```

## Usage

### From MSI Installer

1. User fills out the MSI configuration dialog
2. User clicks "Install Kamiwaza" shortcut from Start Menu
3. Installation proceeds automatically with pre-configured settings

### Manual Testing

```powershell
# Test WSL memory configuration
.\configure_wsl_memory.ps1 -MemoryAmount "16GB"

# Test debconf setup (in WSL/Ubuntu)
sudo ./setup_debconf.sh --email "user@example.com" --license-key "KEY" --usage-reporting "1" --mode "full" --license-accepted "true"

# Verify debconf values
debconf-show kamiwaza
```

## Debconf Templates

The system automatically creates debconf templates for proper dialog presentation:

```debconf
Template: kamiwaza/email
Type: string
Description: Email address for Kamiwaza account

Template: kamiwaza/license-key
Type: password
Description: Kamiwaza license key

Template: kamiwaza/usage-reporting
Type: boolean
Default: true
Description: Enable usage reporting

Template: kamiwaza/install-mode
Type: select
Choices: lite, full, dev
Default: lite
Description: Installation mode
```

## Security Considerations

- **License keys** are stored as `password` type in debconf for security
- **Sensitive information** is masked in log outputs
- **File permissions** are properly set on scripts in Ubuntu
- **Automatic cleanup** removes temporary files after configuration

## Error Handling

The system includes comprehensive error handling:

- **WSL Detection**: Gracefully handles missing WSL installations
- **Permission Checks**: Validates sudo access for debconf operations
- **Backup Creation**: Creates backups before modifying `.wslconfig`
- **Validation**: Verifies memory format and other input parameters
- **Fallback**: Falls back to installer-handled configuration if debconf setup fails

## Environment Variables

During installation, these environment variables are available:

```bash
export KAMIWAZA_EMAIL="user@company.com"
export KAMIWAZA_LICENSE_KEY="LICENSE-KEY"
export KAMIWAZA_USAGE_REPORTING="1"
export KAMIWAZA_INSTALL_MODE="full"
export KAMIWAZA_LICENSE_ACCEPTED="true"
```

## Benefits

1. **Seamless Experience**: Users configure once in the MSI, never asked again
2. **No Re-entry**: Eliminates duplicate configuration dialogs
3. **Consistent Settings**: Ensures same configuration across Windows and Ubuntu
4. **Automated Setup**: Reduces installation complexity and errors
5. **Professional Integration**: Follows Debian/Ubuntu packaging best practices

## Troubleshooting

### Common Issues

**WSL not detected:**
```
WSL not detected - debconf setup will be handled by installer
```
Solution: Install WSL 2 and Ubuntu distribution

**Permission denied:**
```
sudo: a password is required
```
Solution: Ensure user has sudo privileges in Ubuntu

**Debconf not found:**
```
debconf-set-selections: command not found
```
Solution: The script automatically installs `debconf-utils`

### Debug Information

Check the installation logs for detailed information:
- MSI log files in `%TEMP%`
- WSL configuration logs in PowerShell output
- Debconf setup logs in Ubuntu terminal output

## Future Enhancements

- Support for additional package managers (snap, flatpak)
- Integration with Windows Credential Manager
- Automatic license validation
- Configuration synchronization between multiple machines 