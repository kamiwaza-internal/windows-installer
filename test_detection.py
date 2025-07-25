#!/usr/bin/env python3
import subprocess
import sys
import os

def run_command(command, timeout=30):
    try:
        process = subprocess.Popen(
            command, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True, 
            encoding='utf-8'
        )
        stdout, stderr = process.communicate(timeout=timeout)
        return process.returncode, stdout, stderr
    except Exception as e:
        return 1, "", str(e)

def is_windows_server():
    """Test the fixed Windows Server detection"""
    try:
        # Check using systeminfo command - look specifically for "Windows Server" in OS Name line
        ret, out, err = run_command(['systeminfo'], timeout=30)
        if ret == 0 and out:
            print("=== SystemInfo Output ===")
            for line in out.split('\n'):
                if 'OS Name:' in line:
                    print(f"Found OS Name line: {line}")
                    if 'windows server' in line.lower():
                        print("-> DETECTED: Windows Server")
                        return True
                    else:
                        print("-> DETECTED: Standard Windows")
        
        print(f"\n=== Final Result ===")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    result = is_windows_server()
    print(f"Windows Server: {result}")
    
    # Also test WSL detection
    print(f"\n=== WSL Detection Test ===")
    ret, out, err = run_command(['wsl', '--list'])
    if ret == 0:
        print("WSL is working:")
        print(out)
    else:
        print(f"WSL command failed: {err}")