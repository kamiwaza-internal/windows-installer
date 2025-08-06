#!/usr/bin/env python3
"""
Test script to verify WSL reboot functionality
"""
import subprocess
import sys
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
        if stdout:
            print(stdout.strip())
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

def test_wsl_reboot():
    """Test the WSL reboot functionality"""
    print("=== WSL REBOOT FUNCTIONALITY TEST ===")
    
    # Check if WSL is available
    ret, out, err = run_command(['wsl', '--version'], timeout=10)
    if ret != 0:
        print("ERROR: WSL not available")
        return 1
    
    # List existing WSL instances
    print("\n=== EXISTING WSL INSTANCES ===")
    ret, out, err = run_command(['wsl', '--list', '--quiet'], timeout=15)
    if ret == 0:
        wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
        wsl_instances = [name.strip() for name in wsl_instances if name.strip()]
        print(f"Found WSL instances: {wsl_instances}")
        
        # Test with kamiwaza instance if it exists
        if 'kamiwaza' in wsl_instances:
            print("\n=== TESTING KAMIWAZA INSTANCE REBOOT ===")
            test_instance_reboot('kamiwaza')
        
        # Test with Ubuntu-24.04 instance if it exists
        if 'Ubuntu-24.04' in wsl_instances:
            print("\n=== TESTING UBUNTU-24.04 INSTANCE REBOOT ===")
            test_instance_reboot('Ubuntu-24.04')
        
        if 'kamiwaza' not in wsl_instances and 'Ubuntu-24.04' not in wsl_instances:
            print("No kamiwaza or Ubuntu-24.04 instances found for testing")
    else:
        print(f"Failed to list WSL instances: {err}")
        return 1
    
    return 0

def test_instance_reboot(instance_name):
    """Test rebooting a specific WSL instance"""
    print(f"Testing reboot for instance: {instance_name}")
    
    # Test initial connectivity
    print(f"1. Testing initial connectivity to {instance_name}...")
    ret, out, err = run_command(['wsl', '-d', instance_name, 'echo', 'initial_test'], timeout=15)
    if ret != 0:
        print(f"ERROR: Could not connect to {instance_name}: {err}")
        return
    print(f"Initial connectivity OK: {out.strip()}")
    
    # Stop the instance
    print(f"2. Stopping {instance_name} instance...")
    ret, out, err = run_command(['wsl', '--terminate', instance_name], timeout=30)
    if ret == 0:
        print(f"Successfully stopped {instance_name}")
    else:
        print(f"Warning: Could not stop {instance_name}: {err}")
    
    # Shutdown all WSL
    print("3. Shutting down all WSL instances...")
    ret, out, err = run_command(['wsl', '--shutdown'], timeout=60)
    if ret == 0:
        print("Successfully shutdown all WSL instances")
    else:
        print(f"Warning: WSL shutdown failed: {err}")
    
    # Wait a moment
    import time
    print("4. Waiting for WSL to fully shutdown...")
    time.sleep(3)
    
    # Test connectivity after reboot
    print(f"5. Testing connectivity after reboot to {instance_name}...")
    ret, out, err = run_command(['wsl', '-d', instance_name, 'echo', 'reboot_test'], timeout=30)
    if ret == 0:
        print(f"SUCCESS: {instance_name} accessible after reboot: {out.strip()}")
        
        # Test whoami to verify user
        ret, out, err = run_command(['wsl', '-d', instance_name, 'whoami'], timeout=15)
        if ret == 0:
            print(f"Current user: {out.strip()}")
        
    else:
        print(f"ERROR: Could not access {instance_name} after reboot: {err}")

if __name__ == "__main__":
    try:
        exit_code = test_wsl_reboot()
        print(f"\n=== TEST COMPLETED WITH EXIT CODE: {exit_code} ===")
        sys.exit(exit_code)
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)