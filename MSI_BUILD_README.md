# Building Kamiwaza Windows Installer MSI

This guide explains how to convert the Python-based Windows installer into an MSI package.

## Prerequisites

### 1. Python
- Install Python 3.7 or later from [python.org](https://python.org)
- Make sure Python is added to your PATH

### 2. WiX Toolset
- Download and install WiX Toolset from [wixtoolset.org](https://wixtoolset.org/releases/)
- Make sure to add WiX to your PATH environment variable
- You can verify installation by running `candle -?` and `light -?` in command prompt

### 3. Required Python Packages
The build script will automatically install these from `requirements.txt`:
- `pyinstaller` - For creating the executable
- `tkinter` - For the GUI (usually comes with Python)

## Building the MSI

### Option 1: Using the Batch File (Recommended)
```batch
build_msi.bat
```

### Option 2: Using Python Script Directly
```batch
python build_msi.py
```

### Option 3: Manual Build Process
If you prefer to build manually:

1. **Build the executable:**
   ```batch
   pyinstaller --onefile --noconsole --manifest uac_admin.manifest kamiwaza_installer.py
   ```

2. **Build the MSI:**
   ```batch
   candle installer.wxs
   light -ext WixUIExtension installer.wixobj
   ```

## Output Files

After successful build, you'll have:
- `Kamiwaza Installer.msi` - The MSI package for distribution
- `dist/kamiwaza_installer.exe` - The standalone executable

## MSI Package Features

The generated MSI includes:
- **Installation Location**: `C:\Program Files\Kamiwaza\`
- **Start Menu Shortcut**: Creates a shortcut in the Start Menu
- **Uninstall Support**: Proper uninstallation through Control Panel
- **UAC Support**: Requests administrator privileges when needed
- **Registry Entries**: Tracks installation for proper uninstall

## Troubleshooting

### WiX Toolset Not Found
- Ensure WiX Toolset is installed and in your PATH
- Try restarting your command prompt after installation
- Verify with `candle -?` command

### PyInstaller Errors
- Make sure all Python requirements are installed
- Check that `kamiwaza_installer.py` exists in the current directory
- Ensure you have write permissions in the current directory

### MSI Build Errors
- Check that `dist/kamiwaza_installer.exe` exists before building MSI
- Verify the `installer.wxs` file is properly formatted
- Ensure you have administrator privileges if needed

## Customization

### Changing Product Information
Edit `installer.wxs` to modify:
- Product name and version
- Manufacturer information
- Installation directory
- Start menu location

### Adding Files to MSI
To include additional files in the MSI:
1. Add them to the `dist/` folder
2. Update `installer.wxs` to reference them
3. Rebuild the MSI

### Custom Icons
- Place your icon file as `icon.ico` in the project root
- The build script will automatically include it

## Distribution

The generated `Kamiwaza Installer.msi` can be:
- Distributed directly to users
- Deployed through Group Policy
- Used in enterprise software distribution systems
- Installed silently with: `msiexec /i "Kamiwaza Installer.msi" /quiet` 