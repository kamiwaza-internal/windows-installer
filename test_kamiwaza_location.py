#!/usr/bin/env python3
"""
Test where kamiwaza gets installed and verify the command location
"""
import subprocess
import os

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

def test_kamiwaza_installation():
    """Test where kamiwaza gets installed in WSL"""
    print("=== Testing Kamiwaza Installation Location ===\\n")
    
    # Check if we have a WSL instance to test with
    print("1. Checking available WSL instances:")
    ret, out, _ = run_command(['wsl', '--list', '--quiet'], timeout=15)
    if ret != 0:
        print("ERROR: WSL not available")
        return False
    
    # Parse WSL instances (handle UTF-16 encoding with null bytes)
    wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
    wsl_instances = [name.strip() for name in wsl_instances if name.strip()]
    print(f"Available instances: {wsl_instances}")
    
    # Choose test instance (prefer kamiwaza, fallback to Ubuntu-24.04)
    test_instance = None
    if 'kamiwaza' in wsl_instances:
        test_instance = 'kamiwaza'
    elif 'Ubuntu-24.04' in wsl_instances:
        test_instance = 'Ubuntu-24.04'
    else:
        print("ERROR: No suitable WSL instance found for testing")
        return False
    
    print(f"Using WSL instance: {test_instance}")
    
    print("\\n2. Checking if kamiwaza command exists:")
    ret, out, err = run_command(['wsl', '-d', test_instance, 'which', 'kamiwaza'], timeout=10)
    if ret == 0:
        print(f"SUCCESS: kamiwaza command found at: {out.strip()}")
        kamiwaza_path = out.strip()
    else:
        print("INFO: kamiwaza command not found (may not be installed yet)")
        print("Let's check common installation locations...")
        
        # Check common locations where debian packages install binaries
        locations_to_check = [
            '/usr/bin/kamiwaza',
            '/usr/local/bin/kamiwaza',
            '/opt/kamiwaza/bin/kamiwaza',
            '/home/*/.local/bin/kamiwaza'
        ]
        
        found = False
        for location in locations_to_check:
            print(f"\\nChecking: {location}")
            ret, out, err = run_command(['wsl', '-d', test_instance, 'ls', '-la', location], timeout=10)
            if ret == 0:
                print(f"FOUND: {location}")
                found = True
            else:
                print(f"NOT FOUND: {location}")
        
        if not found:
            print("\\nINFO: kamiwaza not installed - this is expected before running the installer")
            kamiwaza_path = "NOT_INSTALLED"
    
    print("\\n3. Checking typical Debian package installation:")
    print("When a .deb package is installed with 'apt install -f -y', it typically:")
    print("- Installs binaries to: /usr/bin/ or /usr/local/bin/")
    print("- Installs config files to: /etc/")
    print("- Installs data files to: /usr/share/ or /opt/")
    print("- Updates PATH automatically for all users")
    
    print("\\n4. Testing if PATH includes typical binary locations:")
    ret, out, err = run_command(['wsl', '-d', test_instance, 'echo', '$PATH'], timeout=10)
    if ret == 0:
        path_dirs = out.strip().split(':')
        print("PATH directories:")
        for path_dir in path_dirs:
            if path_dir:
                print(f"  - {path_dir}")
        
        # Check if standard binary locations are in PATH
        standard_locations = ['/usr/bin', '/usr/local/bin', '/opt/bin']
        for location in standard_locations:
            if location in path_dirs:
                print(f"✓ {location} is in PATH")
            else:
                print(f"- {location} not in PATH")
    
    print("\\n5. Summary:")
    print("After successful .deb installation:")
    print("- The 'kamiwaza start' command should be available in the shell")
    print("- It will be accessible from any directory due to PATH")
    print("- The WSL shortcut 'wsl -d kamiwaza -- kamiwaza start' will work")
    
    return True

if __name__ == "__main__":
    test_kamiwaza_installation()