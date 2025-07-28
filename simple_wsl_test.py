#!/usr/bin/env python3
"""
Simple WSL import test to identify the real issue
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
        if stdout:
            print(f"STDOUT: {stdout.strip()}")
        if stderr:
            print(f"STDERR: {stderr.strip()}")
        
        return process.returncode, stdout, stderr
        
    except Exception as e:
        print(f"Error running command: {e}")
        return 1, "", str(e)

def main():
    print("=== Simple WSL Import Test ===")
    
    # Test if we can create a basic WSL instance by downloading a smaller Ubuntu image
    # Let's try the official Ubuntu WSL image from Microsoft Store
    
    print("\n1. Current WSL distributions:")
    ret, out, _ = run_command(['wsl', '--list', '--verbose'], timeout=15)
    
    print("\n2. Test if we can download Ubuntu from Microsoft Store approach:")
    # Check if we can install Ubuntu-24.04 via the Microsoft Store method
    
    # First let's see what's available
    print("\n3. Check available WSL distributions online:")
    ret, out, _ = run_command(['wsl', '--list', '--online'], timeout=30)
    
    print("\n4. Try alternative: Download pre-built rootfs from reliable source")
    
    # Alternative approach: Download a working Ubuntu rootfs from a different source
    # Let's try Docker Hub Ubuntu rootfs export or LXC images
    
    print("Testing curl download of Ubuntu 24.04 rootfs...")
    temp_dir = tempfile.gettempdir()
    test_file = os.path.join(temp_dir, f'ubuntu-test-{os.getpid()}.tar.gz')
    
    # Test curl download
    curl_cmd = [
        'curl', '-L', '-o', test_file,
        'https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz',
        '--max-time', '30', '--connect-timeout', '10'
    ]
    
    print("Attempting download with curl (30 second timeout)...")
    ret, out, err = run_command(curl_cmd, timeout=45)
    
    if ret == 0 and os.path.exists(test_file):
        file_size = os.path.getsize(test_file)
        print(f"Download successful! File size: {file_size} bytes")
        
        if file_size > 10000000:  # If we got more than 10MB, it's probably working
            print("Partial download successful - would continue with full download")
            
            # Test WSL import with this file
            instance_name = "kamiwaza-test"
            wsl_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WSL', instance_name)
            os.makedirs(wsl_dir, exist_ok=True)
            
            print(f"Testing WSL import with downloaded file...")
            import_ret, import_out, import_err = run_command([
                'wsl', '--import', instance_name, wsl_dir, test_file
            ], timeout=120)
            
            if import_ret == 0:
                print("SUCCESS: WSL import worked!")
                
                # Verify the instance exists
                list_ret, list_out, _ = run_command(['wsl', '--list', '--quiet'], timeout=15)
                if instance_name in list_out:
                    print(f"SUCCESS: {instance_name} instance created and listed!")
                else:
                    print(f"WARNING: Import succeeded but {instance_name} not in list")
                
                # Clean up test instance
                run_command(['wsl', '--unregister', instance_name], timeout=30)
            else:
                print(f"WSL import failed: {import_err}")
        
        # Clean up test file
        os.remove(test_file)
    else:
        print(f"Download failed: {err}")
    
    print("\n=== Test Complete ===")

if __name__ == "__main__":
    main()