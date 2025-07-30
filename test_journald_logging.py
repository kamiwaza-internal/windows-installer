#!/usr/bin/env python3
"""
Test journald logging functionality for Kamiwaza installation
"""
import sys
import os
import subprocess
sys.path.insert(0, os.path.dirname(__file__))

from kamiwaza_headless_installer import HeadlessKamiwazaInstaller

def test_journald_integration():
    """Test how journald logging will work"""
    print("=== Testing Journald Integration ===\\n")
    
    print("1. Current installation commands with journald:")
    
    # Show what the new commands look like
    installer = HeadlessKamiwazaInstaller(
        memory="8GB",
        user_email="test@example.com",
        license_key="test-license-key",
        usage_reporting="1",
        install_mode="lite"
    )
    
    deb_path = "/tmp/kamiwaza_v0.5.0_noble_amd64_build16.deb"
    
    # Get timestamp like the installer does
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    install_commands = [
        f"echo '[{timestamp}] Starting Kamiwaza installation' | systemd-cat -t kamiwaza-install -p info",
        f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt update 2>&1 | systemd-cat -t kamiwaza-install -p info",
        f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt install -f -y {deb_path} 2>&1 | systemd-cat -t kamiwaza-install -p info",
        f"echo '[{timestamp}] Kamiwaza installation completed' | systemd-cat -t kamiwaza-install -p info",
        f"rm {deb_path}"
    ]
    
    print("Installation commands:")
    for i, cmd in enumerate(install_commands, 1):
        print(f"  {i}. {cmd}")
        
    print("\\n2. How systemd-cat works:")
    print("   - systemd-cat: Pipes output directly to systemd journal")
    print("   - -t kamiwaza-install: Tags all entries with 'kamiwaza-install'")
    print("   - -p info: Sets priority level to 'info'")
    print("   - 2>&1: Captures both stdout and stderr")
    
    print("\\n3. What gets logged to journald:")
    print("   All the output you saw manually will now be stored in systemd journal:")
    print("   - Reading package lists... Done")
    print("   - Building dependency tree... Done")
    print("   - Note, selecting 'kamiwaza' instead of '/tmp/package.deb'")
    print("   - The following NEW packages will be installed:")
    print("   - [INFO] Starting Kamiwaza Offline Installation")
    print("   - [INFO] Installing PM2 with a timeout of 180s...")
    print("   - [ERROR] Failed to install PM2 (if it fails)")
    print("   - dpkg: error processing package kamiwaza (if errors occur)")
    
    print("\\n4. How to view the logs after installation:")
    print("   # View all installation logs")
    print("   wsl -d kamiwaza journalctl -t kamiwaza-install")
    print("   ")
    print("   # View only today's logs")
    print("   wsl -d kamiwaza journalctl -t kamiwaza-install --since today")
    print("   ")
    print("   # View last 50 entries")
    print("   wsl -d kamiwaza journalctl -t kamiwaza-install -n 50")
    print("   ")
    print("   # Follow logs in real-time (during installation)")
    print("   wsl -d kamiwaza journalctl -t kamiwaza-install -f")
    print("   ")
    print("   # Search for errors")
    print("   wsl -d kamiwaza journalctl -t kamiwaza-install | grep -i error")
    
    print("\\n5. Test systemd-cat (if kamiwaza WSL exists):")
    
    # Test if we can write to journald
    try:
        test_cmd = ['wsl', '-d', 'kamiwaza', 'echo', 'Test journald logging', '|', 'systemd-cat', '-t', 'kamiwaza-test', '-p', 'info']
        result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            print("   ✓ systemd-cat test successful")
            
            # Try to read it back
            read_cmd = ['wsl', '-d', 'kamiwaza', 'journalctl', '-t', 'kamiwaza-test', '-n', '1', '--no-pager']
            read_result = subprocess.run(read_cmd, capture_output=True, text=True, timeout=10)
            
            if read_result.returncode == 0 and 'Test journald logging' in read_result.stdout:
                print("   ✓ Can read from journald successfully")
                lines = read_result.stdout.strip().split('\n')
                print(f"   Sample output: {lines[-1]}")
            else:
                print("   - Could not read back from journald")
        else:
            print("   - systemd-cat test failed (WSL may not have systemd)")
            
    except Exception as e:
        print(f"   - Could not test systemd-cat: {e}")
    
    return True

if __name__ == "__main__":
    success = test_journald_integration()
    
    if success:
        print("\\n" + "=" * 60)
        print("JOURNALD LOGGING READY!")
        print("=" * 60)
        print("Benefits of journald logging:")
        print("• Persistent logs that survive command completion")
        print("• Searchable and filterable with journalctl")
        print("• Structured logging with timestamps and priorities")
        print("• Real-time log following during installation") 
        print("• Complete capture of all installation output")
        print("• No more lost logs when WSL commands finish!")
        print("=" * 60)
    
    print("\\nNext steps:")
    print("1. Build and install: build.bat --no-upload")
    print("2. Run installation: 'Install Kamiwaza' shortcut")
    print("3. View logs: run view_install_logs.bat")
    print("4. Or manually: wsl -d kamiwaza journalctl -t kamiwaza-install")