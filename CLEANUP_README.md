# Kamiwaza Installation Cleanup Guide

This directory contains several cleanup scripts to remove Kamiwaza installations and their traces from your system.

## Quick Reference

| Script | Privileges | Speed | Completeness | Use Case |
|--------|------------|-------|--------------|----------|
| `quick_cleanup.bat` | User | Fast | Basic | Quick uninstall after testing |
| `cleanup_installs.bat` | Admin | Medium | Complete | Comprehensive Windows cleanup |
| `cleanup_installs.ps1` | Admin | Medium | Advanced | PowerShell with better error handling |

## Scripts Overview

### 1. quick_cleanup.bat
**No Admin Required** | **Fast** | **Basic Cleanup**

```batch
quick_cleanup.bat
```

**What it does:**
- Uninstalls via local `installer.msi` if present
- Cleans temporary MSI files
- Removes desktop shortcuts
- Takes ~10 seconds

**Use when:**
- You just tested an installation and want to quickly remove it
- The MSI file is in the current directory
- You don't need deep system cleaning

### 2. cleanup_installs.bat (Recommended)
**Admin Required** | **Comprehensive** | **Batch Script**

```batch
# Right-click -> "Run as Administrator"
cleanup_installs.bat
```

**What it does:**
- Finds and uninstalls all Kamiwaza MSI packages
- Cleans MSI cache (`C:\Windows\Installer`)
- Removes registry entries (HKLM, HKCU)
- Deletes program files from all standard locations
- Removes shortcuts and start menu entries
- Restarts Windows Installer service
- Verifies cleanup completion

**Use when:**
- You want complete removal of all traces
- Previous installations left artifacts
- You're experiencing installation conflicts
- You prefer batch scripts over PowerShell

### 3. cleanup_installs.ps1 (Advanced)
**Admin Required** | **Advanced** | **PowerShell**

```powershell
# Run PowerShell as Administrator
.\cleanup_installs.ps1

# Silent mode
.\cleanup_installs.ps1 -Quiet

# Force mode
.\cleanup_installs.ps1 -Force
```

**What it does:**
- Everything the batch script does, plus:
- Better error handling and reporting
- Colorized output for easy reading
- Content-based MSI cache detection
- More robust registry cleaning
- Optional quiet mode for automation

**Parameters:**
- `-Quiet` - Run silently without prompts
- `-Force` - Force removal even if warnings occur

**Use when:**
- You prefer PowerShell over batch
- You need better error reporting
- You want to run cleanup in automation
- You need content-based MSI detection

## Recommended Cleanup Process

### For Normal Use:
1. Try `quick_cleanup.bat` first
2. If issues persist, use `cleanup_installs.bat` as Administrator

### For Stubborn Installations:
1. Run `cleanup_installs.ps1 -Force` as Administrator
2. Restart computer
3. Run the cleanup script again if needed

### For Automation:
```powershell
.\cleanup_installs.ps1 -Quiet -Force
```

## Troubleshooting

### "Access Denied" Errors
- Ensure you're running as Administrator
- Some files may be in use - restart and try again
- Use the PowerShell version for better error handling

### MSI Still Shows in Programs List
- Run the comprehensive cleanup script as Administrator
- Check if the MSI is from a different version/build
- Manually remove via `appwiz.cpl` if needed

### Registry Entries Remain
- The PowerShell script has more thorough registry cleaning
- Manually check these registry locations:
  - `HKLM\SOFTWARE\Kamiwaza`
  - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`

### Files Still Present After Cleanup
- Some files may be in use by running processes
- Restart Windows and run cleanup again
- Check these common locations:
  - `%ProgramFiles%\Kamiwaza`
  - `%LocalAppData%\Kamiwaza`
  - `%AppData%\Kamiwaza`

## Safety Notes

- **Always run cleanup scripts as Administrator for complete removal**
- **These scripts are destructive** - they will remove ALL Kamiwaza installations
- **Backup important data** before running comprehensive cleanup
- **Scripts are safe** - they only target Kamiwaza-specific files and registry entries
- **No system files are modified** - only application-specific traces are removed

## Manual Verification

After running cleanup, you can manually verify removal:

1. **Check Programs List:** `appwiz.cpl`
2. **Check Program Files:** Browse to `%ProgramFiles%` and `%ProgramFiles(x86)%`
3. **Check Registry:** Use `regedit` to search for "Kamiwaza"
4. **Check Start Menu:** Look for Kamiwaza shortcuts
5. **Check Desktop:** Look for Kamiwaza shortcuts

If you find any remaining traces, run the comprehensive cleanup script again. 