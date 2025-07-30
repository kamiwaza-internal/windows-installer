#!/usr/bin/env python3
"""
Investigate where logs are stored during Kamiwaza installation
"""
import subprocess
import os
import tempfile

def run_command(command, timeout=None):
    """Run command and return exit code, stdout, stderr"""
    print(f"Running: {' '.join(command)}")
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8'
        )
        
        stdout, stderr = process.communicate(timeout=timeout)
        print(f"Exit code: {process.returncode}")
        if stdout.strip():
            print(f"STDOUT: {stdout.strip()}")
        if stderr.strip():
            print(f"STDERR: {stderr.strip()}")
        
        return process.returncode, stdout, stderr
        
    except Exception as e:
        print(f"Error running command: {e}")
        return 1, "", str(e)

def investigate_log_locations():
    """Investigate where installation logs are stored"""
    print("=== Investigating Kamiwaza Installation Log Locations ===\n")
    
    # Check if kamiwaza WSL instance exists
    print("1. Checking WSL instance accessibility:")
    ret, out, _ = run_command(['wsl', '--list', '--quiet'], timeout=15)
    if ret != 0:
        print("ERROR: WSL not available")
        return False
    
    # Parse WSL instances
    wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
    wsl_instances = [name.strip() for name in wsl_instances if name.strip()]
    
    if 'kamiwaza' not in wsl_instances:
        print("ERROR: 'kamiwaza' WSL instance not found")
        print(f"Available instances: {wsl_instances}")
        return False
    
    print("SUCCESS: 'kamiwaza' WSL instance found")
    
    print("\n2. Current Log Storage Locations:")
    
    # A. Windows side logs (MSI and installer)
    print("\na) Windows-side logs:")
    temp_dir = tempfile.gettempdir()
    print(f"   - MSI installation log: {temp_dir}\\kamiwaza_install.log")
    print(f"   - Temp directory: {temp_dir}")
    
    # Check if MSI log exists
    msi_log = os.path.join(temp_dir, "kamiwaza_install.log")
    if os.path.exists(msi_log):
        print(f"   ✓ MSI log exists: {msi_log}")
        try:
            size = os.path.getsize(msi_log)
            print(f"     Size: {size} bytes")
        except:
            pass
    else:
        print(f"   - MSI log not found: {msi_log}")
    
    # B. WSL instance logs
    print("\nb) WSL instance logs:")
    
    # Check common Linux log locations
    log_locations = [
        "/var/log/apt/",
        "/var/log/dpkg.log",
        "/var/log/apt/history.log",
        "/var/log/apt/term.log",
        "/tmp/",
        "~/.cache/",
        "/var/log/kamiwaza/",
        "/home/*/kamiwaza/"
    ]
    
    for location in log_locations:
        print(f"\n   Checking: {location}")
        ret, out, err = run_command(['wsl', '-d', 'kamiwaza', 'ls', '-la', location], timeout=10)
        if ret == 0:
            print(f"   ✓ EXISTS: {location}")
            # For directories, show recent files
            if location.endswith('/'):
                print("     Recent files:")
                ret2, out2, _ = run_command(['wsl', '-d', 'kamiwaza', 'ls', '-lt', location], timeout=10)
                if ret2 == 0:
                    lines = out2.strip().split('\n')[:5]  # Show first 5 files
                    for line in lines:
                        if line.strip():
                            print(f"       {line}")
        else:
            print(f"   - Not found: {location}")
    
    print("\n3. Current Installation Command Output:")
    print("The current installer runs commands like:")
    print("   wsl -d kamiwaza bash -c 'export DEBIAN_FRONTEND=noninteractive && sudo -E apt install -f -y /tmp/package.deb'")
    print("\nOutput handling:")
    print("   - STDOUT: Captured by Python subprocess and logged to MSI")
    print("   - STDERR: Captured by Python subprocess and logged to MSI") 
    print("   - apt logs: Stored in WSL instance at /var/log/apt/")
    print("   - dpkg logs: Stored in WSL instance at /var/log/dpkg.log")
    
    print("\n4. Recommended Log Locations:")
    print("a) For MSI installation process:")
    print(f"   - Windows: {temp_dir}\\kamiwaza_install.log")
    print("   - This contains the Python installer output")
    
    print("\nb) For WSL package installation:")
    print("   - WSL: /var/log/apt/history.log (apt command history)")
    print("   - WSL: /var/log/apt/term.log (detailed apt output)")
    print("   - WSL: /var/log/dpkg.log (package installation details)")
    
    print("\nc) For Kamiwaza application logs (after installation):")
    print("   - WSL: ~/.kamiwaza/logs/ (if application creates logs)")
    print("   - WSL: /var/log/kamiwaza/ (if application creates system logs)")
    
    return True

def suggest_improvements():
    """Suggest improvements to logging"""
    print("\n" + "="*60)
    print("SUGGESTED LOGGING IMPROVEMENTS")
    print("="*60)
    
    print("\n1. Enhanced WSL Command Logging:")
    print("   - Redirect apt output to dedicated log file in WSL")
    print("   - Use 'tee' to show output AND save to file")
    print("   - Example: command | tee /tmp/kamiwaza_install.log")
    
    print("\n2. Better Log File Management:")
    print("   - Create dedicated log directory: /tmp/kamiwaza-install/")
    print("   - Save each installation step to separate log files")
    print("   - Timestamp log files for multiple installation attempts")
    
    print("\n3. User-Accessible Log Locations:")
    print("   - Copy important logs to Windows-accessible location")
    print("   - Create shortcuts to log files in Start Menu")
    print("   - Provide 'View Logs' option in installer")
    
    print("\n4. Real-time Log Display:")
    print("   - Stream WSL command output in real-time")
    print("   - Show progress indicators during long operations")
    print("   - Buffer output for display in MSI progress dialog")

if __name__ == "__main__":
    success = investigate_log_locations()
    
    if success:
        suggest_improvements()
        print("\n✓ Log investigation completed successfully")
    else:
        print("\n✗ Log investigation failed")
    
    print(f"\nTo view current MSI logs: notepad {tempfile.gettempdir()}\\kamiwaza_install.log")
    print("To view WSL apt logs: wsl -d kamiwaza cat /var/log/apt/history.log")