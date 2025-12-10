# Kamiwaza Installer Delete Functionality

## Overview
The Kamiwaza installer system now supports deleting installers from the cloud storage using a new naming convention and delete functionality.

## New Naming Convention
All installers now follow the format: `kamiwaza_installer_version_arch.msi`

### Examples:
- `kamiwaza_installer_0.5.0_x86_64.msi`
- `kamiwaza_installer_0.5.0_arm64.msi`
- `kamiwaza_installer_0.5.1_x86_64.msi`

## Delete Functionality

### Method 1: Using the PowerShell Script Directly
```powershell
# Delete installers for a specific version and architecture
.\tools\upload_msi_to_win.ps1 -Delete -Version "0.5.0" -Arch "x86_64"

# Delete installers for ARM64 architecture
.\tools\upload_msi_to_win.ps1 -Delete -Version "0.5.0" -Arch "arm64"

# Use custom environment file
.\tools\upload_msi_to_win.ps1 -Delete -Version "0.5.0" -Arch "x86_64" -EnvFile "custom\env\file.sh"
```

### Method 2: Using the Batch Wrapper
```batch
# Delete installers for x86_64
delete_installer.bat 0.5.0 x86_64

# Delete installers for ARM64
delete_installer.bat 0.5.0 arm64
```

### Method 3: Test the Delete Functionality
```batch
# Run the test script
test_delete.bat
```

## What Gets Deleted
The delete functionality will remove:
1. `kamiwaza_installer_version_arch.msi` (generic version)
2. `kamiwaza_installer_version_arch_build*.msi` (any build-specific versions)

## Upload with New Naming Convention
The upload functionality now automatically uses the new naming convention:

```powershell
# Upload with automatic naming
.\tools\upload_msi_to_win.ps1 -MsiFilePath "path\to\your\installer.msi"

# The script will automatically:
# 1. Read version and architecture from config.yaml
# 2. Create filename: kamiwaza_installer_version_arch.msi
# 3. Upload with the new naming convention
```

## Build Script Updates
The `build.bat` script now:
1. Uses the new naming convention for MSI files
2. Automatically renames the built MSI file
3. Updates all upload operations to use the new naming

## Configuration
Make sure your `config.yaml` contains the correct version and architecture:
```yaml
kamiwaza_version: 0.5.0
arch: x86_64  # or arm64
```

## Environment Setup
Ensure your `tools/env.sh` file contains valid AWS credentials:
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_ENDPOINT_URL=your_endpoint_url
BUCKET_NAME=your_bucket_name
```

## Error Handling
- The delete operation will show how many files were deleted
- If no files match the pattern, a warning will be displayed
- All operations include detailed logging for debugging

## Testing
Use `test_delete.bat` to test the delete functionality with version 0.5.0 and x86_64 architecture.
