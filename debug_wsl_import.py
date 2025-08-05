#!/usr/bin/env python3
"""
Debug WSL import process to identify why 'kamiwaza' instance isn't being created
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
        
    except subprocess.TimeoutExpired:
        process.kill()
        print(f"Command timed out after {timeout} seconds")
        return 1, "", f"Command timed out after {timeout} seconds"
    except Exception as e:
        print(f"Error running command: {e}")
        return 1, "", str(e)

def test_wsl_import():
    """Test WSL import process step by step"""
    print("=== Testing WSL Import Process ===\n")
    
    instance_name = "kamiwaza-debug"
    
    # Step 1: Check current WSL distributions
    print("1. Checking current WSL distributions:")
    ret, out, err = run_command(['wsl', '--list', '--verbose'], timeout=15)
    if ret != 0:
        print("ERROR: WSL not available")
        return False
    
    # Step 2: Remove test instance if it exists
    print(f"\n2. Removing existing {instance_name} instance (if any):")
    if instance_name in out:
        run_command(['wsl', '--unregister', instance_name], timeout=30)
    else:
        print(f"No existing {instance_name} instance found")
    
    # Step 3: Create test directories
    print("\n3. Setting up test directories:")
    temp_dir = tempfile.gettempdir()
    wsl_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WSL', instance_name)
    rootfs_file = os.path.join(temp_dir, f'ubuntu-24.04-debug-{os.getpid()}.rootfs.tar.gz')
    
    print(f"WSL directory: {wsl_dir}")
    print(f"Rootfs file: {rootfs_file}")
    
    os.makedirs(wsl_dir, exist_ok=True)
    print(f"Created WSL directory: {wsl_dir}")
    
    # Step 4: Test download URL first
    print("\n4. Testing Ubuntu 24.04 rootfs URL:")
    download_url = "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
    test_cmd = [
        'powershell', '-Command',
        f"try {{ $response = Invoke-WebRequest -Uri '{download_url}' -Method Head -UseBasicParsing; Write-Output ('Status: ' + $response.StatusCode + ' Size: ' + [Math]::Round($response.Headers.'Content-Length'[0]/1MB, 2) + ' MB') }} catch {{ Write-Output ('Error: ' + $_.Exception.Message) }}"
    ]
    ret, out, err = run_command(test_cmd, timeout=30)
    if ret != 0 or 'Error:' in out:
        print("ERROR: Cannot access Ubuntu 24.04 rootfs URL")
        return False
    
    # Step 5: Download a small test to verify the process (first 10MB only)
    print("\n5. Testing partial download (first 10MB for verification):")
    partial_download_cmd = [
        'powershell', '-Command',
        f"try {{ $response = Invoke-WebRequest -Uri '{download_url}' -OutFile '{rootfs_file}' -UseBasicParsing -Headers @{{Range='bytes=0-10485759'}}; Write-Output 'Partial download completed' }} catch {{ Write-Output ('Download error: ' + $_.Exception.Message) }}"
    ]
    ret, out, err = run_command(partial_download_cmd, timeout=60)
    
    if ret != 0:
        print("ERROR: Partial download failed")
        return False
    
    # Check if file was created
    if not os.path.exists(rootfs_file):
        print("ERROR: Downloaded file not found")
        return False
    
    file_size = os.path.getsize(rootfs_file)
    print(f"Partial file created: {file_size} bytes")
    
    # Clean up partial file
    os.remove(rootfs_file)
    print("Cleaned up partial download")
    
    # Step 6: Test WSL import syntax
    print("\n6. Testing WSL import command syntax:")
    # Create a dummy small tar.gz file for testing
    dummy_content = "This is a test file for WSL import syntax verification"
    dummy_file = os.path.join(temp_dir, f'dummy-test-{os.getpid()}.tar.gz')
    
    # Create dummy tar.gz using PowerShell
    create_dummy_cmd = [
        'powershell', '-Command',
        f"$content = '{dummy_content}'; $bytes = [System.Text.Encoding]::UTF8.GetBytes($content); Set-Content -Path '{dummy_file}' -Value $bytes -Encoding Byte"
    ]
    run_command(create_dummy_cmd, timeout=10)
    
    if os.path.exists(dummy_file):
        print(f"Created dummy file: {dummy_file}")
        
        # Test WSL import command
        print("Testing WSL import command:")
        ret, out, err = run_command(['wsl', '--import', instance_name, wsl_dir, dummy_file], timeout=30)
        
        if ret == 0:
            print("[OK] WSL import command syntax is correct")
            
            # Clean up test instance
            print("Cleaning up test instance:")
            run_command(['wsl', '--unregister', instance_name], timeout=30)
        else:
            print("✗ WSL import command failed")
            print(f"Error details: {err}")
        
        # Clean up dummy file
        os.remove(dummy_file)
        print("Cleaned up dummy file")
    else:
        print("ERROR: Could not create dummy test file")
    
    # Clean up test WSL directory
    try:
        os.rmdir(wsl_dir)
        print("Cleaned up test WSL directory")
    except:
        pass
    
    print("\n=== WSL Import Debug Complete ===")
    return True

if __name__ == "__main__":
    success = test_wsl_import()
    if success:
        print("\n[OK] WSL import debugging completed")
    else:
        print("\n✗ WSL import debugging failed")