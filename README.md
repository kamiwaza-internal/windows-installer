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