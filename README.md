# Kamiwaza Windows Installer

## Overview
This project provides a graphical Windows installer for deploying the Kamiwaza .deb package into WSL Ubuntu. It features a progress bar, log output, and automates the download and installation process inside WSL.

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
   pyinstaller --onefile --noconsole windows_installer.py
   # The EXE will be in the dist/ folder
   ```

5. **(Optional) Build an MSI installer**
   - Make sure WiX Toolset is installed and in your PATH.
   - Run:
     ```sh
     candle installer.wxs
     light -ext WixUIExtension installer.wixobj
     ```
   - The MSI will be created in your project directory.

---

## For End Users

### Prerequisites
- Windows 10/11 with WSL enabled (Ubuntu recommended)
- Internet connection

### How to Use

1. **Run the Installer**
   - Double-click the `windows_installer.exe` (or run the MSI if provided).
   - If prompted by Windows, allow the installer to run as administrator.

2. **Follow the UI**
   - Click the "Install in WSL" button.
   - The installer will:
     - Check for WSL and install if missing
     - Download the latest Kamiwaza `.deb` package into WSL
     - Install the package in WSL Ubuntu
     - Show progress and log output in the window

3. **Completion**
   - When finished, a "Close" button will appear.
   - You can review the log output for details or errors.

### Troubleshooting
- If the installer fails to download or install, check your WSL internet connectivity by opening a WSL terminal and running `ping google.com` or `wget <deb-url>`.
- Make sure WSL is set up and Ubuntu is installed. You can install Ubuntu from the Microsoft Store.
- If you see permission errors, try running the installer as administrator.

---

## Customization
- To change the `.deb` package URL, edit the `deb_url` variable in `windows_installer.py`.
- To add more installation steps (e.g., Docker), extend the `perform_installation` method.

---

## Post-Installation Details

- The Kamiwaza instance will be located at `/opt/kamiwaza/kamiwaza`
- A dedicated `kamiwaza` user will be created with full permissions to the instance (if not already present)

### Launching the Application

To start Kamiwaza, use:
```sh
su kamiwaza
kamiwaza start
```

---

## System Restart Procedure Documentation

### Quick Reference Guide

**Complete System Restart**

1. **Stop all containers**: `containers-down.sh`
2. **Start all containers**: `containers-up.sh`
3. **Start Ray cluster**: `start-ray.sh` (run after stopping previous Ray instance using  `stop ray` in the venv)
4. **Start core services**: `launch.sh` (required)
5. **Start frontend**: `npm run prod` (required if frontend desired)

**Optional Components**
- **Stop core services**: `stop-core.sh`
- **Restart Lab environment**: `restart-or-start-lab.sh` or `start-lab.sh`

**Kamiwaza Services**
- **Start Kamiwaza daemon**: `kamiwaza/kamiwazad.sh start` (creates log files in `/opt/kamiwaza/logs`)

### Important Notes
- Core services (`launch.sh`) are required for the system to function properly. If port 7777 isn't running, then the application will fail to respond.
- To clear Python configuration cache when encountering log errors or undefined Python errors, use the system flush command `op.py`
- `launch.sh` initiates launch.py, which calls main.py and spawns run.py as subprocess for task execution

---

## Debugging & Maintenance

**General Approach to Debugging:**
- The primary method for debugging is to **check the log files**. A clean stop and restart of all components is also a crucial debugging step, especially after experiencing issues.

**Stopping Kamiwaza:**
1. **Attempt full stop (caution advised):** The command `kamiwaza-d.sh stop` is intended to stop everything, but the notes indicate it might not always stop all components reliably (specifically mentioning Ray).
2. **Manual Stop Sequence (recommended for debugging):**
    - **Stop Containers:** Run `containers down`. Be aware that `containers down -v` will wipe container state, which is generally okay for most, but **should not** be used for Cockroach containers as its state matters.
    - **Stop Ray:** Manually run `ray stop`. The notes suggest this often needs to be done separately as `kamiwaza-d.sh stop` might not correctly call the Ray stop command, especially if Ray is not installed system-wide.
    - **Stop Core Service:** Run `stop-core.sh`.
    - **Stop Lab Service:** Run `stop lab`.
    - **Stop Front End:** Run `stop front end`. The underlying command likely involves `pm2 stop kamiwaza-frontend`.

**Starting Kamiwaza:**
1. **Containers:** Run `containers up`. This is important for setting up necessary environment variables like `WASA_ROOT`.
2. **Ray Cluster:** Run `start ray`. It's crucial to use this script rather than just `ray start` from the command line because the Kamiwaza setup requires custom Ray resource parameters (e.g., for GPUs). The notes mention starting Ray after containers is common practice, though the order relative to containers might not strictly matter.
3. **Core Service:** Run `launch.sh`. This script initiates `launch.py`, which sets things up and calls `main.py`. `main.py` then launches `run.py` as a subprocess for scheduled tasks (downloads, cluster updates). Both `main.py` and `run.py` should generally be running. If one dies, it's recommended to restart the core service using `stop-core.sh` followed by `launch.sh`.
4. **Lab Service:** Run `start lab`.
5. **Front End:** Navigate to the front end folder and run `npm run prod`. The notes explicitly state that `npm install` should *not* be run after the initial setup as it can cause unexpected package updates and break things. `npm run build` is usually integrated into other scripts and shouldn't need to be run manually. The process is likely managed by PM2.

**Debugging Specific Issues:**
1. **Check Logs:**
    - Main daemon log: `kamiwaza-d.log`
    - Component-specific logs: `kamiwaza-d-<element>.log` (e.g., `core`, `containers`, `containers-worker`).
    - Ray logs: Some core issues might appear here.
    - Explore all relevant logs for error messages or clues.
2. **Config Changes:** If you modify `.config.py`, you *must* update the configuration cache for changes to take effect. Use the command `op.py config/cache` (located in the root directory). The cache file is `.kamiwaza/configure_cache`.
3. **Docker Network Issues:** If you see errors like "cannot find network ID," it might be a Docker network issue. Destroying the specific container attached to the non-existent network is a potential solution.
4. **Front End Issues:** PM2 sometimes orphans processes or leaves ports blocked. The `stop front end` script attempts to handle this.
5. **Status Check:** Use the command `kamiwaza-d.sh status` or `kamiwaza-d.sh status -v` (for more detailed checks defined in the Kamiwaza YAML) to get an overview of component states.
6. **Node Service:** A separate node service runs on port 7778 (distinct from the main Ray API on 7777) and provides node-specific health information, bypassing Ray. Checking this might be useful for node-level problems.
7. **Seeking Help:** If logs are absent, unclear, or you're otherwise stuck after attempting a clean restart and checking logs, reach out for assistance.

In summary, debugging often starts with checking logs, followed by a rigorous stop-and-start sequence using the appropriate scripts for each component. Configuration changes require explicit cache updates.

---

## License
MIT or your chosen license. 